class_name PortMap
extends WorldMap
## Le port du Héron, à l'est du village : la taverne de Marius (où tout le
## monde se retrouve le soir, de 20h à 23h30), le comptoir de Basile, la
## maison de Céleste, le phare de Nina sur la pointe, pontons et bateaux.
##
## Plan : B taverne, C comptoir, H maison de Céleste, L phare, # ponton,
## : sable, W bateau amarré, n lanterne, q banc, u tonneaux, v jardinière.

const MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TT..........................::~~~~~~~~~~~~~~~~",
	"TT....b.................b...::~~~~~:o......o~~",
	"TT.R...........,............::~~~~~:...L....~~",
	"TT.......R........,.........::~~~~~:........~~",
	"TT.....,...............=====::#####:........~~",
	"TT........................==::~~~~~:..n.....~~",
	"TT..........B.......C.....==::~~~~~:.......o~~",
	"TT..b............u......u.==::~~~~~~::::::::~~",
	"TT...............u.v.....,==::~~~~~~~~~~~~~~~~",
	"TT.,.......v.........==...==::~~~~~~~~~~~~~~~~",
	"TT........q...==..q..==...==:u~~WW~~~~~~~~~~~~",
	"TTQn.......n..==..n..==..n==::~~~~~~~~~~~~~~~~",
	"============================#########~~~~~~~~~",
	"============================#####u###~~~~~~~~~",
	"TT..q..==.n.....==.qn...q.P.::~~~~~~~~~~~~~~~~",
	"TT.....==.......==....,.....::~~~WW~~~~~~~~~~~",
	"TT..H..==....R..==..........::~~~~~~~~~~~~~~~~",
	"TT.....==..,....==..b.......::~~~~~~~~~~~~~~~~",
	"TT.v...==v......==........,.::~~~~~~~~~~~~~~~~",
	"TT..........n...==......n...::~~~~~~~~~~~~~~~~",
	"TT........b.....==u.........::~~~~~~~~~~~~~~~~",
	"TT:::R::::::::::##::::::::::::~~~~~~~~~~~~~~~~",
	"TT::::::::::::::##::::::::::::~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~##~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~##~W~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~##~W~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
]

## Bâtiments : caractère -> [identifiant, taille, image, colonne de la porte]
const BUILDINGS := {
	"B": ["taverne", Vector2i(5, 4), "res://assets/sprites/store.png", 2],
	"C": ["comptoir", Vector2i(4, 3), "res://assets/sprites/store.png", 1],
	"H": ["celeste", Vector2i(3, 3), "res://assets/sprites/house.png", 1],
	"L": ["phare", Vector2i(2, 2), "res://assets/sprites/house_gray.png", 0],
}
const BUBBLES := ["Belle marée aujourd'hui !", "Tu viens à la taverne ce soir ?", "Les mouettes sont bavardes.", "Ça sent l'iode !", "Bonjour !"]

var npcs: Array[Npc] = []
var _astar := AStarGrid2D.new()
var _bubble_timer: float = 4.0


func _init() -> void:
	map_id = "port"


func _map_rows() -> Array:
	return MAP


func display_name() -> String:
	return "Port du Héron"


## Case devant la porte d'un bâtiment du port.
static func door_front(id: String) -> Vector2i:
	for ch: String in BUILDINGS:
		var b: Array = BUILDINGS[ch]
		if b[0] != id:
			continue
		for y in MAP.size():
			var x := String(MAP[y]).find(ch)
			if x >= 0:
				var size: Vector2i = b[1]
				return Vector2i(x + int(b[3]), y + size.y)
	return Vector2i(2, 14)


func _place_special(cell: Vector2i, ch: String) -> void:
	if BUILDINGS.has(ch):
		var b: Array = BUILDINGS[ch]
		var door := _add_building(cell, b[1], b[2], b[3])
		_interactables[door] = "door:" + str(b[0])
		return
	match ch:
		"n", "q", "u", "v", "W":
			block_cell(cell)
		"Q":
			_add_sign(cell, "Panneau", "<- Valfleur  |  Port du Héron ->")
		"P":
			_add_sign(cell, "Le port du Héron", "Taverne du Héron : de 16h à minuit, musique tous les soirs. Comptoir de Basile : de 9h à 17h. Le phare est éteint depuis dix ans.")


func _after_build() -> void:
	_spawn_cell = Vector2i(2, 14)
	_place_player()
	_build_navigation()
	for id: String in GameData.npcs:
		if GameData.npc(id).get("map", "") != "port" or id == Marriage.spouse:
			continue
		var npc := Npc.new()
		npc.id = id
		npc.village = self
		npc.home_cell = door_front(str(GameData.npc(id).get("home", ""))) 
		_entities.add_child(npc)
		npcs.append(npc)
	TimeManager.time_changed.connect(func(_h: int, _m: int) -> void:
		for npc in npcs:
			npc.on_time_changed())


func _build_navigation() -> void:
	_astar.region = Rect2i(Vector2i.ZERO, _map_size)
	_astar.cell_size = Vector2(TILE, TILE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for cell: Vector2i in _ground_chars:
		if not is_walkable(cell):
			_astar.set_point_solid(cell, true)
		elif _ground_chars[cell] in ["=", "#"]:
			_astar.set_point_weight_scale(cell, 0.5)


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not _astar.is_in_boundsv(from) or not _astar.is_in_boundsv(to) or _astar.is_point_solid(to):
		return []
	return _astar.get_id_path(from, to, true)


## Le soir, les gens du port entrent à la taverne.
func tavern_cell() -> Vector2i:
	return door_front("taverne")


func _warp_for(cell: Vector2i) -> Dictionary:
	if cell.x <= 0:
		return {"map": "village", "cell": Vector2i(57, clampi(cell.y, 14, 15) + 5)}
	return {}


func npc_at(cell: Vector2i) -> Npc:
	var center := cell_center(cell)
	for npc in npcs:
		if not npc.is_inside() and npc.position.distance_to(center) < TILE * 0.8:
			return npc
	return null


func act_on(cell: Vector2i) -> void:
	var npc: Npc = null if fishing.busy() else npc_at(cell)
	if npc != null:
		talk_to_npc(npc)
		return
	super(cell)


func action_hint(cell: Vector2i) -> String:
	var npc := npc_at(cell)
	if not fishing.busy() and npc != null:
		return "Livrer" if Quests.deliverable(npc.id) >= 0 else "Parler"
	return super(cell)


func _interact(kind: String, _cell: Vector2i) -> void:
	var building := kind.trim_prefix("door:")
	if building == "phare" and PortStory.try_place("phare"):
		return
	if not InteriorMap.LAYOUTS.has(building):
		return
	if InteriorMap.is_open(building):
		Sfx.play("door")
		var rows: Array = InteriorMap.LAYOUTS[building].rows
		var door_x := String(rows[rows.size() - 1]).find("D")
		EventBus.map_change_requested.emit("in:" + building, Vector2i(door_x, rows.size() - 2))
	else:
		EventBus.message_requested.emit(InteriorMap.LAYOUTS[building].name, InteriorMap.closed_text(building))


func _process(delta: float) -> void:
	super(delta)
	_bubble_timer -= delta
	if _bubble_timer <= 0.0:
		_bubble_timer = randf_range(5.0, 9.0)
		for npc in npcs:
			if not npc.is_inside() and npc.position.distance_to(player.position) < TILE * 5:
				EventBus.npc_bubble.emit(npc.id, BUBBLES[randi() % BUBBLES.size()])
				break
