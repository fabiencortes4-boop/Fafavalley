class_name Village
extends WorldMap
## Valfleur, le village : maisons, épicerie, place, habitants.
##
## Quartiers : place, artisans, ranch, résidences, parc de l'étang, mine.
## Bâtiments : E épicerie, Z mairie, Y forge de Gaston, K menuiserie,
## U coopérative, L ranch, H maison d'Odette, A maison de Lina,
## J cabane de Jules, M mine, O fontaine. Décor : N enclume, n lanterne,
## s étal du marché. Animaux : C poule, V vache, I cochon, d chien, e chat.

const MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTT.....TTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTT.....T.....T...T.TTTTT....M...T..T.T..T.T.......T....TTTT",
	"TT........................................................TT",
	"TT........R.........R.........==........o...........R....TTT",
	"TT............................==..........................TT",
	"TTT...........U...............==.............L............TT",
	"TT............................==..................FFFFFFFTTT",
	"TT...........k.....k..........==..........................TT",
	"TT..b...........==......R.....==......b.......==.h...C...TTT",
	"TT..............==............==..............==....V..I..TT",
	"TTT.....'.......==.........m..==....,.........==.........TTT",
	"TTT.............==....,.......==..............==...C..V..TTT",
	"TTT.............==............==..............==.h.......TTT",
	"TT...Y......K...==............==..Z.......'...==.........TTT",
	"TTT.............==......E.....==..............==..FFFFFFF.TT",
	"TT.......N......==............==..............==..........TT",
	"TTT...==.....==.==............==..............==.........TTT",
	"TTTQn.==....n==.==..n.....==n.==.P.==.......n.==....n...b.TT",
	"==========================================================TT",
	"==========================================================TT",
	"TT..n.....==n.......n.......n.==....n.......n.......n.....TT",
	"TT........==.........ss.==============.ss................TTT",
	"TT........==............==============....................TT",
	"TTT..H....==..A.........===.....d..===...................TTT",
	"TTT,......==.......b....===.c....c.===.J..................TT",
	"TT........==............===...O....===................R..TTT",
	"TTT...======............===........===.....f..............TT",
	"TT....===========.......===.c....c.===..==.....~~~~~~~~..TTT",
	"TTT.......=======.......===........===..==....~~~~~~~~~~..TT",
	"TTT.e.....==.........'..==============..==...~~~~~~~~~~~.TTT",
	"TT........==....b.......==============..==.,.~~~~~~~~~~~.TTT",
	"TTT..b....==............................==...~~~~~~~~~~~.TTT",
	"TT........============..................=====~~~~~~~~~~~.TTT",
	"TT........============..................=====~~~~~~~~~~~..TT",
	"TT........==...................b.............~~~~~~~~~~~.TTT",
	"TTT...b...==..FFFFFFF.....R.........f........~~~~~~~~~~~..TT",
	"TT........==............................b.....~~~~~~~~~~..TT",
	"TTT.......................................................TT",
	"TTTTT....T.TTTT.....T..T.T.....TT.'TTTT....T...TTT...T.TTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]

## Bâtiments : caractère -> [identifiant, taille, image, colonne de la porte]
const BUILDINGS := {
	"E": ["store", Vector2i(4, 3), "res://assets/sprites/store.png", 2],
	"Z": ["mairie", Vector2i(3, 4), "res://assets/sprites/house_gable_gray.png", 1],
	"Y": ["gaston", Vector2i(3, 3), "res://assets/sprites/house_gray.png", 1],
	"K": ["menuiserie", Vector2i(4, 3), "res://assets/sprites/store.png", 1],
	"U": ["cooperative", Vector2i(4, 3), "res://assets/sprites/store.png", 2],
	"L": ["ranch", Vector2i(3, 3), "res://assets/sprites/house.png", 1],
	"H": ["odette", Vector2i(3, 3), "res://assets/sprites/house.png", 1],
	"A": ["lina", Vector2i(3, 4), "res://assets/sprites/house_gable.png", 1],
	"J": ["jules", Vector2i(3, 3), "res://assets/sprites/house_gray.png", 1],
	"M": ["mine", Vector2i(3, 2), "res://assets/sprites/mine_entrance.png", 1],
	"O": ["fountain", Vector2i(2, 2), "res://assets/sprites/well.png", -1],
}
## Bâtiment -> boutique
const SHOP_DOORS := {"store": "store", "cooperative": "cooperative", "ranch": "ranch", "menuiserie": "carpenter"}
const ZONES := [
	["Chemin de la mine", Rect2i(26, 2, 10, 11)],
	["Quartier des artisans", Rect2i(2, 2, 21, 17)],
	["Ranch de Léon", Rect2i(41, 2, 17, 17)],
	["Les résidences", Rect2i(2, 21, 21, 19)],
	["Parc de l'étang", Rect2i(38, 21, 20, 19)],
	["Place de Valfleur", Rect2i(22, 12, 18, 28)],
]
const CRITTERS := {"C": ["chicken", 0], "V": ["cow", 1], "I": ["pig", 1], "d": ["dog", 2], "e": ["cat", 2]}
## Petites phrases entendues en passant près des habitants
const BUBBLES := ["Belle journée !", "Bonjour !", "Ça pousse, à la ferme ?", "Tiens, salut !", "Quel temps !", "On se voit à la place ?", "Hm.", "Bonne récolte !"]

