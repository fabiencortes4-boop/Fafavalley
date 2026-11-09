class_name Village
extends WorldMap
## Valfleur, le village : maisons, épicerie, place, habitants.
##
## Quartiers : place, artisans, ranch, résidences, parc de l'étang, mine.
## Bâtiments : E épicerie, Z mairie, Y forge de Gaston, K menuiserie,
## U coopérative, L ranch, H maison d'Odette, A maison de Lina,
## J cabane de Jules, M mine, O fontaine. Décor : N enclume, n lanterne,
## s étal du marché, v jardinière fleurie, q banc, g haie, u tonneaux,
## y meule de foin, w puits, c bac à fleurs de la place, x arbre en bac. Animaux : C poule, V vache, I cochon, d chien, e chat.

const MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTT.....TTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTT.....T.....T...T.TTTTT....M...T..T.T..T.T.......T....TTTT",
	"TT........................................................TT",
	"TT........R.........R.........==........o...........R....TTT",
	"TT............................==..........................TT",
	"TTT...........U...u..........n==.............L............TT",
	"TT............................==..................FFFFFFFTTT",
	"TT...........k.....k..........==.......................y..TT",
	"TT..b...........==......R.....==......b.......==.h...C...TTT",
	"TT.............n==............==n.............==....V..I..TT",
	"TTT.....'.......==.........m..==....,........n==.........TTT",
	"TTT.............==....,.......==..............==...C..V..TTT",
	"TTT.............==............==..............==.h.......TTT",
	"TT...Y.....hK...==n..........n==..Z.......'...==...y.....TTT",
	"TTT.u...........==......E.....==..............==n.FFFFFFF.TT",
	"TT.......N......==n..x........==......x.......==..........TT",
	"TTTx..==.....==.==............==..............==.........TTT",
	"TTTQn.==.v..n==.==v.n..v..==n.==.P.==..v.v..n.==..v.n..vb.TT",
	"============================================================",
	"============================================================",
	"TT..n..v..==n.x.v...n...v.q.n.==..q.n...v.x.n...v...n.x.v.TT",
	"TT.,.....,==.........ss.n============n.ss................TTT",
	"TT.gggggg.==.ggggg.,....==============......,.....,.......TT",
	"TTT..H...n==..A.........==x========x==ggggg.............,TTT",
	"TTT,......==.......b....==============.J..................TT",
	"TT........==.....d....,x====q=O==q====.........q....q.R..TTT",
	"TTT...======............====q====q====.....f..............TT",
	"TT....===========.......==x========x==x.==.....~~~~~~~~..TTT",
	"TTT.......=======.......======qq======..==....~~~~~~~~~~..TT",
	"TTT.e.....==,........'..==============.n==...~~~~~~~~~~~.TTT",
	"TT........==n...b....w..n============n..==.,.~~~~~~~~~~~.TTT",
	"TTT..b....==............................==...~~~~~~~~~~~.TTT",
	"TT.......n============......,...........=====~~~~~~~~~~~.TTT",
	"TT......R.============..................=====~~~~~~~~~~~..TT",
	"TT........==......,......,.....b...........n.~~~~~~~~~~~.TTT",
	"TTT...b...==n.FFFFFFF.....R.........f.R......~~~~~~~~~~~..TT",
	"TT....,...==.......................,....b.....~~~~~~~~~~..TT",
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
		for g: Array in gardens():
			if g[2] == b[0]:
				_blocked[g[0]] = true
				_add_static_block(g[0])
		if b[0] == "mine":
			# La colline rocheuse autour de l'entrée de la mine
			for dx in range(-2, 5):
				for dy in range(0, 2):
					var c: Vector2i = cell + Vector2i(dx, dy)
					if not _blocked.has(c) and (dx < 0 or dx >= 3):
						_blocked[c] = true
						_add_static_block(c)
		if b[3] >= 0:
			_doors[b[0]] = door
			_interactables[door] = "door:" + b[0]
		return
	match ch:
		"P":
			_interactables[cell] = "board"
		"Q":
			_add_sign(cell, "Panneau", "<- Vers la ferme")
		"N":
			_interactables[cell] = "forge"
		"n", "s", "v", "q", "g", "u", "y", "w", "c", "x":
			_blocked[cell] = true
			_add_static_block(cell)
			if ch == "q":
				add_seat(cell, bench_facing(cell))
		_:
			if CRITTERS.has(ch):
				var critter := Critter.new()
				critter.kind = str(CRITTERS[ch][0])
				critter.frame = int(CRITTERS[ch][1])
				critter.position = cell_center(cell)
				_entities.add_child(critter)


