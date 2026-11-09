class_name CaveMap
extends WorldMap
## La grotte des lucioles, cachée dans la forêt : trois leviers gravés
## (étoile, lune, soleil) à actionner dans le bon ordre, que donne l'énigme
## de la tablette. La grille s'ouvre alors sur le coffre de Firmin.
##
## Plan : # roche, e/l/s leviers (étoile, lune, soleil), T tablette,
## C coffre, D sortie vers la forêt.

signal puzzle_changed

const MAP := [
	"################",
	"######....######",
	"####...l....####",
	"###..........###",
	"##.e....T...s.##",
	"##............##",
	"###....C.....###",
	"####........####",
	"#######..#######",
	"#######.D#######",
	"################",
]
const ORDER := ["e", "l", "s"]
const NAMES := {"e": "l'étoile", "l": "la lune", "s": "le soleil"}
const RIDDLE := "« Quand l'étoile du berger s'allume, la lune se lève à sa suite ; le soleil, lui, arrive toujours le dernier. » - F."
const FOREST_DOOR := Vector2i(6, 10)  # devant l'entrée, dans la forêt

var pulled: Array = []


func _init() -> void:
	map_id = "cave"


func _map_rows() -> Array:
	return MAP


func display_name() -> String:
	return "Grotte des lucioles"


static func solved() -> bool:
	return PlayerState.flags.has("cave_solved")


func _ground_tile(cell: Vector2i, ch: String) -> int:
	if ch == "#":
		return WorldTiles.MINE_WALL if _ground_chars.get(cell + Vector2i.DOWN, "#") != "#" else WorldTiles.MINE_VOID
	return WorldTiles.MINE_FLOOR if _hash(cell) % 5 else WorldTiles.MINE_FLOOR_2


func _place_special(cell: Vector2i, ch: String) -> void:
	match ch:
		"e", "l", "s":
			block_cell(cell)
			_interactables[cell] = "lever:" + ch
		"T":
			block_cell(cell)
			_add_sign(cell, "Une tablette gravée", RIDDLE)
		"C":
			block_cell(cell)
			_interactables[cell] = "cave_chest"


func _after_build() -> void:
	_spawn_cell = Vector2i(8, 8)
	_place_player()
	Tips.show("cave")


func _warp_for(cell: Vector2i) -> Dictionary:
	if _ground_chars.get(cell, "") == "D":
		return {"map": "forest", "cell": FOREST_DOOR}
	return {}


func _interact(kind: String, _cell: Vector2i) -> void:
	if kind.begins_with("lever:"):
		_pull(kind.trim_prefix("lever:"))
	elif kind == "cave_chest":
		_open_chest()


## Un levier : dans l'ordre de l'énigme, la grille s'ouvre ; sinon tout
## revient en place.
func _pull(lever: String) -> void:
	player.play_use()
	if solved():
		EventBus.toast("Le mécanisme est déjà ouvert.")
		return
	if lever in pulled:
		return
	pulled.append(lever)
	Sfx.play("clink")
	if pulled != ORDER.slice(0, pulled.size()):
		pulled.clear()
		Sfx.play("error")
		shake(1.5, 0.2)
		EventBus.toast("Les leviers reviennent en place dans un grincement. Ce n'était pas le bon ordre...")
	elif pulled.size() == ORDER.size():
		PlayerState.flags["cave_solved"] = true
		Sfx.play("levelup")
		shake(3.0, 0.4)
		EventBus.toast("Un grondement sourd... La grille du coffre se lève !")
	else:
		EventBus.toast("Clac ! Le levier de %s reste baissé. (%d/3)" % [NAMES[lever], pulled.size()])
	puzzle_changed.emit()


func _open_chest() -> void:
	player.play_use()
	if not solved():
		EventBus.toast("Une grille de fer protège le coffre. Il doit y avoir un mécanisme quelque part...")
		return
	if PlayerState.flags.has("cave_chest"):
		EventBus.toast("Le coffre de Firmin est vide. Mais quelle aventure !")
		return
	PlayerState.flags["cave_chest"] = true
	Inventory.add_gold(1500)
	for e: Array in [["emerald", 2], ["fossil_skull", 1], ["seed_hybrid", 3]]:
		if Inventory.add_item(str(e[0]), int(e[1])) > 0:
			EventBus.toast("Sac plein : une partie du trésor est restée dans le coffre.")
	Sfx.play("achievement")
	Story.bump("caves")
	EventBus.message_requested.emit("Le coffre de Firmin", "Un mot plié dans le coffre : « Bravo, petit malin. Voici mes économies et mes plus belles trouvailles. Prends soin de la vallée. - F. »\n\n+1500 or, 2 émeraudes, un crâne fossile et 3 graines hybrides.")
	puzzle_changed.emit()