var npcs: Array[Npc] = []
var _doors: Dictionary = {}  # identifiant du bâtiment -> case de la porte
var _astar := AStarGrid2D.new()


func _init() -> void:
	map_id = "village"


func _map_rows() -> Array:
	return MAP


func display_name() -> String:
	return "Valfleur"


func _place_special(cell: Vector2i, ch: String) -> void:
	if BUILDINGS.has(ch):
		var b: Array = BUILDINGS[ch]
		var door := _add_building(cell, b[1], b[2], b[3])
		if b[3] >= 0:
			_doors[b[0]] = door
			_interactables[door] = "door:" + b[0]
		return
	match ch:
		"P":
			_add_sign(cell, "Tableau d'affichage", "Bienvenue à Valfleur ! Épicerie de Rosalie : 9h - 17h. La mairie cherche des légumes pour relancer le marché. Fête des moissons : bientôt !")
		"Q":
			_add_sign(cell, "Panneau", "<- Vers la ferme")
		"N":
			_interactables[cell] = "forge"
		"n", "s":
			_blocked[cell] = true
			_add_static_block(cell)
		_:
			if CRITTERS.has(ch):
				var critter := Critter.new()
				critter.kind = str(CRITTERS[ch][0])
				critter.frame = int(CRITTERS[ch][1])
				critter.position = cell_center(cell)
				_entities.add_child(critter)


func _after_build() -> void:
	_spawn_cell = Vector2i(2, 19)
	_build_navigation()
	for id: String in GameData.npcs:
		var npc := Npc.new()
		npc.id = id
		npc.village = self
		var home := str(GameData.npc(id).get("home", ""))
		npc.home_cell = _doors.get(home, Vector2i(2, 19)) + Vector2i.DOWN
		_entities.add_child(npc)
		npcs.append(npc)
	TimeManager.time_changed.connect(_on_time_changed)


func _build_navigation() -> void:
	_astar.region = Rect2i(Vector2i.ZERO, _map_size)
	_astar.cell_size = Vector2(TILE, TILE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for cell: Vector2i in _ground_chars:
		if not is_walkable(cell):
			_astar.set_point_solid(cell, true)
		elif _ground_chars[cell] == "=":
			_astar.set_point_weight_scale(cell, 0.5)  # les habitants préfèrent les chemins


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not _astar.is_in_boundsv(from) or not _astar.is_in_boundsv(to):
		return []
	if _astar.is_point_solid(to):
		push_warning("Destination bloquée pour un habitant : %s" % to)
		return []
	return _astar.get_id_path(from, to, true)


## Bloc de collision d'une case (lanterne, étal).
func _add_static_block(cell: Vector2i) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE) * 0.7
	shape.shape = rect
	shape.position = cell_center(cell) - Vector2(0, 4)
	body.add_child(shape)
	add_child(body)


var _zone: String = ""
var _bubble_timer: float = 3.0


## Quartier où se trouve une case ("" hors de toute zone).
func zone_at(cell: Vector2i) -> String:
	for z: Array in ZONES:
		if (z[1] as Rect2i).has_point(cell):
			return str(z[0])
	return ""


