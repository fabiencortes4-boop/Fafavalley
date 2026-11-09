extends Node
## Cueillette : plantes sauvages qui apparaissent chaque jour, selon la
## saison, sur l'herbe de la ferme et du village.

const PER_MAP := {"farm": 4, "village": 6, "forest": 10}
## Après une journée de pluie, des champignons sortent en plus (pour un jour)
const RAIN_MUSHROOMS := {"farm": 1, "village": 2, "forest": 5}
const RAIN_ITEM := "mushroom"

var spots: Dictionary = {}  # map_id -> {"x,y": item_id}
var _last_day: Dictionary = {}  # map_id -> numéro de jour du dernier remplissage


func reset() -> void:
	spots.clear()
	_last_day.clear()


func _day_number() -> int:
	return (TimeManager.year - 1) * 112 + TimeManager.season * 28 + TimeManager.day


func season_items() -> Array:
	var out: Array = []
	for id: String in GameData.items:
		var item := GameData.item(id)
		if item.get("type") == "forage" and float(TimeManager.season) in item.get("seasons", []):
			out.append(id)
	return out


## Appelé à l'arrivée sur une carte : complète les plantes du jour.
func ensure_spawned(map_id: String, free_cells: Array) -> Dictionary:
	if not PER_MAP.has(map_id):
		return {}
	var map_spots: Dictionary = spots.get(map_id, {})
	if int(_last_day.get(map_id, -1)) != _day_number():
		_last_day[map_id] = _day_number()
		var pool := season_items()
		free_cells.shuffle()
		var target := int(PER_MAP[map_id])
		for cell: Vector2i in free_cells:
			if map_spots.size() >= target or pool.is_empty():
				break
			var key := "%d,%d" % [cell.x, cell.y]
			if not map_spots.has(key):
				map_spots[key] = pool[randi() % pool.size()]
		if rain_mushrooms_today():
			var extra := int(RAIN_MUSHROOMS.get(map_id, 0))
			for cell: Vector2i in free_cells:
				if extra <= 0:
					break
				var key := "%d,%d" % [cell.x, cell.y]
				if not map_spots.has(key):
					map_spots[key] = RAIN_ITEM
					extra -= 1
		spots[map_id] = map_spots
	return map_spots


## Il a plu hier (hors hiver) : les champignons sortent ce matin.
func rain_mushrooms_today() -> bool:
	return TimeManager.rain_yesterday and TimeManager.season != 3


func take(map_id: String, cell: Vector2i) -> String:
	var map_spots: Dictionary = spots.get(map_id, {})
	var key := "%d,%d" % [cell.x, cell.y]
	var id: String = map_spots.get(key, "")
	map_spots.erase(key)
	return id


## Nouveau jour / nouvelle saison : les plantes hors saison fanent.
func new_day() -> void:
	var pool := season_items()
	for map_id: String in spots:
		for key: String in spots[map_id].keys():
			if not spots[map_id][key] in pool:
				spots[map_id].erase(key)


func to_dict() -> Dictionary:
	return {"spots": spots.duplicate(true), "last_day": _last_day.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	spots = data.get("spots", {}).duplicate(true)
	for k: String in data.get("last_day", {}):
		_last_day[k] = int(data.last_day[k])
