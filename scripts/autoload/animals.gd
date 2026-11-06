extends Node
## Élevage : bâtiments (poulailler, étable) construits par Mathis, animaux
## achetés chez Léon, foin acheté chez Margot ou fabriqué avec de la fibre.
## Chaque nuit : chaque animal mange 1 foin de la mangeoire de son bâtiment.
## Nourri -> il gagne de l'amitié et produit au matin. Pas nourri -> il en
## perd et ne produit rien. Caresser et brosser chaque jour le rend heureux.

signal changed

const FEEDER_MAX := 20
const MAX_FRIENDSHIP := 1000
const PET_POINTS := 15
const BRUSH_POINTS := 25
const FED_POINTS := 10
const HUNGRY_POINTS := -30

var data: Dictionary = {}  # data/animals.json
var buildings: Dictionary = {}  # id -> {"built": bool, "days_left": int, "hay": int}
var animals: Array = []  # [{"type", "name", "building", "friendship", "fed", "petted", "brushed", "ready", "age"}]


func _ready() -> void:
	var file := FileAccess.open("res://data/animals.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed
	reset()


func reset() -> void:
	buildings.clear()
	for id: String in data.get("buildings", {}):
		buildings[id] = {"built": false, "days_left": 0, "hay": 0}
	animals.clear()


func building_info(id: String) -> Dictionary:
	return data.get("buildings", {}).get(id, {})


func animal_info(type: String) -> Dictionary:
	return data.get("animals", {}).get(type, {})


func is_built(id: String) -> bool:
	return bool(buildings.get(id, {}).get("built", false))


func under_construction(id: String) -> bool:
	return int(buildings.get(id, {}).get("days_left", 0)) > 0


func in_building(id: String) -> Array:
	var out: Array = []
	for i in animals.size():
		if animals[i].building == id:
			out.append(i)
	return out


func has_room(id: String) -> bool:
	return is_built(id) and in_building(id).size() < int(building_info(id).get("capacity", 4))


func hearts(index: int) -> int:
	return int(animals[index].friendship) / 200  # 0 à 5


# ------------------------------------------------------------ construction
## Ce qui manque pour construire (or, matériaux) ; vide si tout est là.
func construction_missing(id: String) -> Dictionary:
	var info := building_info(id)
	var out := {}
	if Inventory.gold < int(info.get("price", 0)):
		out["or"] = int(info.price) - Inventory.gold
	var mats: Dictionary = info.get("materials", {})
	for item: String in mats:
		var lack := int(mats[item]) - Inventory.count_of(item)
		if lack > 0:
			out[item] = lack
	return out


func start_construction(id: String) -> bool:
	if is_built(id) or under_construction(id) or not construction_missing(id).is_empty():
		return false
	var info := building_info(id)
	Inventory.spend_gold(int(info.price))
	var mats: Dictionary = info.get("materials", {})
	for item: String in mats:
		Inventory.remove_item(item, int(mats[item]))
	buildings[id].days_left = int(info.get("days", 2))
	changed.emit()
	return true


# ------------------------------------------------------------ achat et soins
func buy(type: String) -> bool:
	var info := animal_info(type)
	var building := str(info.get("building", ""))
	if not has_room(building) or not Inventory.spend_gold(int(info.get("price", 0))):
		return false
	var names: Array = data.get("names", ["Noisette"])
	var used := {}
	for a: Dictionary in animals:
		used[a.name] = true
	var name := str(names[randi() % names.size()])
	for n: Variant in names:
		if not used.has(n):
			name = str(n)
			break
	animals.append({"type": type, "name": name, "building": building, "friendship": 100,
		"fed": false, "petted": false, "brushed": false, "ready": false, "age": 0})
	changed.emit()
	return true


## Met tout le foin du sac dans la mangeoire. Renvoie la quantité ajoutée.
func fill_feeder(id: String) -> int:
	var room := FEEDER_MAX - int(buildings[id].hay)
	var moved := mini(room, Inventory.count_of("hay"))
	if moved > 0:
		Inventory.remove_item("hay", moved)
		buildings[id].hay += moved
		changed.emit()
	return moved


func pet(index: int) -> bool:
	var a: Dictionary = animals[index]
	if a.petted:
		return false
	a.petted = true
	_add(index, PET_POINTS)
	return true


func brush(index: int) -> bool:
	var a: Dictionary = animals[index]
	if a.brushed or Inventory.count_of("brush") == 0:
		return false
	a.brushed = true
	_add(index, BRUSH_POINTS)
	return true


func _add(index: int, points: int) -> void:
	animals[index].friendship = clampi(int(animals[index].friendship) + points, 0, MAX_FRIENDSHIP)
	changed.emit()


## Produits prêts sans outil (œufs, laine, truffes) : on les ramasse tous.
func collect(id: String) -> Array:
	var got: Array = []
	for i in in_building(id):
		var a: Dictionary = animals[i]
		var info := animal_info(a.type)
		if a.ready and str(info.get("tool", "")) == "":
			var item := _product_for(i)
			if Inventory.add_item(item, 1) == 0:
				a.ready = false
				got.append(item)
	if not got.is_empty():
		Skills.add_xp("farming", 5 * got.size())
		Story.bump("products", got.size())
		changed.emit()
	return got


## Traire une vache (seau à lait nécessaire).
func milk(index: int) -> String:
	var a: Dictionary = animals[index]
	var info := animal_info(a.type)
	if not a.ready or Inventory.count_of(str(info.get("tool", ""))) == 0:
		return ""
	var item := _product_for(index)
	if Inventory.add_item(item, 1) > 0:
		return ""
	a.ready = false
	Skills.add_xp("farming", 5)
	Story.bump("products")
	changed.emit()
	return item


func _product_for(index: int) -> String:
	var a: Dictionary = animals[index]
	var info := animal_info(a.type)
	if info.has("big_product") and int(a.friendship) >= 600 and randf() < 0.5:
		return str(info.big_product)
	return str(info.product)


# ------------------------------------------------------------ chaque nuit
func new_day(season: int) -> Dictionary:
	var report := {"built": [], "fed": 0, "hungry": 0}
	for id: String in buildings:
		var b: Dictionary = buildings[id]
		if int(b.days_left) > 0:
			b.days_left -= 1
			if b.days_left == 0:
				b.built = true
				report.built.append(id)
	for i in animals.size():
		var a: Dictionary = animals[i]
		var b: Dictionary = buildings[a.building]
		a.age += 1
		if int(b.hay) > 0:
			b.hay -= 1
			a.fed = true
			report.fed += 1
			a.friendship = clampi(int(a.friendship) + FED_POINTS, 0, MAX_FRIENDSHIP)
			var info := animal_info(a.type)
			var winter_off: bool = info.get("no_winter", false) and season == 3
			if not winter_off and int(a.age) % int(info.get("every", 1)) == 0:
				a.ready = true
		else:
			a.fed = false
			report.hungry += 1
			a.friendship = clampi(int(a.friendship) + HUNGRY_POINTS, 0, MAX_FRIENDSHIP)
		a.petted = false
		a.brushed = false
	changed.emit()
	return report


func to_dict() -> Dictionary:
	return {"buildings": buildings.duplicate(true), "animals": animals.duplicate(true)}


func from_dict(saved: Dictionary) -> void:
	reset()
	var b: Dictionary = saved.get("buildings", {})
	for id: String in b:
		if buildings.has(id):
			buildings[id] = {"built": bool(b[id].get("built", false)), "days_left": int(b[id].get("days_left", 0)), "hay": int(b[id].get("hay", 0))}
	for a: Variant in saved.get("animals", []):
		if a is Dictionary:
			animals.append({
				"type": str(a.type), "name": str(a.name), "building": str(a.building),
				"friendship": int(a.get("friendship", 100)), "fed": bool(a.get("fed", false)),
				"petted": bool(a.get("petted", false)), "brushed": bool(a.get("brushed", false)),
				"ready": bool(a.get("ready", false)), "age": int(a.get("age", 0)),
			})
	changed.emit()
