extends Node
## État de la ferme : tuiles labourées/arrosées, cultures, coffre d'expédition.
## Indépendant de l'affichage : la scène Farm ne fait que le refléter.

var tiles: Dictionary = {}  # Vector2i -> {"watered": bool, "crop": String, "age": int}
var shipping: Array = []  # [{"id": String, "qty": int}]
var objects: Dictionary = {}  # Vector2i -> "sprinkler" | "quality_sprinkler" | "chest"
var chests: Dictionary = {}  # Vector2i -> Array de cases (comme Inventory.slots)
## Débris à défricher : Vector2i -> {"type": weed|twig|stone|stump, "hp": int}
var debris: Dictionary = {}
const DEBRIS := {
	"weed": {"hp": 1, "tools": ["scythe", "hoe", "axe", "pickaxe", "watering_can", "weapon"], "drops": [["fiber", 1, 1, 0.6]], "xp": 1},
	"twig": {"hp": 1, "tools": ["axe"], "drops": [["wood", 1, 2, 1.0]], "xp": 2},
	"stone": {"hp": 1, "tools": ["pickaxe"], "drops": [["stone", 1, 1, 1.0]], "xp": 2},
	"stump": {"hp": 5, "tools": ["axe"], "drops": [["wood", 8, 12, 1.0]], "xp": 12},
	# Tombée du ciel une nuit d'étoiles filantes
	"meteorite": {"hp": 6, "tools": ["pickaxe"], "drops": [["meteorite_fragment", 2, 3, 1.0], ["iron_ore", 3, 5, 1.0], ["gold_ore", 1, 2, 0.6], ["amethyst", 1, 1, 0.3]], "xp": 30},
}
const CHEST_SIZE := 36

const SPRINKLER_RANGE := {
	"sprinkler": [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN],
	"quality_sprinkler": [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
		Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	],
	# L'arroseur connecté de l'Atelier Néo : un carré de 5 cases de côté
	"smart_sprinkler": [
		Vector2i(-2, -2), Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2), Vector2i(2, -2),
		Vector2i(-2, -1), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
		Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
	],
}
const FERTILIZER_EVERY := 3  # une nuit de croissance bonus toutes les 3 nuits arrosées

## Arbres fruitiers : Vector2i -> {"type": String, "age": int, "fruits": int}
var trees: Dictionary = {}
var tree_data: Dictionary = {}  # data/fruit_trees.json
const MAX_FRUITS := 3
## Nature : sillon vide et sec -> mauvaises herbes ; culture oubliée -> fanée
const NEGLECT_NIGHTS := 3  # sillon vide et sec -> herbes
const WITHER_NIGHTS := 6  # culture sans eau -> fanée (puis herbes : 9 nuits en tout)
const WEED_SPREAD := 0.08  # chance par nuit qu'une herbe gagne une case voisine
const MAX_DEBRIS := 160
const GREENHOUSE_PLOT_RECT := Rect2i(3, 20, 8, 6)
var last_night: Dictionary = {}  # ce que la nature a fait cette nuit
## La serre (une fois construite) : intérieur cultivable en toute saison
const GREENHOUSE_PLOT := Vector2i(3, 20)
const GREENHOUSE_INNER := Rect2i(4, 21, 6, 4)


