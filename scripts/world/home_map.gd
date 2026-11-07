class_name HomeMap
extends WorldMap
## L'intérieur de la maison : on y dort (lit), on y cuisine (cuisinière),
## et on en sort par la porte du bas vers la ferme.
##
## Plan : # mur, _ plancher, Z lit, k cuisinière, t table, c chaise,
## p cheminée, r tapis, x coffre décoratif, D porte.

const MAP := [
	"############",
	"#Z_____k__x#",
	"#__________#",
	"#___rr__tc_#",
	"#p__rr__c__#",
	"#__________#",
	"#__________#",
	"######D#####",
]
const FARM_DOOR_FRONT := Vector2i(7, 7)  # devant la porte de la maison, à la ferme

var bed_cell: Vector2i = Vector2i(1, 1)


func _init() -> void:
	map_id = "home"


func _map_rows() -> Array:
	return MAP


func display_name() -> String:
	return "Maison"


func _ground_tile(_cell: Vector2i, ch: String) -> int:
	match ch:
		"#":
			return WorldTiles.MINE_WALL
		"D":
			return WorldTiles.MINE_FLOOR_SHADE
		"t", "c", "p", "x", "k", "Z":
			return WorldTiles.BARREL
	return WorldTiles.MINE_FLOOR_2 if ch == "r" else WorldTiles.MINE_FLOOR


func _place_special(cell: Vector2i, ch: String) -> void:
	match ch:
		"Z":
			_interactables[cell] = "bed"
			bed_cell = cell
		"k":
			_interactables[cell] = "kitchen"
		"D":
			_interactables[cell] = "exit"
		"x":
			_add_sign(cell, "Vieux coffre", "Le coffre de Firmin. Il est vide... à part une vieille photo de la ferme, toute fleurie.")
		"p":
			_add_sign(cell, "Cheminée", "Un bon feu crépite. Il fait bon chez soi.")
		"c":
			# Chaise : elle regarde la table voisine
			var look := Vector2i.DOWN
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if _ground_chars.get(cell + d, "") == "t":
					look = d
			add_seat(cell, look)


func _after_build() -> void:
	# Au réveil : à côté du lit
	_spawn_cell = bed_cell + Vector2i(1, 1)
	_place_player()
	if Marriage.spouse_place() == "home":
		_spawn_spouse(Vector2i(8, 5))


func _place_player() -> void:
	player.step_sound = "step_stone"
	super()


func _interact(kind: String, _cell: Vector2i) -> void:
	match kind:
		"bed":
			EventBus.sleep_requested.emit()
		"kitchen":
			EventBus.kitchen_requested.emit()
		"exit":
			Sfx.play("door")
			EventBus.map_change_requested.emit("farm", FARM_DOOR_FRONT)


## Marcher sur le seuil de la porte = sortir.
func _warp_for(cell: Vector2i) -> Dictionary:
	if _interactables.get(cell, "") == "exit":
		Sfx.play("door")
		return {"map": "farm", "cell": FARM_DOOR_FRONT}
	return {}


func _update_tint(_hour: int, _minute: int) -> void:
	_tint.color = Color(1.0, 0.92, 0.82)  # lumière chaude d'intérieur
