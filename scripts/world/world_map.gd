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
	"N": WorldTiles.ANVIL,
}
const TREES := [WorldTiles.PINE, WorldTiles.PINE_2, WorldTiles.BIG_PINE, WorldTiles.PINE]

static var _tileset: TileSet
const SEASON_TEXTURES := [
	"res://assets/sprites/world.png", "res://assets/sprites/world.png",
	"res://assets/sprites/world_autumn.png", "res://assets/sprites/world_winter.png",
]
const FORAGE_GROUND := [".", ",", "'"]

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
var _weather: CPUParticles2D
var _forage_sprites: Dictionary = {}  # Vector2i -> Sprite2D


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


## Un coup d'arme sur une case (la ferme fauche les herbes folles).
func _swing_hit_cell(_cell: Vector2i) -> void:
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
	Settings.changed.connect(_apply_zoom)
	EventBus.camera_shake.connect(shake)
	_after_build()
	_update_tint(0, 0)
	_update_weather()
	_spawn_forage()
	_refresh_pots()


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


## Planche de tuiles de la saison (la mine garde ses couleurs).
func _apply_season() -> void:
	var path: String = SEASON_TEXTURES[0] if map_id.begins_with("mine") else SEASON_TEXTURES[TimeManager.season]
	var src := _ground.tile_set.get_source(0) as TileSetAtlasSource
	if src.texture.resource_path != path:
		src.texture = load(path)


func _build_map() -> void:
	_apply_season()
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
	sprite.set_meta("no3d", true)  # reconstruit en 3D par View3D
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


## Rend une case infranchissable (collision comprise).
## Corps de collision posés par block_cell (pour pouvoir les retirer)
var _static_blocks: Dictionary = {}


func block_cell(cell: Vector2i) -> void:
	_blocked[cell] = true
	var body := StaticBody2D.new()
	_static_blocks[cell] = body
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE) * 0.9
	shape.shape = rect
	shape.position = cell_center(cell)
	body.add_child(shape)
	add_child(body)


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
	_apply_zoom()
	_place_player()


func _place_player() -> void:
	if PlayerState.has_position and PlayerState.map == map_id:
		player.position = PlayerState.position
	else:
		player.position = cell_center(_spawn_cell)
		player.facing = Vector2i.DOWN
	_camera.reset_smoothing()


## Petit tremblement de caméra (gros coups, chute d'arbre, blessure).
func shake(strength: float = 2.0, duration: float = 0.15) -> void:
	if View3D.current != null:
		View3D.current.shake(strength, duration)
	if _camera == null:
		return
	var tw := create_tween()
	var steps := maxi(2, int(duration / 0.03))
	for i in steps:
		var k := 1.0 - float(i) / steps
		tw.tween_property(_camera, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k, 0.03)
	tw.tween_property(_camera, "offset", Vector2.ZERO, 0.03)


func _apply_zoom() -> void:
	if _camera != null:
		_camera.zoom = Vector2.ONE * Settings.zoom


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE * 0.75)


func is_water(cell: Vector2i) -> bool:
	return _ground_chars.get(cell, "") == "~"


func is_walkable(cell: Vector2i) -> bool:
	if not _ground_chars.has(cell) or _blocked.has(cell):
		return false
	var tile := _ground.get_cell_atlas_coords(cell)
	return not (tile.x + tile.y * WorldTiles.COLUMNS) in WorldTiles.SOLID


# ------------------------------------------------------------ bancs et chaises
## Sièges : case -> direction du regard de la personne assise.
var seats: Dictionary = {}
var _stand_cell: Vector2i = Vector2i.ZERO
var _rest_timer: float = 0.0
## Le repos assis rend 1 point d'énergie toutes les REST_PERIOD secondes,
## jusqu'à REST_CAP de l'énergie maximale (ça ne remplace pas une nuit).
const REST_PERIOD := 3.0
const REST_CAP := 0.8


func add_seat(cell: Vector2i, look: Vector2i) -> void:
	seats[cell] = look
	_interactables[cell] = "seat"


