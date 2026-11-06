extends Node
## État de la ferme : tuiles labourées/arrosées, cultures, coffre d'expédition.
## Indépendant de l'affichage : la scène Farm ne fait que le refléter.

var tiles: Dictionary = {}  # Vector2i -> {"watered": bool, "crop": String, "age": int}
var shipping: Array = []  # [{"id": String, "qty": int}]
var objects: Dictionary = {}  # Vector2i -> "sprinkler" | "quality_sprinkler"

const SPRINKLER_RANGE := {
	"sprinkler": [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN],
	"quality_sprinkler": [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
		Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	],
}
const FERTILIZER_EVERY := 3  # une nuit de croissance bonus toutes les 3 nuits arrosées


func reset() -> void:
	tiles.clear()
	shipping.clear()
	objects.clear()


func is_tilled(cell: Vector2i) -> bool:
	return tiles.has(cell)


func is_watered(cell: Vector2i) -> bool:
	return tiles.has(cell) and tiles[cell].watered


func till(cell: Vector2i) -> void:
	if not tiles.has(cell):
		tiles[cell] = {"watered": TimeManager.is_raining(), "crop": "", "age": 0}
		EventBus.farm_tile_changed.emit(cell)


func water(cell: Vector2i) -> void:
	if tiles.has(cell):
		tiles[cell].watered = true
		EventBus.farm_tile_changed.emit(cell)


func place_object(cell: Vector2i, id: String) -> void:
	objects[cell] = id
	EventBus.farm_tile_changed.emit(cell)


func remove_object(cell: Vector2i) -> String:
	var id: String = objects.get(cell, "")
	objects.erase(cell)
	EventBus.farm_tile_changed.emit(cell)
	return id


func is_fertilized(cell: Vector2i) -> bool:
	return tiles.has(cell) and tiles[cell].get("fert", false)


func fertilize(cell: Vector2i) -> bool:
	if not tiles.has(cell) or is_fertilized(cell):
		return false
	tiles[cell]["fert"] = true
	tiles[cell]["fert_progress"] = 0
	EventBus.farm_tile_changed.emit(cell)
	return true


func get_crop(cell: Vector2i) -> String:
	return str(tiles[cell].crop) if tiles.has(cell) else ""


func plant(cell: Vector2i, crop_id: String) -> bool:
	if not tiles.has(cell) or tiles[cell].crop != "":
		return false
	tiles[cell].crop = crop_id
	tiles[cell].age = 0
	EventBus.farm_tile_changed.emit(cell)
	return true


## Stade d'affichage : 0..N-1 en croissance, N = mûr (N = nb d'étapes).
func crop_stage(cell: Vector2i) -> int:
	var crop_id := get_crop(cell)
	if crop_id == "":
		return -1
	var stages: Array = GameData.crop(crop_id).get("stage_days", [])
	var age: int = tiles[cell].age
	var cumulative := 0
	for i in stages.size():
		cumulative += int(stages[i])
		if age < cumulative:
			return i
	return stages.size()


func is_mature(cell: Vector2i) -> bool:
	var crop_id := get_crop(cell)
	return crop_id != "" and tiles[cell].age >= GameData.crop_total_days(crop_id)


## Récolte : renvoie l'id de l'objet obtenu ("" si rien).
func harvest(cell: Vector2i) -> String:
	if not is_mature(cell):
		return ""
	var crop_id := get_crop(cell)
	var data := GameData.crop(crop_id)
	var regrow := int(data.get("regrow", 0))
	if regrow > 0:
		tiles[cell].age = GameData.crop_total_days(crop_id) - regrow
	else:
		tiles[cell].crop = ""
		tiles[cell].age = 0
	EventBus.farm_tile_changed.emit(cell)
	return str(data.get("harvest", ""))


func ship(id: String, qty: int) -> void:
	for entry: Dictionary in shipping:
		if entry.id == id:
			entry.qty += qty
			return
	shipping.append({"id": id, "qty": qty})


## Vend le contenu du coffre d'expédition. Remplit report et renvoie le gain.
func sell_shipping(report: Dictionary) -> int:
	var total := 0
	var sold: Array = []
	for entry: Dictionary in shipping:
		var price := int(GameData.item(entry.id).get("sell", 0))
		var line_total: int = price * int(entry.qty)
		total += line_total
		sold.append({"id": entry.id, "qty": entry.qty, "total": line_total})
	shipping.clear()
	report["sold"] = sold
	report["earned"] = total
	return total


## Simulation d'une nuit : croissance des cultures arrosées, fin de saison.
func advance_day(new_season: int, raining: bool) -> void:
	for cell: Vector2i in tiles:
		var t: Dictionary = tiles[cell]
		if t.crop != "":
			if not GameData.crop_in_season(t.crop, new_season):
				t.crop = ""  # la culture meurt hors saison
				t.age = 0
			elif t.watered:
				t.age += 1
				if t.get("fert", false):
					t.fert_progress = int(t.get("fert_progress", 0)) + 1
					if t.fert_progress >= FERTILIZER_EVERY:
						t.fert_progress = 0
						t.age += 1
		t.watered = raining
	# Les arroseurs arrosent au lever du jour.
	for cell: Vector2i in objects:
		for offset: Vector2i in SPRINKLER_RANGE.get(objects[cell], []):
			if tiles.has(cell + offset):
				tiles[cell + offset].watered = true


func to_dict() -> Dictionary:
	var out := {}
	for cell: Vector2i in tiles:
		out["%d,%d" % [cell.x, cell.y]] = tiles[cell].duplicate()
	var objs := {}
	for cell: Vector2i in objects:
		objs["%d,%d" % [cell.x, cell.y]] = objects[cell]
	return {"tiles": out, "shipping": shipping.duplicate(true), "objects": objs}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("tiles", {})
	for key: String in saved:
		var parts := key.split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var t: Dictionary = saved[key]
		tiles[cell] = {
			"watered": bool(t.get("watered", false)),
			"crop": str(t.get("crop", "")),
			"age": int(t.get("age", 0)),
			"fert": bool(t.get("fert", false)),
			"fert_progress": int(t.get("fert_progress", 0)),
		}
	var objs: Dictionary = data.get("objects", {})
	for key: String in objs:
		var parts := key.split(",")
		objects[Vector2i(int(parts[0]), int(parts[1]))] = str(objs[key])
	for entry: Variant in data.get("shipping", []):
		shipping.append({"id": str(entry.id), "qty": int(entry.qty)})
