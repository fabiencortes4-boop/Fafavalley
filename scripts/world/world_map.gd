class_name WorldMap
extends Node2D
## Base commune des cartes (ferme, village) : terrain depuis un plan ASCII,
## raccords automatiques, bâtiments, caméra, curseur, nuit, passages entre
## cartes et interactions de base (panneaux). Les sous-classes ajoutent
## leurs règles en surchargeant les méthodes « virtuelles » plus bas.
##
## Légende commune : T arbre, R arbre rond, ~ eau, . herbe, , fleurs,
## ' touffe, = chemin, b buisson, o rocher, f tournesol, m champignons,
## h foin, k tonneau, F clôture, c pavés, P/Q panneaux.
## Les chemins et l'eau doivent faire au moins 2 cases de large (raccords).

const TILE := 16
const REACH := 1  # portée d'action en tuiles autour du joueur

const DECOR := {
	"R": WorldTiles.ROUND_TREE, "b": WorldTiles.BUSH, "o": WorldTiles.ROCK,
	"f": WorldTiles.SUNFLOWER, "m": WorldTiles.MUSHROOMS, "h": WorldTiles.HAY,
	"k": WorldTiles.BARREL, ",": WorldTiles.GRASS_FLOWERS, "'": WorldTiles.GRASS_TUFT,
	"c": WorldTiles.COBBLES, "P": WorldTiles.SIGN, "Q": WorldTiles.SIGN,
}
const TREES := [WorldTiles.PINE, WorldTiles.PINE_2, WorldTiles.BIG_PINE, WorldTiles.PINE]

static var _tileset: TileSet

var map_id: String = ""
var hud: Hud
var player: Player

var _ground: TileMapLayer
var _entities: Node2D
var _cursor: Line2D
var _tint: CanvasModulate
var _camera: Camera2D
var _ground_chars: Dictionary = {}  # Vector2i -> String
var _blocked: Dictionary = {}  # Vector2i -> true (bâtiments)
var _interactables: Dictionary = {}  # Vector2i -> String (type d'objet)
var _signs: Dictionary = {}  # Vector2i -> [titre, texte]
var _spawn_cell: Vector2i = Vector2i(2, 2)
var _map_size: Vector2i
var _target_cell: Vector2i
var _warping: bool = false
var fishing: Fishing


# ------------------------------------------------------------ à surcharger
## Plan ASCII de la carte.
func _map_rows() -> Array:
	return []


## Place un objet spécial (bâtiment, animal...) pour un caractère inconnu.
func _place_special(_cell: Vector2i, _ch: String) -> void:
	pass


## Interaction avec un objet enregistré dans _interactables.
func _interact(_kind: String, _cell: Vector2i) -> void:
	pass


## Action sur une case sans objet (outils, semis...). Renvoie true si traité.
func _act_on_ground(_cell: Vector2i) -> bool:
	return false


## Passage vers une autre carte : {"map": id, "cell": Vector2i} ou {}.
func _warp_for(_cell: Vector2i) -> Dictionary:
	return {}


func _after_build() -> void:
	pass


## Coup de pioche sur une case (la mine casse ses rochers).
func _use_pickaxe(_cell: Vector2i, _energy: int) -> void:
	pass


## Nom du lieu affiché dans le HUD.
func display_name() -> String:
	return ""


# ------------------------------------------------------------ construction
func _ready() -> void:
	_ground = TileMapLayer.new()
	_ground.tile_set = _get_tileset()
	_ground.z_index = -2
	add_child(_ground)
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
	fishing = Fishing.new()
	fishing.map = self
	add_child(fishing)
	TimeManager.time_changed.connect(_update_tint)
	TimeManager.day_started.connect(_on_day_started)
	_after_build()
	_update_tint(0, 0)


static func _get_tileset() -> TileSet:
	if _tileset != null:
		return _tileset
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
	_tileset = ts
	return ts


func _build_map() -> void:
	var rows := _map_rows()
	_map_size = Vector2i(String(rows[0]).length(), rows.size())
	for y in rows.size():
		var row: String = rows[y]
		if row.length() != _map_size.x:
			push_error("%s, ligne %d : largeur incorrecte" % [map_id, y])
		for x in row.length():
			_ground_chars[Vector2i(x, y)] = row[x]
	for cell: Vector2i in _ground_chars:
		var ch: String = _ground_chars[cell]
		_ground.set_cell(cell, 0, WorldTiles.coords(_ground_tile(cell, ch)))
		if not ch in [".", "=", "~", "T", "F", ",", "'"]:
			_place_special(cell, ch)


func _ground_tile(cell: Vector2i, ch: String) -> int:
	match ch:
		"=":
			return WorldTiles.autotile(WorldTiles.PATH_START, WorldTiles.PATH_INNER, _same_as.bind(cell, "="))
		"~":
			return WorldTiles.autotile(WorldTiles.WATER_START, WorldTiles.WATER_INNER, _same_as.bind(cell, "~"))
		"T":
			return TREES[_hash(cell) % TREES.size()]
		"F":
			var left: bool = _ground_chars.get(cell + Vector2i.LEFT, "") == "F"
			var right: bool = _ground_chars.get(cell + Vector2i.RIGHT, "") == "F"
			if left == right:
				return WorldTiles.FENCE_MID
			return WorldTiles.FENCE_LEFT if right else WorldTiles.FENCE_RIGHT
		".":
			# Un peu de variété dans l'herbe.
			var r := _hash(cell) % 23
			return WorldTiles.GRASS_TUFT if r == 0 else (WorldTiles.GRASS_FLOWERS if r == 1 else WorldTiles.GRASS)
	return int(DECOR.get(ch, WorldTiles.GRASS))


