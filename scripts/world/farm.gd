class_name Farm
extends Node2D
## La ferme : construit la carte à partir d'un plan ASCII, affiche l'état de
## FarmState et traduit les actions du joueur (outil, graines, récolte...).

const TILE := 16
const REACH := 1  # portée d'action en tuiles autour du joueur

## Légende : T arbre, R arbre rond, ~ eau, . herbe, , fleurs, ' touffe,
## = chemin, b buisson, o rocher, f tournesol, m champignons, h foin, k tonneau,
## H maison (3x3), G grange (3x6), B coffre d'expédition, S étal (3x1),
## C poule, V vache (placées sur de l'herbe).
## Les chemins et l'eau doivent faire au moins 2 cases de large (raccords).
const MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTT..T.T..T...TTT......T..TTT...G...TT",
	"TTT........f.........R................TT",
	"TT....H.........o...............C.....TT",
	"TTT........................S..........TT",
	"TT........B.........'......==..V......TT",
	"TTT....==...b..............==....h...kTT",
	"TTT..f.==..................==.......C.TT",
	"TT.....==========================....TTT",
	"TTT....==========================....TTT",
	"TTT...............................'...TT",
	"TTT................k....m.............TT",
	"TTT.....m.....,...............,.....bTTT",
	"TTT.R................................TTT",
	"TT....................'.....~~~~~~...TTT",
	"TTT........................~~~~~~~~..TTT",
	"TTT.......................~~~~~~~~~...TT",
	"TT........'...............~~~~~~~~~~..TT",
	"TT........................~~~~~~~~~~..TT",
	"TT.....................o..~~~~~~~~~~..TT",
	"TTT.............,.........~~~~~~~~~~..TT",
	"TT....,....................~~~~~~~~...TT",
	"TTT.........................~~~~~~...TTT",
	"TT...................................oTT",
	"TTT.........b......................m..TT",
	"TTT...............'......R............TT",
	"TTT..TTTT.T...TT....T......T..T.T.T...TT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]

const DECOR := {
	"R": WorldTiles.ROUND_TREE, "b": WorldTiles.BUSH, "o": WorldTiles.ROCK,
	"f": WorldTiles.SUNFLOWER, "m": WorldTiles.MUSHROOMS, "h": WorldTiles.HAY,
	"k": WorldTiles.BARREL, ",": WorldTiles.GRASS_FLOWERS, "'": WorldTiles.GRASS_TUFT,
}
const TREES := [WorldTiles.PINE, WorldTiles.PINE_2, WorldTiles.BIG_PINE, WorldTiles.PINE]
const TILLABLE := [".", ",", "'", "C", "V"]
const CROP_STAGES := 4
const CROP_ROWS := 6
var _grass_coords := [
	WorldTiles.coords(WorldTiles.GRASS), WorldTiles.coords(WorldTiles.GRASS_TUFT),
	WorldTiles.coords(WorldTiles.GRASS_FLOWERS),
]

var hud: Hud
var player: Player

var _ground: TileMapLayer
var _soil: TileMapLayer
var _entities: Node2D
var _cursor: Line2D
var _tint: CanvasModulate
var _camera: Camera2D
var _ground_chars: Dictionary = {}  # Vector2i -> String
var _blocked: Dictionary = {}  # Vector2i -> true (bâtiments)
var _interactables: Dictionary = {}  # Vector2i -> "door" | "bin" | "shop"
var _crop_sprites: Dictionary = {}  # Vector2i -> Sprite2D
var _spawn_cell: Vector2i = Vector2i(2, 2)
var _map_size: Vector2i
var _target_cell: Vector2i


