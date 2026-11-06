class_name Village
extends WorldMap
## Valfleur, le village : maisons, épicerie, place, habitants.
##
## Caractères propres au village : E épicerie (4x3), Y maison de Gaston,
## H maison d'Odette (3x3), A maison de Lina, Z mairie (3x4), W puits,
## P tableau d'affichage, Q panneau vers la ferme.

const MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TT.T......TT...T..T.T.TT..TTTT.TT.TTTTTT",
	"TT.................................M..TT",
	"TT......................f.A.....Z.....TT",
	"TT..E......Y....R...................==TT",
	"TT.....................b............==TT",
	"TT.h.....k....f.....................==TT",
	"TTTQ..==....==..P..........==....==.==TT",
	"======================================TT",
	"======================================TT",
	"TT............============............TT",
	"TTT..,.....b..============.........o..TT",
	"TTT.....R.....===,cW.c,===.b.....'....TT",
	"TTT...........===c....c===...,.......TTT",
	"TT............===.c.c,.===.....R.....TTT",
	"TT...H...FFFF.============............TT",
	"TTT.......fff.============...........mTT",
	"TT.................==................TTT",
	"TT.===============================...TTT",
	"TT.===============================..b.TT",
	"TT'...................................TT",
	"TTT.......,.............o...~~~~~~...TTT",
	"TTT...b...............'....~~~~~~~~...TT",
	"TT..........R..,..........~~~~~~~~~...TT",
	"TTT...............m.......~~~~~~~~~...TT",
	"TTT........................~~~~~~~~...TT",
	"TTT....T..TT.T.T.T.TT.TTT....T..T..TTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]

## Bâtiments : caractère -> [identifiant, taille, image, colonne de la porte]
const BUILDINGS := {
	"E": ["store", Vector2i(4, 3), "res://assets/sprites/store.png", 2],
	"Y": ["gaston", Vector2i(3, 3), "res://assets/sprites/house_gray.png", 1],
	"H": ["odette", Vector2i(3, 3), "res://assets/sprites/house.png", 1],
	"A": ["lina", Vector2i(3, 4), "res://assets/sprites/house_gable.png", 1],
	"Z": ["mairie", Vector2i(3, 4), "res://assets/sprites/house_gable_gray.png", 1],
	"W": ["well", Vector2i(1, 2), "res://assets/sprites/well.png", -1],
	"M": ["mine", Vector2i(3, 2), "res://assets/sprites/mine_entrance.png", 1],
}
const STORE_OPEN := 9 * 60
const STORE_CLOSE := 17 * 60

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


func _after_build() -> void:
	_spawn_cell = Vector2i(2, 9)
	_build_navigation()
	for id: String in GameData.npcs:
		var npc := Npc.new()
		npc.id = id
		npc.village = self
		var home := str(GameData.npc(id).get("home", ""))
		npc.home_cell = _doors.get(home, Vector2i(2, 9)) + Vector2i.DOWN
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


func _warp_for(cell: Vector2i) -> Dictionary:
	if cell.x <= 0:
		return {"map": "farm", "cell": Vector2i(37, clampi(cell.y, 9, 10))}
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
	var building := kind.trim_prefix("door:")
	if building == "store":
		if TimeManager.minutes >= STORE_OPEN and TimeManager.minutes < STORE_CLOSE:
			EventBus.shop_requested.emit()
		else:
			EventBus.message_requested.emit("Épicerie de Rosalie", "C'est fermé. Horaires : de 9h à 17h.")
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
