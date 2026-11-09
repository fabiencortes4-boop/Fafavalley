class_name ForestMap
extends WorldMap
## La forêt de la source, au nord de la ferme : cueillette, champignons,
## bois, un lac aux poissons, le vieux campement de Firmin... et, derrière
## les ronces, la source qui alimentait la fontaine de Valfleur.
##
## Débloquée par l'histoire : le tronc qui barre le chemin est dégagé à la
## fin du chapitre 1, les ronces sont coupées à la fin du chapitre 4, et la
## source jaillit de nouveau à la fin de l'histoire.
##
## Plan : X ronces, S bassin de la source, j feu de camp, z tente de
## Firmin, Q panneaux, G entrée de la grotte des lucioles, l arbres à bois (clairière des bûcherons : pins à
## l'est du chemin, platanes et chênes à l'ouest).

const MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTT.....,......TTTTTTTTTTTTTT",
	"TTTTTTTTTTTT...,...SS..,....TTTTTTTTTTTT",
	"TTTTTTTTTTT.....'..SS.......,TTTTTTTTTTT",
	"TTTTTTTTTT..,......==.....'.....TTTTTTTT",
	"TTTTTTTTTT.....R...==...m.....R.TTTTTTTT",
	"TTTTTTTTTTT.....Q..==...........TTTTTTTT",
	"TTTTTTTTTTTTTXXXXXXXXXXXXXXXXXXXTTTTTTTT",
	"TTTTTTTTTb.........==..........'..TTTTTT",
	"TTTTTTG.,....m.....==....,.........TTTTT",
	"TTTT.........R.....==.........R.....TTTT",
	"TTT....'..........====..............TTTT",
	"TTT..h.......,.....==.......~~~~~....TTT",
	"TT....jz...........==......~~~~~~~...TTT",
	"TT.....Q...........==.....~~~~~~~~~..TTT",
	"TT....,............==......~~~~~~~...TTT",
	"TTT.l..l.o..l..R...==.......~~~~~.....TT",
	"TTT.......m........==.....l........l..TT",
	"TTTT.l...'l..l.....==..l.b...m.l...,..TT",
	"TTTT...R...........==================TTT",
	"TTT....,.l.....h...==...l.,.l...o..l.TTT",
	"TTTTl.......l..m...====........l.....TTT",
	"TTTTT..b..R.........'==.l..l..R..l.TTTTT",
	"TTTTTT.l.............==.........TTTTTTTT",
	"TTTTTTTTT............==......TTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTT==TTTTTTTTTTTTTTTT",
]
const FARM_ENTRY := Vector2i(23, 2)  # à la ferme, au bout du chemin du nord


func _init() -> void:
	map_id = "forest"


func _map_rows() -> Array:
	return MAP


func display_name() -> String:
	return "Forêt de la source"


## Les ronces sont-elles coupées ? (fin du chapitre 4)
static func brambles_cut() -> bool:
	return PlayerState.flags.has("story_ch4")


## La source coule-t-elle ? (fin de l'histoire)
static func spring_flows() -> bool:
	return PlayerState.flags.has("story_ch5")


func _ground_tile(cell: Vector2i, ch: String) -> int:
	match ch:
		"X":
			return WorldTiles.GRASS if brambles_cut() else int(DECOR.get("b", WorldTiles.GRASS))
		"S", "j", "z", "l":
			return WorldTiles.GRASS
		"G":
			return WorldTiles.ROCK
	return super(cell, ch)