func _ready() -> void:
	var tileset := _build_tileset()
	_ground = TileMapLayer.new()
	_ground.tile_set = tileset
	_ground.z_index = -2
	add_child(_ground)
	_soil = TileMapLayer.new()
	_soil.tile_set = tileset
	_soil.z_index = -1
	add_child(_soil)
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)
	_build_map()
	_spawn_player()
	_cursor = Line2D.new()
	_cursor.points = PackedVector2Array([Vector2(0, 0), Vector2(TILE, 0), Vector2(TILE, TILE), Vector2(0, TILE)])
	_cursor.closed = true
	_cursor.width = 1.0
	_cursor.default_color = Color(1, 1, 1, 0.7)
	_cursor.z_index = 5
	add_child(_cursor)
	_tint = CanvasModulate.new()
	add_child(_tint)

	EventBus.farm_tile_changed.connect(_refresh_cell)
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.time_changed.connect(_update_tint)
	_refresh_all()


# ------------------------------------------------------------ construction
func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/sprites/world.png")
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var h := TILE / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for i in WorldTiles.COUNT:
		var coords := WorldTiles.coords(i)
		src.create_tile(coords)
		if i in WorldTiles.SOLID:
			var data := src.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	return ts


func _build_map() -> void:
	_map_size = Vector2i(String(MAP[0]).length(), MAP.size())
	for y in MAP.size():
		var row: String = MAP[y]
		if row.length() != _map_size.x:
			push_error("Ligne %d de la carte : largeur incorrecte" % y)
		for x in row.length():
			_ground_chars[Vector2i(x, y)] = row[x]
	for cell: Vector2i in _ground_chars:
		var ch: String = _ground_chars[cell]
		_ground.set_cell(cell, 0, WorldTiles.coords(_ground_tile(cell, ch)))
		match ch:
			"H":
				_add_building(cell, Vector2i(3, 3), "res://assets/sprites/house.png")
				var door := cell + Vector2i(1, 2)
				_interactables[door] = "door"
				_spawn_cell = door + Vector2i.DOWN
			"G":
				_add_building(cell, Vector2i(3, 6), "res://assets/sprites/barn.png")
			"B":
				_add_building(cell, Vector2i(1, 1), "res://assets/sprites/shipping_bin.png")
				_interactables[cell] = "bin"
			"S":
				_add_building(cell, Vector2i(3, 1), "res://assets/sprites/shop_stand.png")
				for dx in 3:
					_interactables[cell + Vector2i(dx, 0)] = "shop"
			"C", "V":
				var critter := Critter.new()
				critter.frame = 0 if ch == "C" else 1
				critter.position = Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE)
				_entities.add_child(critter)


func _ground_tile(cell: Vector2i, ch: String) -> int:
	match ch:
		"=":
			return WorldTiles.autotile(WorldTiles.PATH_START, WorldTiles.PATH_INNER, _same_as.bind(cell, "="))
		"~":
			return WorldTiles.autotile(WorldTiles.WATER_START, WorldTiles.WATER_INNER, _same_as.bind(cell, "~"))
		"T":
			return TREES[_hash(cell) % TREES.size()]
		".":
			# Un peu de variété dans l'herbe.
			var r := _hash(cell) % 23
			return WorldTiles.GRASS_TUFT if r == 0 else (WorldTiles.GRASS_FLOWERS if r == 1 else WorldTiles.GRASS)
	return int(DECOR.get(ch, WorldTiles.GRASS))


func _same_as(dx: int, dy: int, cell: Vector2i, ch: String) -> bool:
	var other := cell + Vector2i(dx, dy)
	# Hors carte = même groupe (pas de bord sur l'extérieur).
	return _ground_chars.get(other, ch) == ch


func _hash(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663)


func _add_building(cell: Vector2i, size_cells: Vector2i, texture_path: String) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.centered = false
	# Origine en bas du bâtiment pour un tri en Y correct avec le joueur.
	sprite.offset = Vector2(0, -size_cells.y * TILE)
	sprite.position = Vector2(cell.x * TILE, (cell.y + size_cells.y) * TILE)
	_entities.add_child(sprite)

	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size_cells * TILE)
	shape.shape = rect
	shape.position = Vector2(cell * TILE) + rect.size / 2.0
	body.add_child(shape)
	add_child(body)
	for dy in size_cells.y:
		for dx in size_cells.x:
			_blocked[cell + Vector2i(dx, dy)] = true