## La place de Valfleur (dallée), autour de la fontaine
const PLAZA := Rect2i(24, 22, 14, 10)
const FOUNTAIN_CENTER := Vector2(31.0, 27.0)


## Sens d'un banc : sur la place, il regarde la fontaine ; ailleurs, il
## tourne le dos aux maisons (vers le bas) ou longe le chemin (vers la droite).
static func bench_facing(cell: Vector2i) -> Vector2i:
	if PLAZA.has_point(cell):
		var d := FOUNTAIN_CENTER - (Vector2(cell) + Vector2(0.5, 0.5))
		if absf(d.x) >= absf(d.y):
			return Vector2i.RIGHT if d.x > 0 else Vector2i.LEFT
		return Vector2i.DOWN if d.y > 0 else Vector2i.UP
	return Vector2i.DOWN if cell.y < 25 or cell.y == 29 else Vector2i.RIGHT


func _after_build() -> void:
	_spawn_cell = Vector2i(2, 19)
	# Chantiers de rénovation : moulin et kiosque occupent leurs cases ; le
	# pont, une fois réparé, se traverse (on peut pêcher depuis le tablier).
	for id: String in Projects.SITES:
		var r: Rect2i = Projects.SITES[id]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if id != "bridge":
					_blocked[c] = true
					_add_static_block(c)
					_interactables[c] = "project:" + id
				elif Projects.state("bridge") != "done":
					_interactables[c] = "project:bridge"
	# Jour de fête ou de marché : un stand sur la place
	if Events.booth_activity() != "":
		_blocked[Events.BOOTH] = true
		_add_static_block(Events.BOOTH)
		_interactables[Events.BOOTH] = "booth"
	_build_navigation()
	if Story.chapter >= 1:
		Tips.show("seat")
	if Story.chapter >= 2:
		Tips.show("projects")
	# La meunière vit au moulin (sa porte : au pied de la façade)
	var mill: Rect2i = Projects.SITES.mill
	_doors["mill"] = Vector2i(mill.position.x + mill.size.x / 2, mill.end.y - 1)
	var wedding := not VillageLife.wedding_today().is_empty()
	for id: String in GameData.npcs:
		var guest: bool = wedding and id in VillageLife.COUPLE and GameData.npc(id).get("map", "") == "port"
		if id == Marriage.spouse or (GameData.npc(id).get("map", "") == "port" and not guest):
			continue  # vit à la ferme, ou au port
		var npc := Npc.new()
		npc.id = id
		npc.village = self
		npc.guest = guest
		var home := str(GameData.npc(id).get("home", ""))
		npc.home_cell = (tavern_cell() + Vector2i.LEFT) if guest else _doors.get(home, Vector2i(2, 19)) + Vector2i.DOWN
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


## Décor des jardins, selon le bâtiment : ce qu'on pose sur les côtés
const GARDEN_PROPS := {
	"store": "crates", "mairie": "flagpole", "gaston": "barrels", "menuiserie": "logs",
	"cooperative": "hay", "ranch": "hay", "odette": "veggies", "lina": "easel", "jules": "fish",
}
static var _gardens: Array = []