func sit_down(cell: Vector2i) -> void:
	if player.busy() or player.seated or not seats.has(cell):
		return
	if Npc.taken_seats.has(cell):
		EventBus.toast("%s est déjà assis·e là." % GameData.npc(str(Npc.taken_seats[cell])).get("name", "Quelqu'un"))
		return
	_stand_cell = player_cell()
	_rest_timer = 0.0
	player.sit(cell_center(cell) + Vector2(0, -4), seats[cell])
	Sfx.play("cloth")
	if PlayerState.energy < int(PlayerState.MAX_ENERGY * REST_CAP):
		EventBus.toast("Tu t'assois un moment : l'énergie remonte doucement.")
	else:
		EventBus.toast("Tu t'assois un moment. Quel calme !")


func stand_up() -> void:
	if not player.seated:
		return
	player.stand(cell_center(_stand_cell))
	Sfx.play("cloth", -4.0)


func _rest(delta: float) -> void:
	# Bouger le joystick (ou les flèches) relève le joueur
	if Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.4:
		stand_up()
		return
	_rest_timer += delta
	if _rest_timer >= REST_PERIOD:
		_rest_timer = 0.0
		if PlayerState.energy < int(PlayerState.MAX_ENERGY * REST_CAP):
			PlayerState.heal(1, 0)


# ------------------------------------------------------------ boucle
func _process(_delta: float) -> void:
	if player.seated:
		_rest(_delta)
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


# ------------------------------------------------------------ aide du bouton Action
const KIND_HINTS := {
	"sign": "Lire", "exit": "Sortir", "bed": "Dormir", "kitchen": "Cuisiner", "counter": "Acheter",
	"forge": "Forge", "booth": "Stand", "elevator": "Ascenseur", "treasure": "Ouvrir", "ladder_up": "Monter",
	"ladder_down": "Descendre", "mailbox": "Courrier", "bin": "Expédier", "door": "Entrer",
	"board": "Demandes", "gate": "Voir", "log_gate": "Voir", "seat": "S'asseoir", "boat": "En mer", "child": "Jouer",
}
const TOOL_HINTS := {
	"hoe": "Labourer", "watering_can": "Arroser", "axe": "Couper", "pickaxe": "Piocher", "scythe": "Faucher",
	"fishing_rod": "Pêcher", "brush": "Brosser", "milk_pail": "Traire",
}


## Ce que fera le bouton Action sur la case visée (affiché près du bouton).
func action_hint(cell: Vector2i) -> String:
	if fishing.busy():
		return "Ferrer !" if fishing.state == Fishing.State.BITE else "Pêche..."
	if player.seated:
		return "Se lever"
	if Machines.has_pot(map_id, cell):
		return "Reprendre" if _holding_tool() == "pickaxe" else ("Vider" if Machines.pot_catch(map_id, cell) != "" else "Casier")
	if _holding_type() == "crab_pot" and is_water(cell):
		return "Poser"
	if _forage_sprites.has(cell):
		return "Cueillir"
	if _spouse_at(cell):
		return "Parler"
	var kind: String = _interactables.get(cell, "")
	if kind != "":
		if kind.begins_with("door:"):
			return "Entrer"
		if kind.begins_with("animals:"):
			return "Soigner"
		if kind.begins_with("plot:") or kind.begins_with("construction:"):
			return "Voir"
		return KIND_HINTS.get(kind, "Interagir")
	return _tool_hint(cell)


func _tool_hint(_cell: Vector2i) -> String:
	var slot: Variant = Inventory.get_selected()
	if slot == null:
		return ""
	var item := GameData.item(slot.id)
	var type := str(item.get("type", ""))
	var tool := str(item.get("tool", ""))
	# Houe, arrosoir, graines... ne servent qu'à la ferme
	if not _is_farmland() and (type in ["seed", "placeable", "fertilizer", "sapling"] or tool in ["hoe", "watering_can", "scythe", "axe", "brush", "milk_pail"]):
		return ""
	match type:
		"tool":
			return TOOL_HINTS.get(tool, "Utiliser")
		"weapon":
			return "Attaquer"
		"seed":
			return "Semer"
		"placeable":
			return "Poser"
		"sapling":
			return "Planter"
		"fertilizer":
			return "Engrais"
	return "Manger" if item.has("edible") else ""


