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
	new_day()


func new_day() -> void:
	talked_today.clear()
	gifted_today.clear()


func hearts(id: String) -> int:
	return mini(int(points.get(id, 0)) / POINTS_PER_HEART, MAX_HEARTS)


func add_points(id: String, amount: int) -> void:
	points[id] = clampi(int(points.get(id, 0)) + amount, 0, POINTS_PER_HEART * MAX_HEARTS)
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


## Goût d'un habitant pour un objet : loved, liked, neutral ou disliked.
func taste(id: String, item_id: String) -> String:
	var data := GameData.npc(id)
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
	add_points(id, GIFT_POINTS[t] * (HeartEvents.BIRTHDAY_FACTOR if birthday and GIFT_POINTS[t] > 0 else 1))
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
	EventBus.relations_changed.emit()