## Jardins des villageois : devant la façade (massifs de fleurs, potager)
## et sur les côtés (objet propre au métier de l'habitant). Seulement sur
## l'herbe, jamais devant une porte ni là où les habitants se rendent.
## [[case, sorte, bâtiment], ...]
static func gardens() -> Array:
	if not _gardens.is_empty():
		return _gardens
	var spots := {}
	for id: String in GameData.npcs:
		for e: Dictionary in GameData.npc(id).get("schedule", []):
			if e.has("cell"):
				spots[Vector2i(int(e.cell[0]), int(e.cell[1]))] = true
	var fronts := {}
	for ch: String in BUILDINGS:
		var b: Array = BUILDINGS[ch]
		if int(b[3]) >= 0:
			fronts[door_front(str(b[0]))] = true
	for y in MAP.size():
		var row := String(MAP[y])
		for x in row.length():
			var ch := row[x]
			if not BUILDINGS.has(ch) or not GARDEN_PROPS.has(str(BUILDINGS[ch][0])):
				continue
			var b: Array = BUILDINGS[ch]
			var id := str(b[0])
			var size: Vector2i = b[1]
			var door := int(b[3])
			var cand: Array = []
			var front_y := y + size.y
			for dx in size.x:
				if dx != door:
					cand.append([Vector2i(x + dx, front_y), "veggies" if id == "odette" else ("planter" if id in ["store", "mairie", "cooperative"] else "flowers")])
			cand.append([Vector2i(x - 1, y + size.y - 1), GARDEN_PROPS[id]])
			cand.append([Vector2i(x + size.x, y + size.y - 1), "bush" if id != "mairie" else "flowers"])
			for c: Array in cand:
				var cell: Vector2i = c[0]
				if cell.y < 0 or cell.y >= MAP.size() or cell.x < 0 or cell.x >= String(MAP[cell.y]).length():
					continue
				if not String(MAP[cell.y])[cell.x] in [".", ","] or spots.has(cell) or fronts.has(cell):
					continue
				if fronts.has(cell + Vector2i.LEFT) or fronts.has(cell + Vector2i.RIGHT):
					continue  # on laisse le passage devant les portes
				_gardens.append([cell, c[1], id])
	return _gardens
## Le soir, les habitants partent à la taverne par la route du port, à l'est.
func tavern_cell() -> Vector2i:
	return Vector2i(_map_size.x - 1, 19)


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
	return Vector2i(2, 19)


var _gather_cache: Dictionary = {}


## n-ième case libre autour d'un lieu de rassemblement (en spirale).
func gather_cell(place: Vector2i, index: int) -> Vector2i:
	if not _gather_cache.has(place):
		var cells: Array[Vector2i] = []
		var seen := {place: true}
		var queue: Array[Vector2i] = [place]
		while not queue.is_empty() and cells.size() < 24:
			var c: Vector2i = queue.pop_front()
			if is_walkable(c) and c != Events.BOOTH + Vector2i.DOWN:
				cells.append(c)
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := c + d
				if not seen.has(n) and _ground_chars.has(n) and (is_walkable(n) or not is_walkable(c)):
					seen[n] = true
					queue.append(n)
		# Une case sur deux : on ne se colle pas
		var spread: Array[Vector2i] = []
		for i in cells.size():
			if i % 2 == 0:
				spread.append(cells[i])
		_gather_cache[place] = spread if not spread.is_empty() else [place]
	var list: Array = _gather_cache[place]
	return list[maxi(index, 0) % list.size()]


func find_path(from: Vector2i, to: Vector2i, avoid: Array = []) -> Array[Vector2i]:
	if not _astar.is_in_boundsv(from) or not _astar.is_in_boundsv(to):
		return []
	if _astar.is_point_solid(to):
		push_warning("Destination bloquée pour un habitant : %s" % to)
		return []
	return _path_avoiding(from, to, avoid)


## Chemin qui contourne des cases occupées (quelqu'un sur le passage).
func _path_avoiding(from: Vector2i, to: Vector2i, avoid: Array) -> Array[Vector2i]:
	var added: Array[Vector2i] = []
	for c: Vector2i in avoid:
		if c != from and c != to and _astar.is_in_boundsv(c) and not _astar.is_point_solid(c):
			_astar.set_point_solid(c, true)
			added.append(c)
	var path := _astar.get_id_path(from, to, true)
	for c in added:
		_astar.set_point_solid(c, false)
	return path


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
				var event := Events.happening_now()
				var line: String = BUBBLES[randi() % BUBBLES.size()]
				if not event.is_empty() and randf() < 0.6:
					line = str(event.get("bubble", "Vive la fête !"))
				EventBus.npc_bubble.emit(npc.id, line)
				break