# ------------------------------------------------------------ époux / épouse
var _spouse_npc: Npc


## Fait apparaître l'époux ou l'épouse sur cette carte (maison, ferme).
func _spawn_spouse(cell: Vector2i) -> void:
	if Marriage.spouse == "":
		return
	_spouse_npc = Npc.new()
	_spouse_npc.id = Marriage.spouse
	_spouse_npc.position = cell_center(cell)
	_entities.add_child(_spouse_npc)


func _spouse_at(cell: Vector2i) -> bool:
	return _spouse_npc != null and is_instance_valid(_spouse_npc) and _spouse_npc.position.distance_to(cell_center(cell)) < TILE * 0.8


## Parler à un habitant : livrer une demande, scène de cœur, cadeau ou
## discussion (dans cet ordre).
func talk_to_npc(npc: Npc) -> void:
	npc.face(player.position)
	var id := npc.id
	var qi := Quests.deliverable(id)
	if qi >= 0:
		var q := Quests.deliver(qi)
		Sfx.play("coins")
		var praise := " Et quelle qualité !" if int(q.get("quality", 0)) > 0 else ""
		EventBus.dialogue_requested.emit(id, "Oh, %d %s ! C'est exactement ce qu'il me fallait.%s Merci mille fois ! (+%d or)" % [int(q.qty), GameData.item_name(str(q.item)).to_lower(), praise, int(q.gold)])
		return
	var slot0: Variant = Inventory.get_selected()
	if slot0 != null and GameData.item(slot0.id).get("type") == "gift_special":
		var res := Marriage.give(id, str(slot0.id))
		if res.used:
			Inventory.remove_from_slot(Inventory.selected, 1)
			Sfx.play("levelup")
		EventBus.dialogue_requested.emit(id, res.text)
		return
	if id == Marriage.spouse:
		if not Relations.talked_today.has(id):
			Relations.talked_today[id] = true
			Relations.add_points(id, Relations.TALK_POINTS)
		EventBus.dialogue_requested.emit(id, Marriage.spouse_line())
		return
	var port_line := PortStory.try_talk(id)
	if port_line != "":
		EventBus.dialogue_requested.emit(id, port_line)
		return
	var scene := HeartEvents.pending(id)
	if not scene.is_empty():
		EventBus.heart_scene_requested.emit(id, scene)
		return
	var slot: Variant = Inventory.get_selected()
	if slot != null and GameData.item(slot.id).get("type") in ["crop", "fish", "forage", "animal", "food"]:
		var result := Relations.give_gift(id, slot.id)
		if result.accepted:
			Inventory.remove_from_slot(Inventory.selected, 1)
		EventBus.dialogue_requested.emit(id, result.text)
	else:
		EventBus.dialogue_requested.emit(id, Relations.talk(id))


# ------------------------------------------------------------ habitants (cartes avec des passants)
## Chemin pour un habitant (village, port). Sans navigation : aucun chemin.
func find_path(_from: Vector2i, _to: Vector2i, _avoid: Array = []) -> Array[Vector2i]:
	return []


func gather_cell(place: Vector2i, _index: int) -> Vector2i:
	return place


## Case où les habitants partent pour la taverne ((-1, -1) : ils disparaissent).
func tavern_cell() -> Vector2i:
	return Vector2i(-1, -1)


func _is_farmland() -> bool:
	return false


func player_cell() -> Vector2i:
	return Vector2i((player.position / TILE).floor())


func _unhandled_input(event: InputEvent) -> void:
	# Pendant un geste d'outil, on attend qu'il se termine.
	if player.busy() and (event.is_action_pressed("use_tool") or (event is InputEventScreenTouch and event.pressed)):
		if not fishing.busy():
			get_viewport().set_input_as_handled()
			return
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
		var cell: Vector2i
		if View3D.current != null:
			cell = View3D.current.screen_to_cell(event.position)
		else:
			var local := make_input_local(event) as InputEventScreenTouch
			cell = Vector2i((local.position / TILE).floor())
		var offset := cell - player_cell()
		if maxi(absi(offset.x), absi(offset.y)) <= REACH:
			player.face_towards(offset)
			act_on(cell)
			get_viewport().set_input_as_handled()


