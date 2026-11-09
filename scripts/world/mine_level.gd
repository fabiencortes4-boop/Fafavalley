class_name MineLevel
extends WorldMap
## Un niveau de la mine, généré au hasard (grotte par automate cellulaire).
## Le même jour, un niveau a toujours la même forme. Rochers à casser à la
## pioche (minerais selon la profondeur), un escalier qui descend caché sous
## l'un d'eux, monstres plus nombreux et plus forts en descendant.
## On change d'étage en marchant sur les escaliers. Tous les 5 étages, un
## ascenseur ; tous les 15 étages, un coffre avec une meilleure arme.

const WIDTH := 40  # 640 px : plus large que les écrans les plus allongés
const HEIGHT := 24
const MAX_LEVEL := 30
const ELEVATOR_STEP := 5
const VILLAGE_EXIT := Vector2i(30, 4)  # devant l'entrée de la mine, au village

## type -> [tuile, coups de pioche, [[objet, min, max, chance], ...]]
const ROCKS := {
	"stone": [WorldTiles.MINE_ROCK, 1, [["stone", 1, 2, 1.0]]],
	"pebbles": [WorldTiles.MINE_ROCK_SMALL, 1, [["stone", 1, 1, 0.7]]],
	"coal": [WorldTiles.MINE_ROCK_COAL, 2, [["coal", 1, 2, 1.0], ["stone", 1, 1, 0.5]]],
	"copper": [WorldTiles.MINE_ROCK_COPPER, 2, [["copper_ore", 1, 3, 1.0]]],
	"iron": [WorldTiles.MINE_ROCK_IRON, 3, [["iron_ore", 1, 2, 1.0]]],
	"gold": [WorldTiles.MINE_ROCK_GOLD, 4, [["gold_ore", 1, 2, 1.0]]],
	"gem": [WorldTiles.MINE_ROCK_GEM, 3, []],
	# Étages gelés (10-19) et de lave (20-29) : leurs trésors propres
	"frost": [WorldTiles.MINE_ROCK_GEM, 3, [["frost_crystal", 1, 1, 1.0], ["stone", 1, 1, 0.5]]],
	"magma": [WorldTiles.MINE_ROCK_GEM, 4, [["fire_opal", 1, 1, 1.0], ["coal", 1, 2, 0.6]]],
}


## Thème de l'étage : terre (1-9), glace (10-19), lave (20-29), le fond (30).
static func theme_for(depth: int) -> String:
	if depth >= 30:
		return "deep"
	if depth >= 20:
		return "lava"
	if depth >= 10:
		return "ice"
	return "earth"
## Coffres des paliers (tous les 15 étages) : niveau -> arme
const TREASURES := {15: "steel_sword", 30: "firmin_blade"}

## On arrive par l'escalier du dessous (en remontant) : apparaître à côté.
static var arrive_from_below: bool = false

var level: int = 1

var _rows: Array = []
var _rng := RandomNumberGenerator.new()
var _rocks: TileMapLayer
var _rock_data: Dictionary = {}  # Vector2i -> {"type": String, "hp": int}
var _ladder_cell: Vector2i = Vector2i(-1, -1)
var _ladder_found: bool = false
var _monster_cells: Array[Vector2i] = []
var _light: PointLight2D
var _up_cell: Vector2i
var elevator_cell: Vector2i = Vector2i(-1, -1)
var treasure_cell: Vector2i = Vector2i(-1, -1)
var _from_below: bool = false
var _initial_rocks: int = 0
## Cordes d'urgence (à côté des escaliers des premiers étages) : on tire
## dessus et l'on est remonté à la surface, sans effort.
const ROPE_LEVELS := 10
var rope_cells: Array[Vector2i] = []

## Mémoire de la journée : chaque étage garde ses rochers cassés, son
## escalier trouvé et ses monstres vaincus jusqu'au lendemain. On peut
## ainsi remonter par le chemin déjà dégagé, même sans énergie.
static var _memory: Dictionary = {}  # niveau -> {"broken", "ladder", "killed"}
static var _memory_day: int = -1


func _mem() -> Dictionary:
	if _memory_day != Marriage.day_number():
		_memory.clear()
		_memory_day = Marriage.day_number()
	if not _memory.has(level):
		_memory[level] = {"broken": {}, "ladder": Vector2i(-1, -1), "killed": {}}
	return _memory[level]


static func forget_all() -> void:
	_memory.clear()
	_memory_day = -1