func _place_special(cell: Vector2i, ch: String) -> void:
	match ch:
		"X":
			if not brambles_cut():
				block_cell(cell)
				_interactables[cell] = "gate"
		"S":
			block_cell(cell)
			_add_sign(cell, "La source", "L'eau jaillit de nouveau, claire et fraîche. Elle sent la violette." if spring_flows() else "Un bassin de pierre, sec. On entend l'eau gronder sous la roche... Il faudrait la libérer, au fond de la mine.")
		"j", "z":
			block_cell(cell)
		"G":
			_interactables[cell] = "cave"
		"Q":
			if cell.y < 7:
				_add_sign(cell, "Une pierre gravée", "« Ici naît la source de Valfleur. Que son eau ne cesse jamais de chanter. » - Les fondateurs")
			else:
				_add_sign(cell, "Le campement de Firmin", "Une tente usée, un feu éteint, un carnet trempé : « La source est derrière les ronces. Elle baisse chaque année depuis l'éboulement. Si quelqu'un lit ceci : la clé est au fond de la mine. Prends soin de la vallée. - F. »")


func _interact(kind: String, _cell: Vector2i) -> void:
	if kind == "cave":
		EventBus.map_change_requested.emit("cave", Vector2i(8, 8))
		return
	if kind == "gate":
		EventBus.message_requested.emit("Des ronces", "Un mur de ronces épaisses. Derrière, on devine une clairière... Mathis aurait les outils pour les couper, quand la ferme sera bien lancée (chapitre 4 de l'histoire).")


func _after_build() -> void:
	_spawn_cell = Vector2i(22, 23)
	_place_player()
	Woods.ensure_seeded()
	Woods.changed.connect(_refresh_lumber)
	Tips.show("woods")
	_refresh_lumber()


# ------------------------------------------------------------ arbres à bois
static var _spots: Array = []

## Emplacements des arbres de la clairière : [case, essence].
## Mini-carte : arbres à bois abattus, souches et jeunes pousses.
func minimap_color(cell: Vector2i) -> Color:
	if Woods.trees.has(cell):
		if Woods.is_stump(cell):
			return Color(0.45, 0.3, 0.18)
		return Color(0.2, 0.42, 0.26) if Woods.stage(cell) >= 3 else Color(0.4, 0.68, 0.32)
	return Color(0, 0, 0, 0)


static func lumber_spots() -> Array:
	if _spots.is_empty():
		for y in MAP.size():
			var row := String(MAP[y])
			for x in row.length():
				if row[x] == "l":
					# Pinède à l'est du chemin, platanes au nord-ouest, chênes au sud-ouest
					_spots.append([Vector2i(x, y), "pine" if x > 20 else ("plane" if y <= 18 else "oak")])
	return _spots


var _lumber_cells: Dictionary = {}
const PLANT_GROUND := [".", ",", "'", "l"]


## Reflète les arbres dans la carte : cases bloquées (tuile d'arbre, de
## buisson pour les jeunes, de souche), et l'herbe là où il n'y a plus rien.
func _refresh_lumber() -> void:
	if not is_inside_tree():
		return
	for cell: Vector2i in _lumber_cells.keys():
		if not Woods.trees.has(cell):
			_ground.set_cell(cell, 0, WorldTiles.coords(WorldTiles.GRASS))
			_lumber_cells.erase(cell)
	for cell: Vector2i in Woods.trees:
		var tile: int
		if Woods.is_stump(cell):
			tile = WorldTiles.STUMP
		elif Woods.stage(cell) < 3:
			tile = WorldTiles.BUSH
		else:
			tile = WorldTiles.PINE if Woods.trees[cell].type == "pine" else WorldTiles.ROUND_TREE
		_ground.set_cell(cell, 0, WorldTiles.coords(tile))
		_lumber_cells[cell] = true


func _act_on_ground(cell: Vector2i) -> bool:
	if Woods.trees.has(cell):
		if _holding_tool() == "axe":
			_chop(cell)
		else:
			player.face_towards(cell - player_cell())
			var tip := "coupe-la à la hache" if Woods.is_stump(cell) else ("coupe-le à la hache pour du bois" if Woods.stage(cell) == 3 else "adulte dans %d jour(s)" % Woods.days_left(cell))
			EventBus.toast("%s : %s." % [Woods.label(cell), tip])
		return true
	var slot: Variant = Inventory.get_selected()
	if slot != null and GameData.item(slot.id).get("type") == "tree_seed":
		_plant_seed(cell, str(GameData.item(slot.id).get("tree", "")))
		return true
	return false