func _spawn_player() -> void:
	player = Player.new()
	_entities.add_child(player)
	_camera = Camera2D.new()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = _map_size.x * TILE
	_camera.limit_bottom = _map_size.y * TILE
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	player.add_child(_camera)
	_place_player()


func _place_player() -> void:
	if PlayerState.has_position:
		player.position = PlayerState.position
	else:
		player.position = Vector2(_spawn_cell * TILE) + Vector2(TILE / 2.0, TILE * 0.75)
		player.facing = Vector2i.DOWN
	_camera.reset_smoothing()


# ------------------------------------------------------------ boucle
func _process(_delta: float) -> void:
	_target_cell = _player_cell() + player.facing
	_cursor.position = Vector2(_target_cell * TILE)


func _player_cell() -> Vector2i:
	return Vector2i((player.position / TILE).floor())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_tool"):
		_act_on(_target_cell)
		get_viewport().set_input_as_handled()
		return
	# Toucher une tuile voisine du joueur = agir dessus.
	if event is InputEventScreenTouch and event.pressed:
		if hud != null and hud.is_over_ui(event):
			return
		var local := make_input_local(event) as InputEventScreenTouch
		var cell := Vector2i((local.position / TILE).floor())
		var offset := cell - _player_cell()
		if maxi(absi(offset.x), absi(offset.y)) <= REACH:
			player.face_towards(offset)
			_act_on(cell)
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------ actions
func _act_on(cell: Vector2i) -> void:
	var kind: String = _interactables.get(cell, "")
	if kind != "":
		_interact(kind)
		return
	if FarmState.is_mature(cell):
		_harvest(cell)
		return
	var slot: Variant = Inventory.get_selected()
	if slot == null:
		return
	var item := GameData.item(slot.id)
	match str(item.get("type", "")):
		"tool":
			_use_tool(str(item.get("tool", "")), int(item.get("energy", 2)), cell)
		"seed":
			_plant(cell, str(item.get("crop", "")))


func _interact(kind: String) -> void:
	match kind:
		"door":
			EventBus.sleep_requested.emit()
		"shop":
			EventBus.shop_requested.emit()
		"bin":
			_ship_selected()


func _use_tool(tool: String, energy: int, cell: Vector2i) -> void:
	match tool:
		"hoe":
			if not _can_till(cell):
				return
			if not _spend(energy):
				return
			player.play_use()
			FarmState.till(cell)
		"watering_can":
			if _ground_chars.get(cell, "") == "~":
				PlayerState.refill_water()
				player.play_use()
				EventBus.toast("Arrosoir rempli !")
				return
			if not FarmState.is_tilled(cell) or FarmState.is_watered(cell):
				return
			if PlayerState.water <= 0:
				EventBus.toast("Arrosoir vide : remplis-le à l'étang.")
				return
			if not _spend(energy):
				return
			PlayerState.use_water()
			player.play_use()
			FarmState.water(cell)


func _spend(energy: int) -> bool:
	if PlayerState.spend_energy(energy):
		return true
	EventBus.toast("Plus assez d'énergie... va dormir !")
	return false


func _can_till(cell: Vector2i) -> bool:
	return (
		str(_ground_chars.get(cell, "")) in TILLABLE
		and _ground.get_cell_atlas_coords(cell) in _grass_coords
		and not _blocked.has(cell)
		and not _interactables.has(cell)
		and not FarmState.is_tilled(cell)
		and cell != _player_cell()
	)


func _plant(cell: Vector2i, crop_id: String) -> void:
	if crop_id == "" or not FarmState.is_tilled(cell) or FarmState.get_crop(cell) != "":
		return
	if not GameData.crop_in_season(crop_id, TimeManager.season):
		EventBus.toast("Ce n'est pas la saison pour planter ça.")
		return
	if FarmState.plant(cell, crop_id):
		Inventory.remove_from_slot(Inventory.selected, 1)