func act_on(cell: Vector2i) -> void:
	if fishing.busy():
		fishing.on_action()
		return
	if player.seated:
		stand_up()
		return
	if _spouse_at(cell):
		talk_to_npc(_spouse_npc)
		return
	if _forage_sprites.has(cell):
		_pick_forage(cell)
		return
	if Machines.has_pot(map_id, cell):
		_use_pot(cell)
		return
	if _holding_type() == "crab_pot" and is_water(cell):
		_place_pot(cell)
		return
	var kind: String = _interactables.get(cell, "")
	if kind == "sign":
		var s: Array = _signs[cell]
		EventBus.message_requested.emit(s[0], s[1])
	elif kind == "seat":
		sit_down(cell)
	elif kind != "":
		_interact(kind, cell)
	elif _holding_tool() == "fishing_rod":
		var energy := int(GameData.item("fishing_rod").get("energy", 4))
		if not fishing.try_cast(energy):
			EventBus.toast("Mets-toi face à l'eau pour pêcher.")
	elif _holding_tool() == "pickaxe":
		var pick := GameData.item(Inventory.get_selected().id)
		_use_pickaxe(cell, int(pick.get("energy", 2)))
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
	_swing_hit_cell(player_cell() + player.facing)
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
	Sfx.play("error")
	EventBus.toast("Plus assez d'énergie... va dormir !")
	return false


# ------------------------------------------------------------ affichage
func _on_day_started(_day: int, _season: int, _year: int) -> void:
	_apply_season()
	_place_player()
	_update_weather()


# ------------------------------------------------------------ cueillette
## Cases libres pour une plante sauvage (herbe, rien dessus).
func _forage_cells() -> Array:
	var out: Array = []
	for cell: Vector2i in _ground_chars:
		if str(_ground_chars[cell]) in FORAGE_GROUND and is_walkable(cell) and not _interactables.has(cell):
			out.append(cell)
	return out


# ------------------------------------------------------------ casiers
var _pot_sprites: Array[Node] = []


func _place_pot(cell: Vector2i) -> void:
	if not map_id in Machines.POT_MAPS:
		EventBus.toast("Pas de casier ici : pose-le dans un étang ou au port.")
		return
	Machines.place_pot(map_id, cell)
	Inventory.remove_from_slot(Inventory.selected, 1)
	player.face_towards(cell - player_cell())
	player.play_use()
	Sfx.play("splash")
	Fx.burst(_entities, cell_center(cell), [Color(0.8, 0.9, 1.0), Color(1, 1, 1)], 8, 40.0)
	EventBus.toast("Casier posé : reviens demain voir ce qu'il a attrapé.")
	_refresh_pots()


func _use_pot(cell: Vector2i) -> void:
	player.face_towards(cell - player_cell())
	if _holding_tool() == "pickaxe":
		if Machines.pot_catch(map_id, cell) != "" and Machines.collect_pot(map_id, cell) == "":
			EventBus.toast("Inventaire plein !")
			return
		if Inventory.add_item("crab_pot", 1) > 0:
			EventBus.toast("Inventaire plein !")
			return
		Machines.take_pot(map_id, cell)
		player.play_use()
		Sfx.play("splash")
		_refresh_pots()
		return
	var got := Machines.collect_pot(map_id, cell)
	if got == "":
		if Machines.pot_catch(map_id, cell) != "":
			EventBus.toast("Inventaire plein !")
		else:
			EventBus.toast("Le casier est vide pour l'instant. Reviens demain ! (La pioche permet de le reprendre.)")
		return
	player.play_use()
	Sfx.play("splash")
	Settings.vibrate(25)
	Fx.item_pop(_entities, cell_center(cell), GameData.item_icon(got), player)
	EventBus.toast("+1 %s" % GameData.item_name(got))
	_refresh_pots()


