extends Node
## Arbres à bois de la forêt : pins, platanes et chênes, dans la clairière
## des bûcherons (au nord de la ferme). On les abat à la hache pour beaucoup
## de bois ; ils laissent une souche (encore un peu de bois) et des graines
## (pomme de pin, boule de platane, gland) qu'on replante dans la forêt.
## Une souche oubliée finit par rejeter, et la forêt se reboise un peu
## toute seule si on l'a trop coupée.

signal changed
signal hit(cell: Vector2i)
signal felled(cell: Vector2i, type: String, from: Vector2i, place: String)

const TYPES := {
	"pine": {
		"name": "Pin", "seed": "pine_cone", "grow": 6, "hp": 8,
		"wood": [10, 14], "seeds": [1, 2], "extra": [],
	},
	"plane": {
		"name": "Platane", "seed": "plane_seed", "grow": 8, "hp": 10,
		"wood": [14, 18], "seeds": [1, 2], "extra": [],
	},
	"oak": {
		"name": "Chêne", "seed": "acorn", "grow": 10, "hp": 12,
		"wood": [12, 16], "seeds": [1, 2], "extra": ["hardwood", 2, 4],
	},
}
const STAGE_NAMES := ["Pousse de", "Jeune", "Petit", ""]
const STUMP_HP := 3
const STUMP_WOOD := [3, 5]
const STUMP_REGROW := 5  # jours avant qu'une souche oubliée ne rejette
const WILD_SPROUT := 0.25  # chance par nuit qu'un emplacement vide reparte (forêt clairsemée)

## Case -> {"type": String, "age": int, "hp": int, "stump": bool, "stump_age": int}
var trees: Dictionary = {}  # la forêt
var farm: Dictionary = {}  # arbres plantés à la ferme (même fonctionnement)
var seeded: bool = false


func reset() -> void:
	trees.clear()
	farm.clear()
	seeded = false


## Les arbres d'un lieu : "forest" (par défaut) ou "farm".
func of(place: String) -> Dictionary:
	return farm if place == "farm" else trees


## Plante les arbres d'origine de la forêt (une seule fois par partie).
func ensure_seeded() -> void:
	if seeded:
		return
	seeded = true
	for spot: Array in ForestMap.lumber_spots():
		var type: String = spot[1]
		trees[spot[0]] = {"type": type, "age": int(TYPES[type].grow), "hp": 0, "stump": false, "stump_age": 0}
		trees[spot[0]].hp = max_hp(spot[0])


## 0 pousse, 1 jeune, 2 petit arbre, 3 adulte.
func stage(cell: Vector2i, place: String = "forest") -> int:
	var t: Dictionary = of(place).get(cell, {})
	if t.is_empty():
		return -1
	var grow := int(TYPES[t.type].grow)
	if int(t.age) >= grow:
		return 3
	return clampi(int(t.age) * 3 / grow, 0, 2)


func is_stump(cell: Vector2i, place: String = "forest") -> bool:
	return of(place).has(cell) and bool(of(place)[cell].stump)


func max_hp(cell: Vector2i, place: String = "forest") -> int:
	if is_stump(cell, place):
		return STUMP_HP
	return [1, 2, 4, int(TYPES[of(place)[cell].type].hp)][stage(cell, place)]


## Nom affiché : « Pin », « Jeune chêne », « Souche de platane »...
func label(cell: Vector2i, place: String = "forest") -> String:
	var t: Dictionary = of(place)[cell]
	var name: String = TYPES[t.type].name
	if t.stump:
		return "Souche de " + name.to_lower()
	var s := stage(cell, place)
	return name if s == 3 else "%s %s" % [STAGE_NAMES[s], name.to_lower()]


func days_left(cell: Vector2i, place: String = "forest") -> int:
	var t: Dictionary = of(place)[cell]
	return maxi(0, int(TYPES[t.type].grow) - int(t.age))


func plant(cell: Vector2i, type: String, place: String = "forest") -> bool:
	if of(place).has(cell) or not TYPES.has(type):
		return false
	of(place)[cell] = {"type": type, "age": 0, "hp": 1, "stump": false, "stump_age": 0}
	changed.emit()
	return true