func _harvest(cell: Vector2i) -> void:
	var harvest_id := str(GameData.crop(FarmState.get_crop(cell)).get("harvest", ""))
	if not Inventory.can_add(harvest_id):
		EventBus.toast("Inventaire plein !")
		return
	var got := FarmState.harvest(cell)
	if got != "":
		Inventory.add_item(got, 1)
		player.play_use()
		EventBus.toast("+1 %s" % GameData.item_name(got))


func _ship_selected() -> void:
	var slot: Variant = Inventory.get_selected()
	if slot == null or int(GameData.item(slot.id).get("sell", 0)) <= 0 or GameData.item(slot.id).get("type") == "tool":
		EventBus.toast("Sélectionne un objet à vendre, puis touche le coffre.")
		return
	var qty: int = slot.qty
	FarmState.ship(slot.id, qty)
	EventBus.toast("Expédié : %d x %s (payé cette nuit)" % [qty, GameData.item_name(slot.id)])
	Inventory.remove_from_slot(Inventory.selected, qty)


# ------------------------------------------------------------ affichage
func _refresh_all() -> void:
	_soil.clear()
	for cell: Vector2i in _crop_sprites.keys():
		if FarmState.get_crop(cell) == "":
			_crop_sprites[cell].queue_free()
			_crop_sprites.erase(cell)
	for cell: Vector2i in FarmState.tiles:
		_refresh_soil(cell)
		_refresh_crop(cell)


func _refresh_cell(cell: Vector2i) -> void:
	# Une parcelle change l'apparence de ses voisines (rangées continues).
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		_refresh_soil(cell + offset)
	_refresh_crop(cell)


func _refresh_soil(cell: Vector2i) -> void:
	if not FarmState.is_tilled(cell):
		_soil.erase_cell(cell)
		return
	var left := FarmState.is_tilled(cell + Vector2i.LEFT)
	var right := FarmState.is_tilled(cell + Vector2i.RIGHT)
	var up := FarmState.is_tilled(cell + Vector2i.UP)
	var down := FarmState.is_tilled(cell + Vector2i.DOWN)
	var index := WorldTiles.SOIL_SINGLE
	if left or right:
		index = WorldTiles.SOIL_H_LEFT if not left else (WorldTiles.SOIL_H_RIGHT if not right else WorldTiles.SOIL_H_MID)
	elif up or down:
		index = WorldTiles.SOIL_V_TOP if not up else (WorldTiles.SOIL_V_BOTTOM if not down else WorldTiles.SOIL_V_MID)
	if FarmState.is_watered(cell):
		index += 1
	_soil.set_cell(cell, 0, WorldTiles.coords(index))


func _refresh_crop(cell: Vector2i) -> void:
	var stage := FarmState.crop_stage(cell)
	if stage < 0:
		if _crop_sprites.has(cell):
			_crop_sprites[cell].queue_free()
			_crop_sprites.erase(cell)
		return
	var sprite: Sprite2D = _crop_sprites.get(cell)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.texture = load("res://assets/sprites/crops.png")
		sprite.hframes = CROP_STAGES
		sprite.vframes = CROP_ROWS
		sprite.centered = false
		sprite.offset = Vector2(0, -13)
		sprite.position = Vector2(cell.x * TILE, cell.y * TILE + 12)
		_entities.add_child(sprite)
		_crop_sprites[cell] = sprite
	var row := int(GameData.crop(FarmState.get_crop(cell)).get("sprite_row", 0))
	sprite.frame = row * CROP_STAGES + mini(stage, CROP_STAGES - 1)


func _on_day_started(_day: int, _season: int, _year: int) -> void:
	_refresh_all()
	_place_player()


func _update_tint(_hour: int, _minute: int) -> void:
	var hours := TimeManager.minutes / 60.0
	var night := clampf((hours - 18.0) / 4.0, 0.0, 1.0)
	var color := Color.WHITE.lerp(Color(0.35, 0.40, 0.65), night)
	if TimeManager.is_raining():
		color *= Color(0.75, 0.80, 0.92)
	_tint.color = color
