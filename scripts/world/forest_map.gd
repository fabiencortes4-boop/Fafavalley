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
## Firmin, Q panneaux.

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
	"TTTTTT..,....m.....==....,.........TTTTT",
	"TTTT.........R.....==.........R.....TTTT",
	"TTT....'..........====..............TTTT",
	"TTT..h.......,.....==.......~~~~~....TTT",
	"TT....jz...........==......~~~~~~~...TTT",
	"TT.....Q...........==.....~~~~~~~~~..TTT",
	"TT....,............==......~~~~~~~...TTT",
	"TTT......o.....R...==.......~~~~~.....TT",
	"TTT.......m........==.................TT",
	"TTTT.....'.........==....b...m.....,..TT",
	"TTTT...R...........==================TTT",
	"TTT....,.......h...==.....,.....o....TTT",
	"TTTT...........m...====..............TTT",
	"TTTTT..b..R.........'==.......R....TTTTT",
	"TTTTTT...............==.........TTTTTTTT",
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
		"S", "j", "z":
			return WorldTiles.GRASS
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
		"Q":
			if cell.y < 7:
				_add_sign(cell, "Une pierre gravée", "« Ici naît la source de Valfleur. Que son eau ne cesse jamais de chanter. » - Les fondateurs")
			else:
				_add_sign(cell, "Le campement de Firmin", "Une tente usée, un feu éteint, un carnet trempé : « La source est derrière les ronces. Elle baisse chaque année depuis l'éboulement. Si quelqu'un lit ceci : la clé est au fond de la mine. Prends soin de la vallée. - F. »")


func _interact(kind: String, _cell: Vector2i) -> void:
	if kind == "gate":
		EventBus.message_requested.emit("Des ronces", "Un mur de ronces épaisses. Derrière, on devine une clairière... Mathis aurait les outils pour les couper, quand la ferme sera bien lancée (chapitre 4 de l'histoire).")


func _after_build() -> void:
	_spawn_cell = Vector2i(22, 23)
	_place_player()


func _warp_for(cell: Vector2i) -> Dictionary:
	if cell.y >= _map_size.y - 1:
		return {"map": "farm", "cell": FARM_ENTRY}
	return {}