## Sauvegarde : la mémoire du jour suit la partie (on retrouve ses étages
## dégagés après avoir fermé le jeu).
static func memory_to_dict() -> Dictionary:
	var levels := {}
	for lvl: int in _memory:
		var m: Dictionary = _memory[lvl]
		levels[str(lvl)] = {
			"broken": (m.broken as Dictionary).keys().map(func(c: Vector2i) -> Array: return [c.x, c.y]),
			"killed": (m.killed as Dictionary).keys().map(func(c: Vector2i) -> Array: return [c.x, c.y]),
			"ladder": [m.ladder.x, m.ladder.y],
		}
	return {"day": _memory_day, "levels": levels}


static func memory_from_dict(data: Dictionary) -> void:
	forget_all()
	_memory_day = int(data.get("day", -1))
	var levels: Dictionary = data.get("levels", {})
	for key: String in levels:
		var src: Dictionary = levels[key]
		var m := {"broken": {}, "ladder": Vector2i(-1, -1), "killed": {}}
		for c: Array in src.get("broken", []):
			m.broken[Vector2i(int(c[0]), int(c[1]))] = true
		for c: Array in src.get("killed", []):
			m.killed[Vector2i(int(c[0]), int(c[1]))] = true
		var l: Array = src.get("ladder", [-1, -1])
		m.ladder = Vector2i(int(l[0]), int(l[1]))
		_memory[int(key)] = m


func setup(depth: int) -> void:
	level = clampi(depth, 1, MAX_LEVEL)
	map_id = "mine:%d" % level


func display_name() -> String:
	return "Mine - niveau %d" % level


# ------------------------------------------------------------ génération
func _map_rows() -> Array:
	if _rows.is_empty():
		_generate()
	return _rows


func _generate() -> void:
	_rng.seed = hash([TimeManager.year, TimeManager.season, TimeManager.day, level])
	var wall: Array = []
	var region: Array[Vector2i] = []
	for attempt in 12:
		wall = _cave()
		region = _largest_region(wall)
		if region.size() > WIDTH * HEIGHT * 0.35:
			break
	var floor_set := {}
	for c in region:
		floor_set[c] = true
	# Échelle de sortie : une case dont la voisine du dessous est libre.
	var up := region[0]
	for i in 200:
		var c: Vector2i = region[_rng.randi() % region.size()]
		if floor_set.has(c + Vector2i.DOWN) and floor_set.has(c + Vector2i.DOWN * 2):
			up = c
			break
	_spawn_cell = up + Vector2i.DOWN
	_up_cell = up
	# Ascenseur (tous les 5 étages) et coffre (tous les 15) près de l'arrivée
	var reserved := {up: true, _spawn_cell: true}
	# Corde d'urgence à côté de l'escalier qui remonte
	if level <= ROPE_LEVELS:
		for c: Vector2i in [up + Vector2i.LEFT, up + Vector2i.RIGHT, _spawn_cell + Vector2i.LEFT, _spawn_cell + Vector2i.RIGHT]:
			if floor_set.has(c) and not reserved.has(c):
				rope_cells.append(c)
				reserved[c] = true
				break
	if level % ELEVATOR_STEP == 0:
		elevator_cell = _free_near(_spawn_cell, floor_set, reserved)
		reserved[elevator_cell] = true
	if TREASURES.has(level):
		treasure_cell = _free_near(_spawn_cell, floor_set, reserved)
		reserved[treasure_cell] = true
	# Rochers et monstres
	var rock_cells: Array[Vector2i] = []
	var density := 0.2 + level * 0.004
	for c in region:
		var d: Vector2i = c - _spawn_cell
		if reserved.has(c) or absi(d.x) + absi(d.y) <= 2:
			continue
		if _rng.randf() < density:
			_rock_data[c] = {"type": _rock_type(), "hp": 0}
			rock_cells.append(c)
	for c: Vector2i in _rock_data:
		_rock_data[c].hp = ROCKS[_rock_data[c].type][1]
	if level < MAX_LEVEL and not rock_cells.is_empty():
		_ladder_cell = rock_cells[_rng.randi() % rock_cells.size()]
	# Ce qu'on a déjà fait ici aujourd'hui : rochers cassés, escalier trouvé
	var mem := _mem()
	for c: Vector2i in mem.broken:
		_rock_data.erase(c)
	if mem.ladder != Vector2i(-1, -1):
		_ladder_cell = mem.ladder
		_rock_data.erase(_ladder_cell)
	# En remontant : l'escalier qui descend est déjà dégagé, on arrive à côté
	_from_below = arrive_from_below and _ladder_cell != Vector2i(-1, -1)
	arrive_from_below = false
	if _from_below:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				_rock_data.erase(_ladder_cell + Vector2i(dx, dy))
		for d: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			if floor_set.has(_ladder_cell + d) and not reserved.has(_ladder_cell + d):
				_spawn_cell = _ladder_cell + d
				break
	var count := mini(2 + level / 3, 10)
	for i in 300:
		if _monster_cells.size() >= count:
			break
		var c: Vector2i = region[_rng.randi() % region.size()]
		var d: Vector2i = c - _spawn_cell
		if absi(d.x) + absi(d.y) > 7 and not _rock_data.has(c) and not c in _monster_cells and not reserved.has(c):
			_monster_cells.append(c)
	_monster_cells.assign(_monster_cells.filter(func(c: Vector2i) -> bool: return not mem.killed.has(c)))
	# Plan ASCII : # mur, _ sol, U échelle montante
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			var c := Vector2i(x, y)
			row += "U" if c == up else ("_" if floor_set.has(c) else "#")
		_rows.append(row)