## Flotteurs des casiers (et la prise qui attend au-dessus).
func _refresh_pots() -> void:
	for s in _pot_sprites:
		if is_instance_valid(s):
			s.queue_free()
	_pot_sprites.clear()
	for cell: Vector2i in Machines.pots_on(map_id):
		var buoy := Sprite2D.new()
		buoy.texture = GameData.item_icon("crab_pot")
		buoy.position = cell_center(cell)
		buoy.offset = Vector2(0, -6)
		buoy.set_meta("item_id", "crab_pot")
		_entities.add_child(buoy)
		_pot_sprites.append(buoy)
		var got := Machines.pot_catch(map_id, cell)
		if got != "":
			var catch := Sprite2D.new()
			catch.texture = GameData.item_icon(got)
			catch.position = cell_center(cell) + Vector2(0, -1)
			catch.offset = Vector2(0, -16)
			catch.scale = Vector2(0.7, 0.7)
			catch.set_meta("item_id", got)
			catch.set_meta("pot_catch", true)
			_entities.add_child(catch)
			_pot_sprites.append(catch)


func _spawn_forage() -> void:
	var placed := Forage.ensure_spawned(map_id, _forage_cells())
	for key: String in placed:
		var parts := key.split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var sprite := Sprite2D.new()
		sprite.texture = GameData.item_icon(placed[key])
		sprite.set_meta("item_id", placed[key])
		sprite.position = cell_center(cell)
		sprite.offset = Vector2(0, -6)
		_entities.add_child(sprite)
		_forage_sprites[cell] = sprite


func _pick_forage(cell: Vector2i) -> void:
	var sprite: Sprite2D = _forage_sprites[cell]
	var id := Forage.take(map_id, cell)
	if id == "" or not Inventory.can_add(id):
		if id != "":
			Forage.spots.get(map_id, {})["%d,%d" % [cell.x, cell.y]] = id
			EventBus.toast("Inventaire plein !")
		return
	var count := 2 if Skills.roll("foraging", 6.0) else 1
	id = GameData.with_quality(id, GameData.roll_quality(Skills.level("foraging")))
	Inventory.add_item(id, count)
	Skills.add_xp("foraging", 7)
	sprite.queue_free()
	_forage_sprites.erase(cell)
	player.play_use()
	Sfx.play("harvest")
	Settings.vibrate(18)
	Fx.burst(_entities, cell_center(cell) + Vector2(0, -4), Fx.GRASS, 6, 40.0)
	Fx.item_pop(_entities, cell_center(cell) + Vector2(0, -6), GameData.item_icon(id), player)
	EventBus.toast("+%d %s" % [count, GameData.item_name(id)])


# ------------------------------------------------------------ météo
## Pluie ou neige qui tombent autour du joueur (pas dans la mine).
func _update_weather() -> void:
	if _weather != null:
		_weather.queue_free()
		_weather = null
	if map_id.begins_with("mine") or not (TimeManager.is_raining() or TimeManager.is_snowing()):
		return
	var snow := TimeManager.is_snowing()
	_weather = CPUParticles2D.new()
	var img := Image.create(1 if not snow else 2, 4 if not snow else 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.75, 0.85, 1.0, 0.7) if not snow else Color(1, 1, 1, 0.9))
	_weather.texture = ImageTexture.create_from_image(img)
	_weather.amount = 160 if not snow else 90
	_weather.lifetime = 0.9 if not snow else 4.0
	_weather.preprocess = 2.0
	_weather.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_weather.emission_rect_extents = Vector2(360, 10)
	_weather.position = Vector2(0, -200)
	_weather.direction = Vector2(0.25, 1) if not snow else Vector2(0.1, 1)
	_weather.spread = 2.0 if not snow else 25.0
	_weather.gravity = Vector2.ZERO
	_weather.initial_velocity_min = 380.0 if not snow else 30.0
	_weather.initial_velocity_max = 440.0 if not snow else 55.0
	_weather.local_coords = false
	_weather.z_index = 10
	player.add_child(_weather)


func _update_tint(_hour: int, _minute: int) -> void:
	var hours := TimeManager.minutes / 60.0
	var night := clampf((hours - 18.0) / 4.0, 0.0, 1.0)
	var color := Color.WHITE.lerp(Color(0.35, 0.40, 0.65), night)
	if TimeManager.is_raining():
		color *= Color(0.75, 0.80, 0.92)
	_tint.color = color
