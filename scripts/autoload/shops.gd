extends Node
## Boutiques du village (data/shops.json) : chacune est tenue par un
## habitant, avec ses horaires et ses jours de fermeture.

var shops: Dictionary = {}


func _ready() -> void:
	var file := FileAccess.open("res://data/shops.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			shops = parsed


func info(id: String) -> Dictionary:
	return shops.get(id, {})


func is_open(id: String) -> bool:
	var s := info(id)
	var hours: Array = s.get("open", [9, 17])
	var weekday := (TimeManager.day - 1) % 7
	if float(weekday) in s.get("closed_days", []):
		return false
	return TimeManager.minutes >= int(hours[0]) * 60 and TimeManager.minutes < int(hours[1]) * 60


func hours_text(id: String) -> String:
	var s := info(id)
	var hours: Array = s.get("open", [9, 17])
	var text := "Ouvert de %dh à %dh" % [int(hours[0]), int(hours[1])]
	var closed: Array = s.get("closed_days", [])
	if not closed.is_empty():
		var days := []
		for d: Variant in closed:
			days.append(["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"][int(d)])
		text += ", fermé le " + ", ".join(days)
	return text + "."


## Objets vendus (le jeton "@seeds" = toutes les graines).
func items(id: String) -> Array:
	var out: Array = []
	for entry: Variant in info(id).get("items", []):
		if str(entry) == "@seeds":
			for item_id: String in GameData.items:
				if GameData.item(item_id).get("type") == "seed":
					out.append(item_id)
		else:
			out.append(str(entry))
	return out