## Case libre (sol) proche d'une case, à 2-4 pas, hors cases réservées.
func _free_near(center: Vector2i, floor_set: Dictionary, reserved: Dictionary) -> Vector2i:
	for radius in range(2, 6):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var c := center + Vector2i(dx, dy)
				if absi(dx) + absi(dy) != radius or reserved.has(c) or not floor_set.has(c):
					continue
				# Il faut pouvoir s'en approcher : un voisin libre
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
					if floor_set.has(c + d) and not reserved.has(c + d):
						return c
	return center + Vector2i.RIGHT


## Niveaux accessibles par l'ascenseur : 1 puis tous les 5 étages atteints.
static func elevator_levels() -> Array:
	var deepest := int(PlayerState.flags.get("mine_deepest", 1))
	var levels: Array = [1]
	for l in range(ELEVATOR_STEP, deepest + 1, ELEVATOR_STEP):
		levels.append(l)
	return levels


func _cave() -> Array:
	var wall: Array = []
	for y in HEIGHT:
		var row: Array[bool] = []
		for x in WIDTH:
			var border := x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1
			row.append(border or _rng.randf() < 0.44)
		wall.append(row)
	for step in 4:
		var next: Array = []
		for y in HEIGHT:
			var row: Array[bool] = []
			for x in WIDTH:
				if x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1:
					row.append(true)
					continue
				var n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if wall[y + dy][x + dx]:
							n += 1
				row.append(n >= 5)
			next.append(row)
		wall = next
	return wall


func _largest_region(wall: Array) -> Array[Vector2i]:
	var seen := {}
	var best: Array[Vector2i] = []
	for y in HEIGHT:
		for x in WIDTH:
			var start := Vector2i(x, y)
			if wall[y][x] or seen.has(start):
				continue
			var region: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				region.append(c)
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n := c + d
					if n.x >= 0 and n.y >= 0 and n.x < WIDTH and n.y < HEIGHT and not wall[n.y][n.x] and not seen.has(n):
						seen[n] = true
						stack.append(n)
			if region.size() > best.size():
				best = region
	return best


## Type de rocher selon la profondeur.
func _rock_type() -> String:
	var r := _rng.randf()
	# Minerais assez rares : la plupart des rochers ne sont que de la pierre
	if r < 0.025 + level * 0.0015:
		return "gem"
	r = _rng.randf()
	if level >= 10 and level < 20 and r < 0.05:
		return "frost"
	if level >= 20 and r < 0.05:
		return "magma"
	r = _rng.randf()
	if level >= 20 and r < 0.11:
		return "gold"
	if level >= 10 and r < 0.19:
		return "iron"
	if level < 20 and r < 0.27:
		return "copper"
	if r < 0.38:
		return "coal"
	return "pebbles" if _rng.randf() < 0.3 else "stone"


func _gem_for_depth() -> String:
	var r := randf()
	if level >= 20 and r < 0.25:
		return "emerald"
	if level >= 8 and r < 0.55:
		return "amethyst"
	return "quartz"