func _tool_hint(cell: Vector2i) -> String:
	if Woods.trees.has(cell) and _holding_tool() == "axe":
		return "Arracher" if Woods.is_stump(cell) else "Couper"
	var slot: Variant = Inventory.get_selected()
	if slot != null and GameData.item(slot.id).get("type") == "tree_seed" and _can_plant(cell):
		return "Planter"
	return super(cell)


func _can_plant(cell: Vector2i) -> bool:
	if not str(_ground_chars.get(cell, "")) in PLANT_GROUND or not is_walkable(cell):
		return false
	if _interactables.has(cell) or _forage_sprites.has(cell) or cell == player_cell() or cell.y >= _map_size.y - 2:
		return false
	# Pas collé à un autre arbre : on garde des allées pour passer
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if Woods.trees.has(cell + d) or _ground_chars.get(cell + d, "") == "=":
			return false
	return true


func _plant_seed(cell: Vector2i, type: String) -> void:
	if not _can_plant(cell):
		EventBus.toast("Plante-le sur l'herbe libre, à l'écart du chemin et des autres arbres.")
		return
	if not Woods.plant(cell, type):
		return
	Inventory.remove_from_slot(Inventory.selected, 1)
	player.face_towards(cell - player_cell())
	player.play_tool("bend", GameData.item_icon(str(Woods.TYPES[type].seed)), func() -> void:
		Sfx.play("plant")
		Fx.puff(_entities, cell_center(cell), Color(0.62, 0.45, 0.3, 0.7), 1.2))
	EventBus.toast("%s planté ! Adulte dans %d jours." % [Woods.TYPES[type].name, int(Woods.TYPES[type].grow)])


## Coup de hache : l'arbre encaisse, puis tombe (bois, graines) et laisse
## une souche ; la souche s'arrache à son tour.
func _chop(cell: Vector2i) -> void:
	var axe := GameData.item(Inventory.get_selected().id)
	if not spend_energy(int(axe.get("energy", 2))):
		return
	var power := int(axe.get("power", 1))
	var from := player_cell()
	player.face_towards(cell - from)
	player.play_tool("strike", GameData.item_icon(Inventory.get_selected().id), func() -> void:
		if not Woods.trees.has(cell):
			return
		var was_tree := not Woods.is_stump(cell) and Woods.stage(cell) == 3
		var res := Woods.chop(cell, power, from)
		var at := cell_center(cell) + Vector2(0, -6)
		Sfx.play("chop")
		Fx.burst(_entities, at, Fx.WOOD, 18 if res.done else 8, 60.0)
		if res.done:
			if was_tree:
				Sfx.play("tree_fall")
				Settings.vibrate(70)
				shake(3.5, 0.3)
				Fx.puff(_entities, cell_center(cell), Color(0.9, 0.85, 0.75, 0.9), 2.4)
				EventBus.toast("%s abattu !" % Woods.TYPES[Woods.trees[cell].type].name if Woods.trees.has(cell) else "Arbre abattu !")
			else:
				Fx.puff(_entities, cell_center(cell), Color(0.75, 0.6, 0.45, 0.8), 1.4)
			# Le bois tombe du côté opposé au joueur, en éventail
			var away := Vector2(cell - from).normalized() if cell != from else Vector2.DOWN
			for i in res.drops.size():
				var pickup := Pickup.new()
				pickup.item_id = str(res.drops[i])
				pickup.target = player
				var spread := Vector2(randf_range(-10, 10), randf_range(-8, 8))
				pickup.position = cell_center(cell) + away * float(4 + i % 3 * 3) + spread
				_entities.add_child(pickup)
		else:
			Settings.vibrate(15))


func _warp_for(cell: Vector2i) -> Dictionary:
	if cell.y >= _map_size.y - 1:
		return {"map": "farm", "cell": FARM_ENTRY}
	return {}
