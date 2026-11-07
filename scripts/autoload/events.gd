extends Node
## Événements du village (data/events.json) : une grande fête par saison,
## le marché du samedi et une petite animation chaque jour de la semaine.
## Pendant une fête, tout le monde se rassemble sur la place et les
## boutiques ferment ; un stand propose l'activité de la fête.

signal changed

const BOOTH := Vector2i(29, 24)  # le stand, sur la place

var festivals: Array = []
var weekly: Array = []
var market: Dictionary = {}
var prizes: Array = []
var done: Dictionary = {}  # "id:année" -> true (activité de la fête déjà faite)


func _ready() -> void:
	var file := FileAccess.open("res://data/events.json", FileAccess.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			festivals = data.get("festivals", [])
			weekly = data.get("weekly", [])
			market = data.get("market", {})
			prizes = data.get("contest_prizes", [])
	# Boutique du colporteur (marché du samedi, marché d'hiver)
	var items: Array = []
	var prices := {}
	for entry: Array in market.get("items", []):
		items.append(str(entry[0]))
		prices[str(entry[0])] = int(entry[1])
	Shops.shops["market"] = {"name": market.get("name", "Colporteur"), "owner": "", "open": [6, 24], "items": items, "prices": prices}
	# Lettre d'annonce la veille de chaque fête
	for f: Dictionary in festivals:
		Mail.letters["event_" + str(f.id)] = {
			"from": "Bertrand, maire de Valfleur",
			"when": {"season": int(f.season), "day": int(f.day) - 1},
			"text": f.get("letter", ""), "items": [],
		}


func reset() -> void:
	done.clear()


func weekday() -> int:
	return (TimeManager.day - 1) % 7


func _in_hours(e: Dictionary) -> bool:
	var m := TimeManager.minutes
	return m >= int(e.start) * 60 and m < int(e.end) * 60


## La grande fête du jour ({} s'il n'y en a pas).
func festival_today() -> Dictionary:
	for f: Dictionary in festivals:
		if int(f.season) == TimeManager.season and int(f.day) == TimeManager.day:
			return f
	return {}


## L'animation de la semaine pour aujourd'hui.
func weekly_today() -> Dictionary:
	for w: Dictionary in weekly:
		if int(w.weekday) == weekday():
			return w
	return {}


## Une fête est en cours : tout le monde est sur la place.
func gathering_now() -> bool:
	var f := festival_today()
	return not f.is_empty() and _in_hours(f)


## Le stand est-il ouvert ? (fête en cours ou marché du samedi)
func booth_open() -> bool:
	if gathering_now():
		return true
	var w := weekly_today()
	return w.get("market", false) and _in_hours(w) and festival_today().is_empty()


## Ce qu'il y a au stand aujourd'hui : "contest", "dance", "market" ou "".
func booth_activity() -> String:
	var f := festival_today()
	if not f.is_empty():
		return str(f.activity)
	return "market" if weekly_today().get("market", false) else ""


## Où doit aller cet habitant à cause d'un événement :
## {"place": Vector2i, "index": int}, ou {} s'il suit son emploi du temps.
func place_for(npc_id: String) -> Dictionary:
	if gathering_now():
		var ids: Array = GameData.npcs.keys()
		return {"place": BOOTH + Vector2i(1, 2), "index": ids.find(npc_id)}
	var w := weekly_today()
	if not w.is_empty() and _in_hours(w) and npc_id in w.npcs:
		var p: Array = w.place
		return {"place": Vector2i(int(p[0]), int(p[1])), "index": (w.npcs as Array).find(npc_id)}
	return {}


## Ce qui se passe en ce moment au village (pour les bulles et le panneau).
func happening_now() -> Dictionary:
	if gathering_now():
		return festival_today()
	var w := weekly_today()
	if not w.is_empty() and _in_hours(w):
		return w
	return {}


func is_done(id: String) -> bool:
	return done.has("%s:%d" % [id, TimeManager.year])


func mark_done(id: String) -> void:
	done["%s:%d" % [id, TimeManager.year]] = true
	changed.emit()


## Concours : on présente un objet, le prix dépend de sa valeur.
func enter_contest(item_id: String) -> Dictionary:
	var f := festival_today()
	if f.is_empty() or is_done(str(f.id)):
		return {}
	var value := int(GameData.item(item_id).get("sell", 0))
	for p: Array in prizes:
		if value >= int(p[0]):
			Inventory.remove_item(item_id, 1)
			Inventory.add_gold(int(p[1]))
			mark_done(str(f.id))
			for id: String in GameData.npcs:
				Relations.add_points(id, 20)
			return {"title": str(p[2]), "gold": int(p[1]), "value": value}
	return {}


## Danse de la Nuit des lanternes avec un habitant.
func dance_with(npc_id: String) -> void:
	var f := festival_today()
	if f.is_empty() or is_done(str(f.id)):
		return
	Relations.add_points(npc_id, 250)
	mark_done(str(f.id))


## Texte du panneau d'affichage : ce qui vient.
func calendar_text() -> String:
	var seasons := ["printemps", "été", "automne", "hiver"]
	var lines: Array = []
	for f: Dictionary in festivals:
		lines.append("%s : %d %s, %dh-%dh." % [f.name, int(f.day), seasons[int(f.season)], int(f.start), int(f.end)])
	var days := ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]
	var w := weekly_today()
	var today := "" if w.is_empty() else " Aujourd'hui (%s) : %s, %dh-%dh." % [days[weekday()].to_lower(), w.name, int(w.start), int(w.end)]
	return "Fêtes de Valfleur - " + " ".join(lines) + " Chaque samedi matin : marché sur la place." + today


func to_dict() -> Dictionary:
	return {"done": done.keys()}


func from_dict(data: Dictionary) -> void:
	reset()
	for k: Variant in data.get("done", []):
		done[str(k)] = true