# ------------------------------------------------------------ construction
func _ground_tile(cell: Vector2i, ch: String) -> int:
	match ch:
		"#":
			var below: String = _ground_chars.get(cell + Vector2i.DOWN, "#")
			if below != "#":
				return WorldTiles.MINE_WALL_GRATE if _hash(cell) % 11 == 0 else WorldTiles.MINE_WALL
			var r := _hash(cell) % 9
			return WorldTiles.MINE_VOID + (1 if r == 0 else (2 if r == 1 else 0))
		"U":
			return WorldTiles.LADDER_UP
	if _ground_chars.get(cell + Vector2i.UP, "#") == "#":
		return WorldTiles.MINE_FLOOR_SHADE
	var r := _hash(cell) % 13
	return WorldTiles.MINE_RUBBLE if r == 0 else (WorldTiles.MINE_FLOOR_2 if r < 4 else WorldTiles.MINE_FLOOR)


func _place_special(cell: Vector2i, ch: String) -> void:
	if ch == "U":
		_interactables[cell] = "ladder_up"


func up_cell() -> Vector2i:
	return _up_cell


func treasure_opened() -> bool:
	return PlayerState.flags.has("treasure_%d" % level)


func _after_build() -> void:
	_rocks = TileMapLayer.new()
	_rocks.tile_set = _ground.tile_set
	_rocks.z_index = -1
	add_child(_rocks)
	for c: Vector2i in _rock_data:
		_rocks.set_cell(c, 0, WorldTiles.coords(ROCKS[_rock_data[c].type][0]))
	_initial_rocks = _rock_data.size()
	if level < MAX_LEVEL and _ladder_cell == Vector2i(-1, -1):
		_reveal_ladder(_monster_cells[0] if not _monster_cells.is_empty() else _spawn_cell + Vector2i.RIGHT)
	if _from_below or _mem().ladder != Vector2i(-1, -1):
		_reveal_ladder(_ladder_cell, true, false)
	for c: Vector2i in rope_cells:
		_add_rope(c)
	if elevator_cell != Vector2i(-1, -1):
		_blocked[elevator_cell] = true
		_interactables[elevator_cell] = "elevator"
	if treasure_cell != Vector2i(-1, -1):
		_blocked[treasure_cell] = true
		_interactables[treasure_cell] = "treasure"
	for c in _monster_cells:
		_spawn_monster(c)
	# Éclairage : plus on descend, plus il fait sombre (la lanterne éclaire).
	_light = PointLight2D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.92, 0.75, 1))
	gradient.set_color(1, Color(1, 0.92, 0.75, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_light.texture = tex
	_light.texture_scale = 0.9
	_light.energy = 0.9
	_light.position = Vector2(0, -8)
	player.add_child(_light)
	if level == MAX_LEVEL:
		EventBus.toast("Le fond de la mine... L'escalier s'arrête ici.")
	else:
		EventBus.toast(display_name())
	# Le fond de la mine : le Gardien de la source, tant qu'il n'est pas vaincu
	if level == MAX_LEVEL and not PlayerState.flags.has("mine_boss"):
		_spawn_boss()
	var deepest := int(PlayerState.flags.get("mine_deepest", 1))
	PlayerState.flags["mine_deepest"] = maxi(deepest, level)
	if level % ELEVATOR_STEP == 0 and not PlayerState.flags.has("elevator_%d" % level):
		PlayerState.flags["elevator_%d" % level] = true
		EventBus.message_requested.emit("Ascenseur débloqué !", "Un vieil ascenseur de mineur, toujours en état. Tu peux maintenant revenir directement au niveau %d depuis l'entrée de la mine." % level)


func _place_player() -> void:
	player.step_sound = "step_stone"
	# Dans la mine, on arrive toujours au pied de l'échelle.
	player.position = cell_center(_spawn_cell)
	player.facing = Vector2i.DOWN
	_camera.reset_smoothing()


func _spawn_boss() -> void:
	var boss := Monster.new()
	boss.kind = "guardian"
	boss.level = level
	boss.target = player
	var cell := _spawn_cell + Vector2i(0, 4)
	for r in range(4, 12):
		var c := _spawn_cell + Vector2i(0, r)
		if is_walkable(c):
			cell = c
	boss.position = cell_center(cell)
	boss.died.connect(_on_boss_died)
	boss.add_to_group("monsters")
	_entities.add_child(boss)
	EventBus.message_requested.emit("Le Gardien de la source", "Au fond de la mine, une silhouette de pierre se dresse entre toi et la source... Le Gardien ! Frappe, recule, et ne te laisse pas encercler.")


func _on_boss_died(_monster: Monster) -> void:
	PlayerState.flags["mine_boss"] = true
	Sfx.play("achievement")
	Settings.vibrate(150)
	EventBus.camera_shake.emit(5.0, 0.5)
	Inventory.add_gold(5000)
	if Inventory.add_item("mountain_heart", 1) > 0:
		_drop("mountain_heart", _monster.position)
	Skills.add_xp("combat", 300)
	Story.bump("monsters")
	EventBus.message_requested.emit("Victoire !", "Le Gardien s'effondre en une pluie de pierres. Dans les éboulis brille le Cœur de la montagne. +5000 or.")


func _spawn_monster(cell: Vector2i) -> void:
	var monster := Monster.new()
	monster.kind = _monster_kind()
	monster.level = level
	monster.target = player
	monster.position = cell_center(cell)
	monster.set_meta("spawn", cell)
	monster.died.connect(_on_monster_died)
	monster.add_to_group("monsters")
	_entities.add_child(monster)


func _monster_kind() -> String:
	var pool: Array = []
	var total := 0
	for id: String in GameData.monsters:
		var m: Dictionary = GameData.monsters[id]
		var levels: Array = m.get("levels", [1, 30])
		if level >= int(levels[0]) and level <= int(levels[1]):
			pool.append(id)
			total += int(m.get("weight", 1))
	if pool.is_empty():
		return "slime"
	var roll := _rng.randi() % total
	for id: String in pool:
		roll -= int(GameData.monsters[id].get("weight", 1))
		if roll < 0:
			return id
	return pool[0]


# ------------------------------------------------------------ actions
func _interact(kind: String, _cell: Vector2i) -> void:
	match kind:
		"ladder_up":
			_go_up()
		"ladder_down":
			_go_down()
		"elevator":
			Sfx.play("door")
			EventBus.elevator_requested.emit(elevator_levels())
		"treasure":
			_open_treasure()
		"rope":
			_climb_rope()


## Marcher sur un escalier = changer d'étage.
func _warp_for(cell: Vector2i) -> Dictionary:
	if cell == _up_cell:
		_go_up()
	elif _ladder_found and cell == _ladder_cell:
		_go_down()
	return {}


var _leaving: bool = false


func _go_up() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play("step_stone")
	if level == 1:
		EventBus.map_change_requested.emit("village", VILLAGE_EXIT)
	else:
		arrive_from_below = true
		EventBus.map_change_requested.emit("mine:%d" % (level - 1), Vector2i.ZERO)


## Corde d'urgence : on est hissé jusqu'à l'entrée de la mine.
func _climb_rope() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play("door")
	EventBus.toast("Tu tires sur la corde d'urgence : on te hisse jusqu'à la surface !")
	EventBus.map_change_requested.emit("village", VILLAGE_EXIT)


func _add_rope(cell: Vector2i) -> void:
	if not cell in rope_cells:
		rope_cells.append(cell)
	_blocked[cell] = true
	_interactables[cell] = "rope"


func _go_down() -> void:
	if _leaving or level >= MAX_LEVEL:
		return
	_leaving = true
	Sfx.play("step_stone")
	EventBus.map_change_requested.emit("mine:%d" % (level + 1), Vector2i.ZERO)


func _open_treasure() -> void:
	var weapon: String = TREASURES.get(level, "")
	if weapon == "" or treasure_opened():
		EventBus.toast("Le coffre est vide.")
		return
	if not Inventory.can_add(weapon):
		EventBus.toast("Libère une place dans ton sac d'abord.")
		return
	PlayerState.flags["treasure_%d" % level] = true
	Inventory.add_item(weapon, 1)
	Sfx.play("levelup")
	Fx.burst(_entities, cell_center(treasure_cell) + Vector2(0, -8), [Color(1, 0.9, 0.4), Color(1, 1, 0.8)], 20, 60.0)
	var item := GameData.item(weapon)
	EventBus.message_requested.emit("Un coffre ancien !", "Dedans : %s ! %s (dégâts %d-%d)" % [item.name, item.get("description", ""), int(item.damage[0]), int(item.damage[1])])


func _use_pickaxe(cell: Vector2i, energy: int) -> void:
	if not _rock_data.has(cell):
		return
	if not spend_energy(energy):
		return
	_rock_data[cell].hp -= int(GameData.item(Inventory.get_selected().id).get("power", 1))
	var broken: bool = _rock_data[cell].hp <= 0
	var tex := GameData.item_icon(Inventory.get_selected().id)
	player.face_towards(cell - player_cell())
	var at := cell_center(cell) + Vector2(0, -4)
	# L'état change tout de suite ; le rocher éclate à l'impact de la pioche.
	var drops: Array = _break_rock(cell) if broken else []
	player.play_tool("strike", tex, func() -> void:
		Sfx.play("clink")
		Fx.burst(_entities, at, Fx.SPARK, 4, 50.0, true, 200.0, 0.25)
		Fx.burst(_entities, at, Fx.STONE, 6 if not broken else 16, 60.0)
		if broken:
			_rocks.erase_cell(cell)
			Sfx.play("rock_break")
			Settings.vibrate(30)
			shake(2.0, 0.15)
			for id: String in drops:
				_drop(id, cell_center(cell))
			if cell == _ladder_cell:
				_ground.set_cell(cell, 0, WorldTiles.coords(WorldTiles.LADDER_DOWN))
				Sfx.play("levelup", -8.0))


## Retire le rocher (état) et renvoie ce qu'il laisse tomber.
func _break_rock(cell: Vector2i) -> Array:
	var type: String = _rock_data[cell].type
	_rock_data.erase(cell)
	_mem().broken[cell] = true
	var out: Array = []
	var drops: Array = ROCKS[type][2]
	if type == "gem":
		drops = [[_gem_for_depth(), 1, 1, 1.0]]
	if type in ["stone", "pebbles"]:
		var fossil := Museum.roll_find(0.012)
		if fossil != "":
			drops = drops + [[fossil, 1, 1, 1.0]]
	Skills.add_xp("mining", 3 if type in ["stone", "pebbles"] else 6)
	if not type in ["stone", "pebbles"]:
		Story.bump("ores")
	for d: Array in drops:
		if randf() < float(d[3]):
			var n := randi_range(int(d[1]), int(d[2]))
			if type != "stone" and type != "pebbles" and Skills.roll("mining", 6.0):
				n += 1
			for i in n:
				out.append(str(d[0]))
	if cell == _ladder_cell:
		_reveal_ladder(cell, false)  # trouvée tout de suite, affichée à l'impact
	elif not _ladder_found and level < MAX_LEVEL:
		# Un escalier peut apparaître sous n'importe quel rocher cassé : de
		# plus en plus probable à mesure qu'on dégage le niveau.
		var cleared := 1.0 - float(_rock_data.size()) / float(maxi(_initial_rocks, 1))
		if randf() < 0.03 + 0.12 * cleared:
			_reveal_ladder(cell, false)
	return out


func _reveal_ladder(cell: Vector2i, show_now: bool = true, announce: bool = true) -> void:
	if _ladder_found:
		return
	_ladder_found = true
	_ladder_cell = cell
	_mem().ladder = cell
	if show_now:
		_ground.set_cell(cell, 0, WorldTiles.coords(WorldTiles.LADDER_DOWN))
	_interactables[cell] = "ladder_down"
	if announce:
		EventBus.toast("Un escalier descend vers le niveau %d !" % (level + 1))
	# Corde d'urgence aussi à côté de l'escalier qui descend (premiers étages),
	# sur une case dégagée qui ne bouche pas le passage
	if level <= ROPE_LEVELS:
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var c := cell + d
			if _ground_chars.get(c, "#") != "_" or _rock_data.has(c) or _blocked.has(c) or c == _spawn_cell or c in _monster_cells:
				continue
			var open := 0
			for d2: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _ground_chars.get(c + d2, "#") != "#":
					open += 1
			if open >= 3:
				_add_rope(c)
				break


func _on_monster_died(monster: Monster) -> void:
	if monster.has_meta("spawn"):
		_mem().killed[monster.get_meta("spawn")] = true
	Sfx.play("monster_die")
	Fx.puff(_entities, monster.position, Color(0.95, 0.95, 1.0, 0.85), 1.6)
	var data: Dictionary = GameData.monsters.get(monster.kind, {})
	Skills.add_xp("combat", 5 + level / 2)
	Story.bump("monsters")
	if randf() < float(data.get("drop_chance", 0.5)):
		_drop(str(data.get("drop", "slime")), monster.position)


func _drop(item_id: String, at: Vector2) -> void:
	var pickup := Pickup.new()
	pickup.item_id = item_id
	pickup.target = player
	pickup.position = at
	_entities.add_child(pickup)


# ------------------------------------------------------------ affichage
func _update_tint(_hour: int, _minute: int) -> void:
	var depth := clampf(float(level) / MAX_LEVEL, 0.0, 1.0)
	_tint.color = Color(0.82, 0.78, 0.74).lerp(Color(0.22, 0.2, 0.28), depth)