## Un coup de hache (`power` : force de la hache). Renvoie ce qui tombe :
## {"done": bool (arbre abattu ou souche arrachée), "drops": [ids]}.
func chop(cell: Vector2i, power: int, from: Vector2i, place: String = "forest") -> Dictionary:
	var out := {"done": false, "drops": [], "stump": false}
	var d := of(place)
	if not d.has(cell):
		return out
	var t: Dictionary = d[cell]
	t.hp = int(t.hp) - maxi(1, power)
	if int(t.hp) > 0:
		hit.emit(cell)
		return out
	out.done = true
	var info: Dictionary = TYPES[t.type]
	if t.stump:
		# Souche arrachée : un peu de bois, la case est libre
		out.stump = true
		for i in randi_range(STUMP_WOOD[0], STUMP_WOOD[1]):
			out.drops.append("wood")
		d.erase(cell)
		Skills.add_xp("foraging", 4)
		changed.emit()
		return out
	var s := stage(cell, place)
	if s == 3:
		var wood := randi_range(int(info.wood[0]), int(info.wood[1]))
		if Skills.roll("foraging", 6.0):
			wood += wood / 2
		for i in wood:
			out.drops.append("wood")
		for i in randi_range(int(info.seeds[0]), int(info.seeds[1])):
			out.drops.append(str(info.seed))
		var extra: Array = info.extra
		if not extra.is_empty():
			for i in randi_range(int(extra[1]), int(extra[2])):
				out.drops.append(str(extra[0]))
		Skills.add_xp("foraging", 15)
		Story.bump("trees_felled")
		# Il reste une souche
		t.stump = true
		t.stump_age = 0
		t.hp = STUMP_HP
		felled.emit(cell, str(t.type), from, place)
	else:
		# Un jeune arbre ne donne que quelques bûches ; la graine est rendue
		for i in [1, 2, 4][s]:
			out.drops.append("wood")
		if s == 0:
			out.drops.append(str(info.seed))
		Skills.add_xp("foraging", 2)
		d.erase(cell)
	changed.emit()
	return out


## Nuit : les arbres poussent, les souches oubliées rejettent, et les
## emplacements vides de la clairière se reboisent doucement.
func new_day() -> void:
	ensure_seeded()
	for place: String in ["forest", "farm"]:
		var d := of(place)
		for cell: Vector2i in d:
			var t: Dictionary = d[cell]
			if t.stump:
				t.stump_age = int(t.stump_age) + 1
				if int(t.stump_age) >= STUMP_REGROW:
					d[cell] = {"type": t.type, "age": 0, "hp": 1, "stump": false, "stump_age": 0}
				continue
			var before := stage(cell, place)
			t.age = int(t.age) + 1
			if stage(cell, place) != before:
				t.hp = max_hp(cell, place)  # il a grandi : plus solide
	for spot: Array in ForestMap.lumber_spots():
		if not trees.has(spot[0]) and randf() < WILD_SPROUT:
			trees[spot[0]] = {"type": spot[1], "age": 0, "hp": 1, "stump": false, "stump_age": 0}
	changed.emit()


func to_dict() -> Dictionary:
	return {"trees": _list(trees), "farm": _list(farm), "seeded": seeded}


func _list(d: Dictionary) -> Array:
	var list: Array = []
	for cell: Vector2i in d:
		var t: Dictionary = d[cell]
		list.append([cell.x, cell.y, t.type, int(t.age), int(t.hp), bool(t.stump), int(t.stump_age)])
	return list


func from_dict(data: Dictionary) -> void:
	reset()
	seeded = bool(data.get("seeded", false))
	for pair: Array in [[trees, "trees"], [farm, "farm"]]:
		for e: Variant in data.get(pair[1], []):
			var a: Array = e
			if a.size() >= 7 and TYPES.has(str(a[2])):
				(pair[0] as Dictionary)[Vector2i(int(a[0]), int(a[1]))] = {"type": str(a[2]), "age": int(a[3]), "hp": int(a[4]), "stump": bool(a[5]), "stump_age": int(a[6])}
