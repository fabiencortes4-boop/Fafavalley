extends Node
## Amitié avec les habitants : points (250 par cœur, 10 cœurs max),
## discussion et cadeau une fois par jour, choix des répliques.

const POINTS_PER_HEART := 250
const MAX_HEARTS := 10
const TALK_POINTS := 20
const GIFT_POINTS := {"loved": 80, "liked": 45, "neutral": 20, "disliked": -20}

var points: Dictionary = {}  # id -> int
var met: Dictionary = {}  # id -> true
var talked_today: Dictionary = {}
var gifted_today: Dictionary = {}


func reset() -> void:
	points.clear()
	met.clear()
	remarks_said.clear()
	new_day()


func new_day() -> void:
	talked_today.clear()
	gifted_today.clear()


func hearts(id: String) -> int:
	return mini(int(points.get(id, 0)) / POINTS_PER_HEART, MAX_HEARTS)


func add_points(id: String, amount: int) -> void:
	# Célibataires : 8 cœurs au plus tant qu'on ne sort pas ensemble
	var cap := POINTS_PER_HEART * Marriage.heart_cap(id)
	points[id] = clampi(int(points.get(id, 0)) + amount, 0, maxi(cap, mini(int(points.get(id, 0)), POINTS_PER_HEART * MAX_HEARTS)))
	EventBus.relations_changed.emit()


## Discussion : renvoie la réplique et compte les points d'amitié.
func talk(id: String) -> String:
	var lines: Dictionary = GameData.npc(id).get("dialogue", {})
	if not met.has(id):
		met[id] = true
		talked_today[id] = true
		add_points(id, TALK_POINTS)
		return str(lines.get("intro", "..."))
	if talked_today.has(id):
		return _pick(lines.get("again", ["..."]))
	talked_today[id] = true
	add_points(id, TALK_POINTS)
	# Parfois, une remarque sur ce que le joueur a accompli
	var remark := _remark(id)
	if remark != "":
		return remark
	var pool: Array = []
	var h := hearts(id)
	pool.append_array(lines.get("stranger", []) if h < 3 else lines.get("friend", []))
	if h >= 6:
		pool.append_array(lines.get("close", []))
	var season_key: String = ["spring", "summer", "autumn", "winter"][TimeManager.season]
	pool.append_array(lines.get(season_key, []))
	if TimeManager.is_raining():
		pool.append_array(lines.get("rain", []))
		pool.append_array(lines.get("rain", []))  # plus probable quand il pleut
	return _pick(pool)


## Remarques (data/remarks.json) déjà dites : "habitant:index"
var remarks_said: Dictionary = {}
var _remarks: Array = []


func _remark(id: String) -> String:
	if _remarks.is_empty():
		var file := FileAccess.open("res://data/remarks.json", FileAccess.READ)
		if file != null:
			var data: Variant = JSON.parse_string(file.get_as_text())
			if data is Dictionary:
				_remarks = data.get("remarks", [])
	if randf() > 0.4:
		return ""
	for i in _remarks.size():
		var r: Dictionary = _remarks[i]
		var key := "%s:%d" % [id, i]
		var who: Array = r.get("npcs", [])
		if remarks_said.has(key) or (not who.is_empty() and not id in who) or not _remark_applies(str(r.when)):
			continue
		remarks_said[key] = true
		var lines: Array = r.get("lines", ["..."])
		return str(lines[randi() % lines.size()])
	return ""


static func _remark_applies(when: String) -> bool:
	if when.begins_with("flag:"):
		return PlayerState.flags.has(when.trim_prefix("flag:"))
	if when.begins_with("chapter:"):
		return Story.chapter >= int(when.trim_prefix("chapter:"))
	if when.begins_with("collection:"):
		return Collections.total_found() >= int(when.trim_prefix("collection:"))
	match when:
		"machine":
			return Collections.count("artisan") > 0
		"legend":
			return Achievements.value("legends") > 0
		"boss":
			return PlayerState.flags.has("mine_boss")
		"married":
			return Marriage.spouse != ""
		"child":
			return Marriage.child_name != ""
		"quality":
			return Collections.found.size() > 0 and Inventory.slots.any(func(s: Variant) -> bool: return s != null and GameData.quality_of(str(s.id)) >= 2)
	return false


## Goût d'un habitant pour un objet : loved, liked, neutral ou disliked.
func taste(id: String, item_id: String) -> String:
	var data := GameData.npc(id)
	item_id = GameData.base_id(item_id)  # la qualité ne change pas les goûts
	for key: String in ["loves", "likes", "dislikes"]:
		if item_id in data.get(key, []):
			return {"loves": "loved", "likes": "liked", "dislikes": "disliked"}[key]
	return "neutral"


## Offre un cadeau : renvoie la réaction (le joueur garde l'objet si refusé).
func give_gift(id: String, item_id: String) -> Dictionary:
	var lines: Dictionary = GameData.npc(id).get("dialogue", {})
	if gifted_today.has(id):
		return {"accepted": false, "text": str(lines.get("gift_again", "..."))}
	var t := taste(id, item_id)
	gifted_today[id] = true
	met[id] = true
	var birthday := HeartEvents.is_birthday(id)
	# Un beau cadeau (argent, or, cristal) fait encore plus plaisir
	var points: int = GIFT_POINTS[t] * (HeartEvents.BIRTHDAY_FACTOR if birthday and GIFT_POINTS[t] > 0 else 1)
	if points > 0:
		points = int(points * (1.0 + 0.1 * GameData.quality_of(item_id)))
	add_points(id, points)
	if birthday:
		return {"accepted": true, "taste": t, "text": "Pour mon anniversaire ? Oh, tu y as pensé ! " + str(lines.get("gift_" + t, "Merci."))}
	Story.bump("gifts")
	return {"accepted": true, "taste": t, "text": str(lines.get("gift_" + t, "Merci."))}


func _pick(pool: Array) -> String:
	if pool.is_empty():
		return "..."
	return str(pool[randi() % pool.size()])


func to_dict() -> Dictionary:
	return {
		"points": points.duplicate(),
		"met": met.keys(),
		"talked": talked_today.keys(),
		"gifted": gifted_today.keys(),
		"remarks": remarks_said.keys(),
	}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("points", {})
	for id: String in saved:
		points[id] = int(saved[id])
	for id: Variant in data.get("met", []):
		met[str(id)] = true
	for id: Variant in data.get("talked", []):
		talked_today[str(id)] = true
	for id: Variant in data.get("gifted", []):
		gifted_today[str(id)] = true
	for key: Variant in data.get("remarks", []):
		remarks_said[str(key)] = true
	EventBus.relations_changed.emit()
