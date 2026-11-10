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


## Prix d'achat (certaines boutiques ont leurs propres prix).
func price(shop_id: String, item_id: String) -> int:
	var prices: Dictionary = info(shop_id).get("prices", {})
	return int(round(float(prices.get(item_id, GameData.item(item_id).get("buy", 0))) * Soul.price_factor(shop_id) * Partners.price_factor(shop_id)))


func is_open(id: String) -> bool:
	if id != "market" and Events.gathering_now():
		return false  # tout le monde est à la fête
	var s := info(id)
	if Soul.MODERN_SHOPS.has(id) and (not Soul.arrived or Soul.is_gone(str(Soul.MODERN_SHOPS[id]))):
		return false  # pas encore ouverte, ou fermée pour de bon
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
			# Graines de la saison d'abord, puis les autres
			var later: Array = []
			for item_id: String in GameData.items:
				var item := GameData.item(item_id)
				if item.get("type") != "seed" or not item.has("buy"):
					continue
				if GameData.crop_in_season(str(item.get("crop", "")), TimeManager.season):
					out.append(item_id)
				else:
					later.append(item_id)
			out.append_array(later)
		elif Soul.in_stock(id, str(entry)):
			out.append(str(entry))
	# Le pont réparé : Basile fait venir des graines hybrides
	if id == "comptoir" and Projects.done.has("bridge"):
		out.append("seed_hybrid")
	return out