func _ready() -> void:
	var file := FileAccess.open("res://data/fruit_trees.json", FileAccess.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			tree_data = data


func in_greenhouse(cell: Vector2i) -> bool:
	return GREENHOUSE_INNER.has_point(cell) and Animals.is_built("greenhouse")


func plant_tree(cell: Vector2i, type: String) -> bool:
	if objects.has(cell) or tiles.has(cell) or not tree_data.has(type):
		return false
	objects[cell] = "tree"
	trees[cell] = {"type": type, "age": 0, "fruits": 0}
	return true


## Stade d'un arbre : 0 jeune pousse, 1 arbuste, 2 adulte (donne des fruits).
func tree_stage(cell: Vector2i) -> int:
	var t: Dictionary = trees[cell]
	var grow := int(tree_data[t.type].grow_days)
	if int(t.age) >= grow:
		return 2
	return 1 if int(t.age) >= grow / 2 else 0


## Secoue l'arbre : renvoie [fruit, nombre] (nombre = 0 s'il n'y a rien).
func shake_tree(cell: Vector2i) -> Array:
	var t: Dictionary = trees[cell]
	var n := int(t.fruits)
	t.fruits = 0
	return [str(tree_data[t.type].fruit), n]


func reset() -> void:
	tiles.clear()
	shipping.clear()
	objects.clear()
	chests.clear()
	debris.clear()
	trees.clear()
	fences.clear()


func is_tilled(cell: Vector2i) -> bool:
	return tiles.has(cell)


func is_watered(cell: Vector2i) -> bool:
	return tiles.has(cell) and tiles[cell].watered


func till(cell: Vector2i) -> void:
	if not tiles.has(cell):
		tiles[cell] = {"watered": TimeManager.is_raining(), "crop": "", "age": 0}
		EventBus.farm_tile_changed.emit(cell)


## Météo de la nuit : gel (pousses), orage d'été (cultures couchées). Renvoie
## true si la culture a souffert (elle ne pousse pas cette nuit).
func _weather_hurts(_cell: Vector2i, t: Dictionary, frost: bool) -> bool:
	if frost and int(t.age) <= int(GameData.crop(str(t.crop)).get("stage_days", [1])[0]):
		t.age = maxi(0, int(t.age) - 1)
		last_night.frost += 1
		return true
	if weather_events and TimeManager.storm_yesterday and randf() < 0.1:
		t.age = maxi(0, int(t.age) - 2)
		last_night.storm += 1
		return true
	return false


## Un objet (ruche, épouvantail...) à moins de `radius` cases (carré).
func _near_object(cell: Vector2i, id: String, radius: int) -> bool:
	for c: Vector2i in objects:
		if objects[c] == id and absi(c.x - cell.x) <= radius and absi(c.y - cell.y) <= radius:
			return true
	return false


## Corbeaux : sur une grande ferme, ils viennent parfois picorer une ou deux
## cultures loin des épouvantails (rayon 4) ; le chien les fait fuir souvent.
const SCARECROW_RADIUS := 4


func _crows() -> void:
	var exposed: Array = []
	var total := 0
	for cell: Vector2i in tiles:
		if str(tiles[cell].crop) == "" or in_greenhouse(cell):
			continue
		total += 1
		if not _near_object(cell, "scarecrow", SCARECROW_RADIUS):
			exposed.append(cell)
	if not weather_events or total < 12 or exposed.is_empty() or randf() > (0.25 if Pet.kind == "dog" else 0.5):
		return
	exposed.shuffle()
	for i in mini(1 + total / 25, exposed.size()):
		var t: Dictionary = tiles[exposed[i]]
		t.crop = ""
		t.age = 0
		last_night.crows += 1


## Croisements : deux cultures mûres et différentes, côte à côte, donnent
## parfois des graines hybrides (cultures cristal, récolte double).
func _crossbreed() -> void:
	for cell: Vector2i in tiles:
		if not is_mature(cell):
			continue
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var other := cell + d
			if tiles.has(other) and is_mature(other) and get_crop(other) != get_crop(cell) and randf() < 0.05:
				if Inventory.add_item("seed_hybrid", 1) == 0:
					last_night.hybrid += 1


## Beauté de la ferme : décor, chemins, clôtures, arbres et fleurs. Le
## dimanche, une belle ferme attire des visiteurs du village.
const BEAUTY := {
	"garden_bench": 3, "garden_lantern": 3, "flower_bed": 4, "garden_fountain": 10, "design_sculpture": 14, "scarecrow": 1, "golden_statue": 40,
	"path_wood": 0.5, "path_stone": 0.5, "tree": 2, "wood_tree": 1, "beehive": 2,
}
const VISITOR_TIERS := [25, 60, 100]


func beauty() -> int:
	var score := 0.0
	for cell: Vector2i in objects:
		score += float(BEAUTY.get(objects[cell], 0))
	score += fences.size() * 0.3
	for cell: Vector2i in tiles:
		if str(tiles[cell].crop) in FLOWER_CROPS:
			score += 0.5
	return int(score)


## Nombre de visiteurs le dimanche selon la beauté.
func visitors_count() -> int:
	var n := 0
	for t: int in VISITOR_TIERS:
		if beauty() >= t:
			n += 1
	return n


## Fleur cultivée près d'une case (pour le miel parfumé), "" sinon.
const FLOWER_CROPS := ["sunflower", "daffodil", "poppy"]


func flower_near(cell: Vector2i, radius: int = 4) -> String:
	for c: Vector2i in tiles:
		if str(tiles[c].crop) in FLOWER_CROPS and absi(c.x - cell.x) <= radius and absi(c.y - cell.y) <= radius:
			return str(tiles[c].crop)
	return ""


func water(cell: Vector2i) -> void:
	if tiles.has(cell):
		tiles[cell].watered = true
		tiles[cell].water_count = int(tiles[cell].get("water_count", 0)) + 1
		EventBus.farm_tile_changed.emit(cell)


## Aléas de la nuit (gel, orage, pollinisation) : coupés dans les tests
## automatiques, qui comptent les jours de pousse au jour près.
var weather_events: bool = DisplayServer.get_name() != "headless"

## Objets posés sur lesquels on marche (chemins)
const WALKABLE_OBJECTS := ["path_wood", "path_stone"]

## Clôtures : posées sur les bords des cases, pas au milieu. Clé « h:x,y »
## (bord du haut de la case x,y) ou « v:x,y » (bord gauche de la case).
signal fences_changed
var fences: Dictionary = {}


## Le bord commun à deux cases voisines ("" si elles ne se touchent pas).
static func edge_between(a: Vector2i, b: Vector2i) -> String:
	match b - a:
		Vector2i.UP:
			return "h:%d,%d" % [a.x, a.y]
		Vector2i.DOWN:
			return "h:%d,%d" % [b.x, b.y]
		Vector2i.LEFT:
			return "v:%d,%d" % [a.x, a.y]
		Vector2i.RIGHT:
			return "v:%d,%d" % [b.x, b.y]
	return ""


## [horizontal ?, case] d'un bord.
static func edge_parts(edge: String) -> Array:
	var xy := edge.substr(2).split(",")
	return [edge.begins_with("h"), Vector2i(int(xy[0]), int(xy[1]))]


func add_fence(edge: String) -> bool:
	if edge == "" or fences.has(edge):
		return false
	fences[edge] = true
	fences_changed.emit()
	return true


func remove_fence(edge: String) -> bool:
	if not fences.erase(edge):
		return false
	fences_changed.emit()
	return true


func place_object(cell: Vector2i, id: String) -> void:
	objects[cell] = id
	if id == "chest":
		var slots: Array = []
		slots.resize(CHEST_SIZE)
		chests[cell] = slots
	EventBus.farm_tile_changed.emit(cell)


func remove_object(cell: Vector2i) -> String:
	var id: String = objects.get(cell, "")
	objects.erase(cell)
	chests.erase(cell)
	EventBus.farm_tile_changed.emit(cell)
	return id


func chest_is_empty(cell: Vector2i) -> bool:
	for slot: Variant in chests.get(cell, []):
		if slot != null:
			return false
	return true


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
		var price := int(int(GameData.item(entry.id).get("sell", 0)) * Projects.sell_factor(str(entry.id)) * Soul.sell_factor(str(entry.id)) * Partners.sell_factor())
		var line_total: int = price * int(entry.qty)
		total += line_total
		sold.append({"id": entry.id, "qty": entry.qty, "total": line_total})
	shipping.clear()
	report["sold"] = sold
	report["earned"] = total
	return total


## Simulation d'une nuit : croissance des cultures arrosées, fin de saison.
func advance_day(new_season: int, raining: bool) -> void:
	last_night = {"weeds": 0, "withered": 0, "spread": 0, "new": 0, "dried": 0, "season": 0,
		"frost": 0, "storm": 0, "heat": 0, "crows": 0, "hybrid": 0, "bees": 0}
	# Gel des premières nuits de printemps (sans pluie) : les pousses perdent un jour
	var frost := weather_events and new_season == 0 and TimeManager.day <= 8 and not raining and randf() < 0.25
	var reclaimed: Array[Vector2i] = []
	for cell: Vector2i in tiles:
		var t: Dictionary = tiles[cell]
		var sheltered := in_greenhouse(cell)
		# Terrain négligé : la nature reprend ses droits
		if t.crop == "":
			t.neglect = 0 if t.watered else int(t.get("neglect", 0)) + 1
			if int(t.neglect) >= NEGLECT_NIGHTS:
				reclaimed.append(cell)
		else:
			t.dry = 0 if t.watered else int(t.get("dry", 0)) + 1
			if not sheltered and int(t.dry) >= WITHER_NIGHTS:
				t.crop = ""  # oubliée trop longtemps, la culture se fane
				t.age = 0
				t.dry = 0
				t.neglect = 0
				last_night.withered += 1
		if t.crop != "":
			if not sheltered and not GameData.crop_in_season(t.crop, new_season):
				t.crop = ""  # la culture meurt hors saison (sauf dans la serre)
				t.age = 0
				last_night.season += 1
			elif sheltered or not _weather_hurts(cell, t, frost):
				if not t.watered:
					pass
				elif TimeManager.heat_yesterday and not sheltered and int(t.get("water_count", 1)) < 2:
					last_night.heat += 1  # canicule : un seul arrosage n'a pas suffi
				else:
					t.age += 1
					# Pollinisation : une ruche toute proche fait parfois pousser plus vite
					if weather_events and _near_object(cell, "beehive", 3) and randf() < 0.25:
						t.age += 1
						last_night.bees += 1
				if t.get("fert", false):
					t.fert_progress = int(t.get("fert_progress", 0)) + 1
					if t.fert_progress >= FERTILIZER_EVERY:
						t.fert_progress = 0
						t.age += 1
		t.watered = raining and not sheltered  # la pluie n'entre pas dans la serre
		t.water_count = 2 if t.watered else 0
	# Sillons vides et secs depuis plusieurs nuits : les mauvaises herbes s'y
	# installent (dans la serre, la terre redevient simplement nue).
	for cell in reclaimed:
		tiles.erase(cell)
		if in_greenhouse(cell):
			last_night.dried += 1
		else:
			debris[cell] = {"type": "weed", "hp": int(DEBRIS.weed.hp)}
			last_night.weeds += 1
	_wild_growth()
	_crows()
	_crossbreed()
	# Les arbres grandissent ; adultes, ils donnent un fruit par jour en saison.
	for cell: Vector2i in trees:
		var tree: Dictionary = trees[cell]
		tree.age = int(tree.age) + 1
		if tree_stage(cell) == 2 and int(tree_data[tree.type].season) == new_season:
			tree.fruits = mini(int(tree.fruits) + 1, MAX_FRUITS)
	# Les arroseurs arrosent au lever du jour.
	for cell: Vector2i in objects:
		for offset: Vector2i in SPRINKLER_RANGE.get(objects[cell], []):
			if tiles.has(cell + offset):
				tiles[cell + offset].watered = true
				tiles[cell + offset].water_count = int(tiles[cell + offset].get("water_count", 0)) + 1


## La nature gagne du terrain sur ce qui n'est pas entretenu : les mauvaises
## herbes se propagent autour d'elles, et quelques herbes, branches et
## pierres apparaissent dans les coins laissés à l'abandon.
func _wild_growth() -> void:
	var wild := _wild_cells()
	if wild.is_empty():
		return
	# Propagation : chaque herbe peut gagner une case voisine libre
	var spread: Array[Vector2i] = []
	for cell: Vector2i in debris:
		if debris[cell].type != "weed" or randf() >= WEED_SPREAD:
			continue
		var d: Vector2i = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][randi() % 4]
		if _is_free_wild(cell + d, wild):
			spread.append(cell + d)
	for cell in spread:
		if debris.size() >= MAX_DEBRIS:
			break
		debris[cell] = {"type": "weed", "hp": int(DEBRIS.weed.hp)}
		last_night.spread += 1
	# Nouvelles pousses, branches tombées, pierres remontées
	for i in randi_range(1, 3):
		if debris.size() >= MAX_DEBRIS:
			break
		var cell: Vector2i = wild[randi() % wild.size()]
		if not _is_free_wild(cell, wild):
			continue
		var roll := randf()
		var type := "weed" if roll < 0.6 else ("twig" if roll < 0.85 else "stone")
		debris[cell] = {"type": type, "hp": int(DEBRIS[type].hp)}
		last_night.new += 1