func _same_as(dx: int, dy: int, cell: Vector2i, ch: String) -> bool:
	# Hors carte = même groupe (pas de bord sur l'extérieur).
	return _ground_chars.get(cell + Vector2i(dx, dy), ch) == ch


func _hash(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663)


## Ajoute un bâtiment (sprite + collision). Renvoie la case de la porte
## (door_column sur la rangée du bas) ou (-1, -1) sans porte.
func _add_building(cell: Vector2i, size_cells: Vector2i, texture_path: String, door_column: int = -1) -> Vector2i:
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
	if door_column < 0:
		return Vector2i(-1, -1)
	return cell + Vector2i(door_column, size_cells.y - 1)


func _add_sign(cell: Vector2i, title: String, text: String) -> void:
	_interactables[cell] = "sign"
	_signs[cell] = [title, text]


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
	if PlayerState.has_position and PlayerState.map == map_id:
		player.position = PlayerState.position
	else:
		player.position = cell_center(_spawn_cell)
		player.facing = Vector2i.DOWN
	_camera.reset_smoothing()


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE * 0.75)


func is_water(cell: Vector2i) -> bool:
	return _ground_chars.get(cell, "") == "~"


func is_walkable(cell: Vector2i) -> bool:
	if not _ground_chars.has(cell) or _blocked.has(cell):
		return false
	var tile := _ground.get_cell_atlas_coords(cell)
	return not (tile.x + tile.y * WorldTiles.COLUMNS) in WorldTiles.SOLID


# ------------------------------------------------------------ boucle
func _process(_delta: float) -> void:
	_target_cell = player_cell() + player.facing
	_cursor.position = Vector2(_target_cell * TILE)
	_cursor.visible = not fishing.busy()


func _physics_process(_delta: float) -> void:
	if _warping:
		return
	var warp := _warp_for(player_cell())
	if not warp.is_empty():
		_warping = true
		EventBus.map_change_requested.emit(warp.map, warp.cell)


func player_cell() -> Vector2i:
	return Vector2i((player.position / TILE).floor())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_tool"):
		act_on(_target_cell)
		get_viewport().set_input_as_handled()
		return
	# Toucher une tuile voisine du joueur = agir dessus.
	if event is InputEventScreenTouch and event.pressed:
		if hud != null and hud.is_over_ui(event):
			return
		# Pendant la pêche, toucher l'écran n'importe où = ferrer.
		if fishing.busy():
			fishing.on_action()
			get_viewport().set_input_as_handled()
			return
		var local := make_input_local(event) as InputEventScreenTouch
		var cell := Vector2i((local.position / TILE).floor())
		var offset := cell - player_cell()
		if maxi(absi(offset.x), absi(offset.y)) <= REACH:
			player.face_towards(offset)
			act_on(cell)
			get_viewport().set_input_as_handled()


func act_on(cell: Vector2i) -> void:
	if fishing.busy():
		fishing.on_action()
		return
	var kind: String = _interactables.get(cell, "")
	if kind == "sign":
		var s: Array = _signs[cell]
		EventBus.message_requested.emit(s[0], s[1])
	elif kind != "":
		_interact(kind, cell)
	elif _holding_tool() == "fishing_rod":
		var energy := int(GameData.item("fishing_rod").get("energy", 4))
		if not fishing.try_cast(energy):
			EventBus.toast("Mets-toi face à l'eau pour pêcher.")
	elif _holding_tool() == "pickaxe":
		_use_pickaxe(cell, int(GameData.item("pickaxe").get("energy", 2)))
	elif _holding_type() == "weapon":
		_swing(Inventory.get_selected().id)
	elif not _act_on_ground(cell):
		# Rien à faire ici avec un aliment en main : on propose de le manger.
		var slot: Variant = Inventory.get_selected()
		if slot != null and GameData.item(slot.id).has("edible"):
			EventBus.eat_requested.emit(slot.id)


func _holding_type() -> String:
	var slot: Variant = Inventory.get_selected()
	return "" if slot == null else str(GameData.item(slot.id).get("type", ""))


## Coup d'arme : touche les monstres devant le joueur.
func _swing(weapon_id: String) -> void:
	var data := GameData.item(weapon_id)
	if not player.swing(GameData.item_icon(weapon_id), float(data.get("cooldown", 0.4))):
		return
	var damage: Array = data.get("damage", [5, 8])
	var center := player.hit_point()
	for node in get_tree().get_nodes_in_group("monsters"):
		var monster := node as Monster
		if monster != null and (monster.position + Vector2(0, -4)).distance_to(center) < 16.0:
			monster.hit(randi_range(int(damage[0]), int(damage[1])), player.position, float(data.get("knockback", 120)))


func _holding_tool() -> String:
	var slot: Variant = Inventory.get_selected()
	if slot == null:
		return ""
	return str(GameData.item(slot.id).get("tool", ""))


func spend_energy(energy: int) -> bool:
	if PlayerState.spend_energy(energy):
		return true
	EventBus.toast("Plus assez d'énergie... va dormir !")
	return false


# ------------------------------------------------------------ affichage
func _on_day_started(_day: int, _season: int, _year: int) -> void:
	_place_player()


func _update_tint(_hour: int, _minute: int) -> void:
	var hours := TimeManager.minutes / 60.0
	var night := clampf((hours - 18.0) / 4.0, 0.0, 1.0)
	var color := Color.WHITE.lerp(Color(0.35, 0.40, 0.65), night)
	if TimeManager.is_raining():
		color *= Color(0.75, 0.80, 0.92)
	_tint.color = color
