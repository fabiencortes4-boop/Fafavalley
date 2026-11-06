class_name MineLevel
extends WorldMap
## Un niveau de la mine, généré au hasard (grotte par automate cellulaire).
## Le même jour, un niveau a toujours la même forme. Rochers à casser à la
## pioche (minerais selon la profondeur), une échelle cachée sous l'un
## d'eux, monstres plus nombreux et plus forts en descendant.

const WIDTH := 40  # 640 px : plus large que les écrans les plus allongés
const HEIGHT := 24
const MAX_LEVEL := 30
const ELEVATOR_STEP := 5
const VILLAGE_EXIT := Vector2i(36, 5)  # devant l'entrée de la mine, au village

## type -> [tuile, coups de pioche, [[objet, min, max, chance], ...]]
const ROCKS := {
	"stone": [WorldTiles.MINE_ROCK, 1, [["stone", 1, 2, 1.0]]],
	"pebbles": [WorldTiles.MINE_ROCK_SMALL, 1, [["stone", 1, 1, 0.7]]],
	"coal": [WorldTiles.MINE_ROCK_COAL, 2, [["coal", 1, 2, 1.0], ["stone", 1, 1, 0.5]]],
	"copper": [WorldTiles.MINE_ROCK_COPPER, 2, [["copper_ore", 1, 3, 1.0]]],
	"iron": [WorldTiles.MINE_ROCK_IRON, 3, [["iron_ore", 1, 2, 1.0]]],
	"gold": [WorldTiles.MINE_ROCK_GOLD, 4, [["gold_ore", 1, 2, 1.0]]],
	"gem": [WorldTiles.MINE_ROCK_GEM, 3, []],
}
## Trésors des paliers : niveau -> arme
const TREASURES := {10: "iron_sword", 20: "war_axe"}

var level: int = 1

var _rows: Array = []
var _rng := RandomNumberGenerator.new()
var _rocks: TileMapLayer
var _rock_data: Dictionary = {}  # Vector2i -> {"type": String, "hp": int}
var _ladder_cell: Vector2i = Vector2i(-1, -1)
var _ladder_found: bool = false
var _monster_cells: Array[Vector2i] = []
var _light: PointLight2D


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
	# Rochers et monstres
	var rock_cells: Array[Vector2i] = []
	var density := 0.2 + level * 0.004
	for c in region:
		var d: Vector2i = c - _spawn_cell
		if c == up or absi(d.x) + absi(d.y) <= 2:
			continue
		if _rng.randf() < density:
			_rock_data[c] = {"type": _rock_type(), "hp": 0}
			rock_cells.append(c)
	for c: Vector2i in _rock_data:
		_rock_data[c].hp = ROCKS[_rock_data[c].type][1]
	if level < MAX_LEVEL and not rock_cells.is_empty():
		_ladder_cell = rock_cells[_rng.randi() % rock_cells.size()]
	var count := mini(2 + level / 3, 10)
	for i in 300:
		if _monster_cells.size() >= count:
			break
		var c: Vector2i = region[_rng.randi() % region.size()]
		var d: Vector2i = c - _spawn_cell
		if absi(d.x) + absi(d.y) > 7 and not _rock_data.has(c) and not c in _monster_cells:
			_monster_cells.append(c)
	# Plan ASCII : # mur, _ sol, U échelle montante
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			var c := Vector2i(x, y)
			row += "U" if c == up else ("_" if floor_set.has(c) else "#")
		_rows.append(row)


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
	if r < 0.04 + level * 0.002:
		return "gem"
	r = _rng.randf()
	if level >= 20 and r < 0.18:
		return "gold"
	if level >= 10 and r < 0.3:
		return "iron"
	if level < 20 and r < 0.42:
		return "copper"
	if r < 0.55:
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


func _after_build() -> void:
	_rocks = TileMapLayer.new()
	_rocks.tile_set = _ground.tile_set
	_rocks.z_index = -1
	add_child(_rocks)
	for c: Vector2i in _rock_data:
		_rocks.set_cell(c, 0, WorldTiles.coords(ROCKS[_rock_data[c].type][0]))
	if level < MAX_LEVEL and _ladder_cell == Vector2i(-1, -1):
		_reveal_ladder(_monster_cells[0] if not _monster_cells.is_empty() else _spawn_cell + Vector2i.RIGHT)
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
	# Trésor des paliers
	if TREASURES.has(level) and not PlayerState.flags.has("treasure_%d" % level):
		PlayerState.flags["treasure_%d" % level] = true
		_drop(TREASURES[level], cell_center(_spawn_cell) + Vector2(16, 0))
		EventBus.message_requested.emit("Un coffre oublié !", "Quelqu'un a laissé une arme ici, il y a bien longtemps. Elle est à toi maintenant.")
	if level == MAX_LEVEL:
		EventBus.toast("Le fond de la mine... Il n'y a plus d'échelle.")
	else:
		EventBus.toast(display_name())
	var deepest := int(PlayerState.flags.get("mine_deepest", 1))
	PlayerState.flags["mine_deepest"] = maxi(deepest, level)


func _place_player() -> void:
	player.step_sound = "step_stone"
	# Dans la mine, on arrive toujours au pied de l'échelle.
	player.position = cell_center(_spawn_cell)
	player.facing = Vector2i.DOWN
	_camera.reset_smoothing()


func _spawn_monster(cell: Vector2i) -> void:
	var monster := Monster.new()
	monster.kind = _monster_kind()
	monster.level = level
	monster.target = player
	monster.position = cell_center(cell)
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
			EventBus.map_change_requested.emit("village", VILLAGE_EXIT)
		"ladder_down":
			Sfx.play("step_stone")
			EventBus.map_change_requested.emit("mine:%d" % (level + 1), Vector2i.ZERO)


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
	var out: Array = []
	var drops: Array = ROCKS[type][2]
	if type == "gem":
		drops = [[_gem_for_depth(), 1, 1, 1.0]]
	Skills.add_xp("mining", 3 if type in ["stone", "pebbles"] else 6)
	for d: Array in drops:
		if randf() < float(d[3]):
			var n := randi_range(int(d[1]), int(d[2]))
			if type != "stone" and type != "pebbles" and Skills.roll("mining", 6.0):
				n += 1
			for i in n:
				out.append(str(d[0]))
	if cell == _ladder_cell:
		_reveal_ladder(cell, false)  # trouvée tout de suite, affichée à l'impact
	return out


func _reveal_ladder(cell: Vector2i, show_now: bool = true) -> void:
	if _ladder_found:
		return
	_ladder_found = true
	_ladder_cell = cell
	if show_now:
		_ground.set_cell(cell, 0, WorldTiles.coords(WorldTiles.LADDER_DOWN))
	_interactables[cell] = "ladder_down"
	EventBus.toast("Une échelle vers le niveau %d !" % (level + 1))


func _on_monster_died(monster: Monster) -> void:
	Sfx.play("monster_die")
	Fx.puff(_entities, monster.position, Color(0.95, 0.95, 1.0, 0.85), 1.6)
	var data: Dictionary = GameData.monsters.get(monster.kind, {})
	Skills.add_xp("combat", 5 + level / 2)
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