var _wild_cache: Array = []


## Cases d'herbe de la ferme où la nature peut pousser : ni chemins, ni
## bâtiments, ni abords de la maison.
func _wild_cells() -> Array:
	if _wild_cache.is_empty():
		var footprints := [Rect2i(4, 3, 7, 7), Rect2i(28, 2, 10, 5), GREENHOUSE_PLOT_RECT]
		for y in Farm.MAP.size():
			var row := String(Farm.MAP[y])
			for x in row.length():
				var cell := Vector2i(x, y)
				if not row[x] in [".", ",", "'"]:
					continue
				if footprints.any(func(r: Rect2i) -> bool: return r.has_point(cell)):
					continue
				_wild_cache.append(cell)
	return _wild_cache


func _is_free_wild(cell: Vector2i, wild: Array) -> bool:
	return cell in wild and not tiles.has(cell) and not objects.has(cell) and not debris.has(cell)


func to_dict() -> Dictionary:
	var out := {}
	for cell: Vector2i in tiles:
		out["%d,%d" % [cell.x, cell.y]] = tiles[cell].duplicate()
	var objs := {}
	for cell: Vector2i in objects:
		objs["%d,%d" % [cell.x, cell.y]] = objects[cell]
	var junk := {}
	for cell: Vector2i in debris:
		junk["%d,%d" % [cell.x, cell.y]] = debris[cell].duplicate()
	var boxes := {}
	for cell: Vector2i in chests:
		boxes["%d,%d" % [cell.x, cell.y]] = chests[cell].duplicate(true)
	var orchard := {}
	for cell: Vector2i in trees:
		orchard["%d,%d" % [cell.x, cell.y]] = trees[cell].duplicate()
	return {"tiles": out, "shipping": shipping.duplicate(true), "objects": objs, "chests": boxes, "debris": junk, "trees": orchard, "fences": fences.keys()}


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
			"neglect": int(t.get("neglect", 0)),
			"dry": int(t.get("dry", 0)),
		}
	var objs: Dictionary = data.get("objects", {})
	for key: String in objs:
		var parts := key.split(",")
		var c := Vector2i(int(parts[0]), int(parts[1]))
		if str(objs[key]) == "fence":
			fences["h:%d,%d" % [c.x, c.y + 1]] = true  # ancienne clôture « au milieu » : posée sur le bord du bas
			continue
		objects[c] = str(objs[key])
	for edge: Variant in data.get("fences", []):
		fences[str(edge)] = true
	var junk: Dictionary = data.get("debris", {})
	for key: String in junk:
		var parts := key.split(",")
		debris[Vector2i(int(parts[0]), int(parts[1]))] = {"type": str(junk[key].type), "hp": int(junk[key].hp)}
	var boxes: Dictionary = data.get("chests", {})
	for key: String in boxes:
		var parts := key.split(",")
		var slots: Array = []
		slots.resize(CHEST_SIZE)
		var content: Array = boxes[key]
		for i in mini(content.size(), CHEST_SIZE):
			if content[i] is Dictionary:
				slots[i] = {"id": str(content[i].id), "qty": int(content[i].qty)}
		chests[Vector2i(int(parts[0]), int(parts[1]))] = slots
	var orchard: Dictionary = data.get("trees", {})
	for key: String in orchard:
		var parts := key.split(",")
		var t: Dictionary = orchard[key]
		trees[Vector2i(int(parts[0]), int(parts[1]))] = {"type": str(t.type), "age": int(t.age), "fruits": int(t.get("fruits", 0))}
	for entry: Variant in data.get("shipping", []):
		shipping.append({"id": str(entry.id), "qty": int(entry.qty)})
