extends Node
## Mariage (data/marriage.json) : à 8 cœurs, un bouquet pour sortir
## ensemble ; à 10 cœurs, le pendentif de la source (forgé par Gaston) pour
## demander en mariage. Le mariage a lieu sur la place 3 jours plus tard,
## puis l'époux ou l'épouse vit à la ferme et aide chaque matin.

var data: Dictionary = {}
var dating: Dictionary = {}  # id -> true
var fiance: String = ""
var wedding_day: int = -1  # numéro de jour absolu du mariage
var spouse: String = ""
var wedding_pending: bool = false  # la scène du mariage reste à jouer
var last_help: String = ""  # aide du matin (affichée au réveil)


func _ready() -> void:
	var file := FileAccess.open("res://data/marriage.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed


func reset() -> void:
	dating.clear()
	fiance = ""
	wedding_day = -1
	spouse = ""
	wedding_pending = false
	last_help = ""


func is_candidate(id: String) -> bool:
	return id in data.get("candidates", [])


## Plafond d'amitié : 8 cœurs tant qu'on ne sort pas ensemble (célibataires).
func heart_cap(id: String) -> int:
	if is_candidate(id) and not dating.has(id) and spouse != id:
		return int(data.get("bouquet_hearts", 8))
	return Relations.MAX_HEARTS


func day_number() -> int:
	return (TimeManager.year - 1) * 112 + TimeManager.season * TimeManager.DAYS_PER_SEASON + TimeManager.day


## Offrir un objet spécial (bouquet, pendentif). Renvoie {"used": bool, "text": String}.
func give(id: String, item: String) -> Dictionary:
	var name := str(GameData.npc(id).get("name", id))
	if not is_candidate(id):
		return {"used": false, "text": "Oh, c'est gentil... mais garde ça pour quelqu'un de spécial."}
	var lines: Dictionary = data.get(id, {})
	if item == "bouquet":
		if dating.has(id) or spouse == id:
			return {"used": false, "text": "Encore des fleurs ? Tu es adorable. Mais tu sais déjà ma réponse !"}
		if Relations.hearts(id) < int(data.get("bouquet_hearts", 8)):
			return {"used": false, "text": "Un bouquet ? Je... on ne se connaît pas encore assez, tu ne crois pas ?"}
		dating[id] = true
		Relations.add_points(id, 100)
		return {"used": true, "text": str(lines.get("dating", "Oui !"))}
	if item == "pendant":
		if spouse != "" or fiance != "":
			return {"used": false, "text": "Tu as déjà fait ta promesse à quelqu'un, %s." % ("non" if spouse == "" else "voyons")}
		if not dating.has(id):
			return {"used": false, "text": "Un pendentif ? Mais... on ne sort même pas ensemble !"}
		if Relations.hearts(id) < int(data.get("pendant_hearts", 10)):
			return {"used": false, "text": "C'est... très tôt. Laisse-nous encore un peu de temps, d'accord ?"}
		fiance = id
		wedding_day = day_number() + int(data.get("wedding_delay", 3))
		EventBus.toast("Mariage avec %s dans %d jours, sur la place !" % [name, int(data.get("wedding_delay", 3))])
		return {"used": true, "text": str(lines.get("proposal", "Oui !"))}
	return {"used": false, "text": "..."}


## Chaque nuit : le jour du mariage arrive ; marié·e, l'aide du matin.
func new_day() -> void:
	last_help = ""
	if fiance != "" and day_number() >= wedding_day:
		spouse = fiance
		fiance = ""
		wedding_pending = true
		return
	if spouse == "":
		return
	var name := str(GameData.npc(spouse).get("name", spouse))
	var roll := randf()
	if roll < 0.4 and not FarmState.tiles.is_empty():
		for c: Vector2i in FarmState.tiles:
			FarmState.tiles[c].watered = true
		last_help = "%s a arrosé toutes les cultures ce matin." % name
	elif roll < 0.6 and (Animals.is_built("coop") or Animals.is_built("barn")):
		for b: String in Animals.buildings:
			if Animals.is_built(b):
				Animals.buildings[b].hay = mini(int(Animals.buildings[b].hay) + 4, Animals.FEEDER_MAX)
		last_help = "%s a rempli les mangeoires de foin." % name
	elif roll < 0.85:
		var dish: String = ["vegetable_soup", "omelette", "salad", "grilled_fish"][randi() % 4]
		if Inventory.add_item(dish, 1) == 0:
			last_help = "%s t'a préparé : %s !" % [name, GameData.item_name(dish).to_lower()]


## Phrase de l'époux ou de l'épouse selon l'heure.
func spouse_line() -> String:
	var pools: Dictionary = data.get(spouse, {}).get("spouse", {})
	var hour := TimeManager.minutes / 60
	var key := "morning" if hour < 11 else ("day" if hour < 18 else "evening")
	var pool: Array = pools.get(key, ["..."])
	return str(pool[randi() % pool.size()])


## Où se trouve l'époux ou l'épouse : "home" (matin, soir) ou "farm" (journée).
func spouse_place() -> String:
	if spouse == "":
		return ""
	var hour := TimeManager.minutes / 60
	return "farm" if hour >= 11 and hour < 18 and not TimeManager.is_raining() else "home"


## Répliques de la scène du mariage (avec les vœux de l'élu·e).
func wedding_lines() -> Array:
	var out: Array = []
	for entry: Array in data.get("wedding", []):
		var who := str(entry[0])
		var text := str(entry[1])
		if who == "@spouse":
			who = spouse
		if text == "@vow":
			text = str(data.get(spouse, {}).get("vow", "Oui."))
		out.append([who, text])
	return out


func to_dict() -> Dictionary:
	return {"dating": dating.keys(), "fiance": fiance, "wedding_day": wedding_day, "spouse": spouse, "wedding_pending": wedding_pending}


func from_dict(saved: Dictionary) -> void:
	reset()
	for id: Variant in saved.get("dating", []):
		dating[str(id)] = true
	fiance = str(saved.get("fiance", ""))
	wedding_day = int(saved.get("wedding_day", -1))
	spouse = str(saved.get("spouse", ""))
	wedding_pending = bool(saved.get("wedding_pending", false))