func _process(delta: float) -> void:
	super(delta)
	# Arrivée dans un nouveau quartier
	var zone := zone_at(player_cell())
	if zone != _zone:
		_zone = zone
		if zone != "":
			EventBus.zone_entered.emit(zone)
	# Les habitants proches lancent une petite phrase de temps en temps
	_bubble_timer -= delta
	if _bubble_timer <= 0.0:
		_bubble_timer = randf_range(5.0, 9.0)
		for npc in npcs:
			if not npc.is_inside() and npc.position.distance_to(player.position) < TILE * 5:
				EventBus.npc_bubble.emit(npc.id, BUBBLES[randi() % BUBBLES.size()])
				break


func _warp_for(cell: Vector2i) -> Dictionary:
	if cell.x <= 0:
		return {"map": "farm", "cell": Vector2i(37, clampi(cell.y, 19, 20) - 10)}
	return {}


func _on_time_changed(_hour: int, _minute: int) -> void:
	for npc in npcs:
		npc.on_time_changed()


func _on_day_started(day: int, season: int, year: int) -> void:
	super(day, season, year)
	for npc in npcs:
		npc.sync_to_time()


# ------------------------------------------------------------ interactions
func npc_at(cell: Vector2i) -> Npc:
	var center := cell_center(cell)
	for npc in npcs:
		if not npc.is_inside() and npc.position.distance_to(center) < TILE * 0.8:
			return npc
	return null


func act_on(cell: Vector2i) -> void:
	var npc: Npc = null if fishing.busy() else npc_at(cell)
	if npc != null:
		_talk_to(npc)
		return
	super(cell)


func _talk_to(npc: Npc) -> void:
	npc.face(player.position)
	var slot: Variant = Inventory.get_selected()
	if slot != null and GameData.item(slot.id).get("type") in ["crop", "fish"]:
		var result := Relations.give_gift(npc.id, slot.id)
		if result.accepted:
			Inventory.remove_from_slot(Inventory.selected, 1)
		EventBus.dialogue_requested.emit(npc.id, result.text)
	else:
		EventBus.dialogue_requested.emit(npc.id, Relations.talk(npc.id))


func _interact(kind: String, _cell: Vector2i) -> void:
	if kind == "forge":
		EventBus.forge_requested.emit()
		return
	var building := kind.trim_prefix("door:")
	if SHOP_DOORS.has(building):
		var shop: String = SHOP_DOORS[building]
		if Shops.is_open(shop):
			Sfx.play("door")
			EventBus.shop_opened.emit(shop)
		else:
			EventBus.message_requested.emit(str(Shops.info(shop).get("name", "")), "C'est fermé. " + Shops.hours_text(shop))
		return
	if building == "mine":
		_enter_mine()
		return
	if building == "mairie":
		EventBus.message_requested.emit("Mairie de Valfleur", "La porte est fermée. Une affiche : « Le maire reçoit sur rendez-vous... ou sur la place. »")
		return
	for npc in npcs:
		if GameData.npc(npc.id).get("home") == building:
			var who := str(GameData.npc(npc.id).name)
			var text := "On entend du bruit à l'intérieur : %s est à la maison." % who if npc.is_inside() else "Personne ne répond. %s doit être en ville." % who
			EventBus.message_requested.emit("Maison de %s" % who, text)
			return


func _enter_mine() -> void:
	# Première visite : le coffre de Firmin, l'ancien fermier.
	if not PlayerState.flags.has("mine_kit"):
		if not Inventory.can_add("pickaxe") or not Inventory.can_add("rusty_sword", 1):
			EventBus.toast("Libère de la place dans ton inventaire d'abord.")
			return
		PlayerState.flags["mine_kit"] = true
		Inventory.add_item("pickaxe", 1)
		Inventory.add_item("rusty_sword", 1)
		EventBus.message_requested.emit("Un vieux coffre", "Devant la mine, un coffre poussiéreux. Une étiquette : « Pour qui veut descendre. Prends soin de toi. - Firmin ». Dedans : une pioche et une épée rouillée.")
		return
	var deepest := int(PlayerState.flags.get("mine_deepest", 1))
	var levels: Array = [1]
	for l in range(MineLevel.ELEVATOR_STEP, deepest + 1, MineLevel.ELEVATOR_STEP):
		levels.append(l)
	if levels.size() == 1:
		EventBus.map_change_requested.emit("mine:1", Vector2i.ZERO)
	else:
		EventBus.elevator_requested.emit(levels)
