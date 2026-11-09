extends Node
## Machines de transformation posées à la ferme (data/machines.json) :
## bocal à conserves, pressoir, fumoir, presse à fromage. On y dépose un
## ingrédient en le touchant avec l'objet en main ; quelques nuits plus
## tard, le produit est prêt. La qualité de l'ingrédient passe au produit.

signal changed(cell: Vector2i)

var data: Dictionary = {}
var fruits: Array = []
var state: Dictionary = {}  # case -> {"machine", "output", "days"}
## Casiers posés dans l'eau : "carte:x,y" -> prise ("" si vide)
var pots: Dictionary = {}
## Meubles posés dans la maison : case -> objet
var furniture: Dictionary = {}
const POT_SEA := [["crab", 30], ["shrimp", 30], ["mussel", 25], ["oyster", 15]]
const POT_LAKE := [["crayfish", 65], ["mussel", 35]]
const POT_MAPS := ["farm", "village", "forest", "port"]


func _ready() -> void:
	var file := FileAccess.open("res://data/machines.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed.get("machines", {})
			fruits = parsed.get("fruits", [])


func reset() -> void:
	state.clear()
	pots.clear()
	furniture.clear()


static func pot_key(map_id: String, cell: Vector2i) -> String:
	return "%s:%d,%d" % [map_id, cell.x, cell.y]


func has_pot(map_id: String, cell: Vector2i) -> bool:
	return pots.has(pot_key(map_id, cell))


func pot_catch(map_id: String, cell: Vector2i) -> String:
	return str(pots.get(pot_key(map_id, cell), ""))


func pots_on(map_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key: String in pots:
		if key.get_slice(":", 0) == map_id:
			var xy := key.get_slice(":", 1).split(",")
			out.append(Vector2i(int(xy[0]), int(xy[1])))
	return out


func place_pot(map_id: String, cell: Vector2i) -> void:
	pots[pot_key(map_id, cell)] = ""


func take_pot(map_id: String, cell: Vector2i) -> void:
	pots.erase(pot_key(map_id, cell))


## Vide le casier : renvoie la prise (ou "").
func collect_pot(map_id: String, cell: Vector2i) -> String:
	var got := pot_catch(map_id, cell)
	if got == "" or Inventory.add_item(got, 1) > 0:
		return ""
	pots[pot_key(map_id, cell)] = ""
	return got


func is_machine(id: String) -> bool:
	return data.has(id)


## Catégorie d'un ingrédient pour les machines : fruit, légume, poisson, ou
## son propre identifiant (lait, œuf...).
func category(item_id: String) -> String:
	var base := GameData.base_id(item_id)
	var type := str(GameData.item(base).get("type", ""))
	if base in fruits:
		return "fruit"
	if type == "crop":
		return "vegetable"
	if type == "fish":
		# Les poissons légendaires sont trop précieux pour le fumoir
		return "legendary" if GameData.fish(base).get("legendary", false) else "fish"
	return base


## Ce que donnerait cet ingrédient dans cette machine : [produit, jours] ou [].
func recipe(machine: String, item_id: String) -> Array:
	var m: Dictionary = data.get(machine, {})
	if m.has("aging"):
		# Tonneau : un cran de qualité en plus (produits artisanaux, fromage)
		var b := GameData.base_id(item_id)
		var aged: bool = str(GameData.item(b).get("type", "")) == "artisan" or b == "cheese"
		var q := GameData.quality_of(item_id)
		if not aged or q >= 3:
			return []
		return [GameData.with_quality(b, q + 1), int(m.aging)]
	var accepts: Dictionary = m.get("accepts", {})
	var r: Variant = accepts.get(category(item_id))
	if r == null:
		return []
	var base := GameData.base_id(item_id)
	var tpl := str(r[0])
	# Produit qui dépend de l'ingrédient (« jam:melon ») ou fixe (« cheese »)
	var product := tpl + ":" + base if GameData.item(tpl).has("from") else tpl
	return [GameData.with_quality(product, GameData.quality_of(item_id)), int(r[1])]


func busy(cell: Vector2i) -> bool:
	return state.has(cell) and int(state[cell].days) > 0


func ready(cell: Vector2i) -> bool:
	return state.has(cell) and int(state[cell].days) <= 0


## Dépose un ingrédient. Renvoie le nombre de nuits, ou -1 si refusé.
func insert(cell: Vector2i, machine: String, item_id: String) -> int:
	if state.has(cell):
		return -1
	var r := recipe(machine, item_id)
	if r.is_empty():
		return -1
	state[cell] = {"machine": machine, "output": str(r[0]), "days": int(r[1])}
	changed.emit(cell)
	return int(r[1])


## Machine qui travaille seule (ruche) : elle commence aussitôt posée.
func start_auto(cell: Vector2i, machine: String) -> void:
	var auto: Array = data.get(machine, {}).get("auto", [])
	if auto.is_empty():
		return
	var q := GameData.roll_quality(Skills.level("farming"))
	state[cell] = {"machine": machine, "output": GameData.with_quality(str(auto[0]), q), "days": int(auto[1])}
	changed.emit(cell)


## Récupère le produit prêt (renvoie son identifiant, ou "").
func collect(cell: Vector2i) -> String:
	if not ready(cell):
		return ""
	var out := str(state[cell].output)
	if Inventory.add_item(out, 1) > 0:
		return ""
	var machine := str(state[cell].machine)
	state.erase(cell)
	start_auto(cell, machine)
	Story.bump("products")
	changed.emit(cell)
	return out


## La machine est retirée de la ferme : ce qu'elle contenait est perdu.
func remove(cell: Vector2i) -> void:
	state.erase(cell)


func new_day() -> void:
	# Chaque nuit, chaque casier vide attrape quelque chose
	for key: String in pots:
		if str(pots[key]) != "":
			continue
		var table: Array = POT_SEA if key.begins_with("port:") else POT_LAKE
		var total := 0
		for e: Array in table:
			total += int(e[1])
		var roll := randi() % total
		for e: Array in table:
			roll -= int(e[1])
			if roll < 0:
				pots[key] = GameData.with_quality(str(e[0]), GameData.roll_quality(Skills.level("fishing") / 2))
				break
	for cell: Vector2i in state:
		# Les abeilles dorment en hiver
		if data.get(str(state[cell].machine), {}).has("auto") and TimeManager.season == 3:
			continue
		if int(state[cell].days) > 0:
			state[cell].days = int(state[cell].days) - 1
			if int(state[cell].days) == 0:
				# Ruche près de fleurs cultivées : un miel parfumé, plus cher
				if str(state[cell].machine) == "beehive":
					var flower := FarmState.flower_near(cell)
					if flower != "":
						state[cell].output = GameData.with_quality("flower_honey:" + flower, GameData.quality_of(str(state[cell].output)))
				changed.emit(cell)


func to_dict() -> Dictionary:
	var out := {}
	for cell: Vector2i in state:
		out["%d,%d" % [cell.x, cell.y]] = state[cell].duplicate()
	var furn := {}
	for cell: Vector2i in furniture:
		furn["%d,%d" % [cell.x, cell.y]] = furniture[cell]
	return {"machines": out, "pots": pots.duplicate(), "furniture": furn}


func from_dict(all: Dictionary) -> void:
	reset()
	var saved: Dictionary = all.get("machines", {})
	pots = all.get("pots", {}).duplicate()
	var furn: Dictionary = all.get("furniture", {})
	for key: String in furn:
		var xy := key.split(",")
		furniture[Vector2i(int(xy[0]), int(xy[1]))] = str(furn[key])
	for key: String in saved:
		var parts := key.split(",")
		var s: Dictionary = saved[key]
		state[Vector2i(int(parts[0]), int(parts[1]))] = {"machine": str(s.get("machine", "")), "output": str(s.get("output", "")), "days": int(s.get("days", 0))}