func _warp_for(cell: Vector2i) -> Dictionary:
	if cell.x >= _map_size.x - 1:
		return {"map": "port", "cell": Vector2i(1, clampi(cell.y, 19, 20) - 5)}
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
func action_hint(cell: Vector2i) -> String:
	if not fishing.busy() and npc_at(cell) != null:
		var slot: Variant = Inventory.get_selected()
		var gift: bool = slot != null and GameData.item(slot.id).get("type") in ["crop", "fish", "forage", "animal", "food"]
		var npc_id := npc_at(cell).id
		if Quests.deliverable(npc_id) >= 0:
			return "Livrer"
		return "Offrir" if gift else "Parler"
	return super(cell)


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
	talk_to_npc(npc)


## Le pont réparé : ses cases ne sont plus de l'eau.
func _bridge(cell: Vector2i) -> bool:
	return Projects.state("bridge") == "done" and (Projects.SITES.bridge as Rect2i).has_point(cell)


func _ground_tile(cell: Vector2i, ch: String) -> int:
	if _bridge(cell):
		return WorldTiles.PATH_INNER
	return super(cell, ch)


func is_water(cell: Vector2i) -> bool:
	return super(cell) and not _bridge(cell)


func _interact(kind: String, _cell: Vector2i) -> void:
	if kind.begins_with("project:"):
		var id := kind.trim_prefix("project:")
		var p: Dictionary = Projects.PROJECTS[id]
		match Projects.state(id):
			"works":
				EventBus.message_requested.emit(str(p.name), "Les ouvriers de Mathis sont à pied d'œuvre. Encore %d jour%s de travaux." % [Projects.days_left(id), "s" if Projects.days_left(id) > 1 else ""])
			"done":
				EventBus.message_requested.emit(str(p.name), str(p.text))
			_:
				EventBus.message_requested.emit(str(p.name) + " (à l'abandon)", "%s\n\nLe chantier se finance depuis le Journal, rubrique Rénovations." % p.text)
		return
	if kind == "forge":
		EventBus.forge_requested.emit()
		return
	if kind == "booth":
		EventBus.booth_requested.emit()
		return
	if kind == "board":
		EventBus.board_requested.emit()
		return
	var building := kind.trim_prefix("door:")
	if building == "mine":
		_enter_mine()
		return
	if InteriorMap.LAYOUTS.has(building):
		if Events.gathering_now():
			EventBus.message_requested.emit(InteriorMap.LAYOUTS[building].name, "Fermé pour la fête ! Tout le monde est sur la place.")
		elif InteriorMap.is_open(building):
			Sfx.play("door")
			var rows: Array = InteriorMap.LAYOUTS[building].rows
			var door_x := String(rows[rows.size() - 1]).find("D")
			EventBus.map_change_requested.emit("in:" + building, Vector2i(door_x, rows.size() - 2))
		else:
			EventBus.message_requested.emit(InteriorMap.LAYOUTS[building].name, InteriorMap.closed_text(building))


## L'entrée de la mine est-elle dégagée ? (Gaston, fin du chapitre 2)
static func mine_open() -> bool:
	# (les parties commencées avant l'éboulement gardent l'accès)
	return PlayerState.flags.has("story_ch2") or PlayerState.flags.has("mine_kit")


func _enter_mine() -> void:
	if not mine_open():
		EventBus.message_requested.emit("Un éboulement", "Des rochers bouchent l'entrée de la mine depuis l'éboulement d'il y a dix ans. Gaston dit qu'il la dégagera quand le village sera de nouveau uni (chapitre 2 de l'histoire).")
		return
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
	var levels: Array = MineLevel.elevator_levels()
	if levels.size() == 1:
		EventBus.map_change_requested.emit("mine:1", Vector2i.ZERO)
	else:
		EventBus.elevator_requested.emit(levels)
