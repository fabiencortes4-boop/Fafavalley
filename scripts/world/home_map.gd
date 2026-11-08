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
## Après l'agrandissement (chez Mathis) : une grande pièce à droite.
const MAP_BIG := [
	"#################",
	"#Z_____k__x______#",
	"#________________#",
	"#___rr__tc_______#",
	"#p__rr__c________#",
	"#________________#",
	"#________________#",
	"######D###########",
]
const FARM_DOOR_FRONT := Vector2i(7, 7)  # devant la porte de la maison, à la ferme

signal furniture_changed

var bed_cell: Vector2i = Vector2i(1, 1)


func _init() -> void:
	map_id = "home"


func _map_rows() -> Array:
	return MAP_BIG if PlayerState.flags.has("house_big") else MAP


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
	for cell: Vector2i in Machines.furniture:
		if _ground_chars.has(cell):
			block_cell(cell)
			_furniture_seat(cell)
	# Au réveil : à côté du lit
	_spawn_cell = bed_cell + Vector2i(1, 1)
	_place_player()
	if Marriage.spouse_place() == "home":
		_spawn_spouse(Vector2i(8, 5))
	_spawn_child()


## L'enfant : au berceau près du lit, puis il joue sur le tapis.
var child: Node2D


func _spawn_child() -> void:
	var stage := Marriage.child_stage()
	if stage == "":
		return
	var cell := bed_cell + Vector2i(2, 0) if stage == "baby" else Vector2i(4, 5)
	child = Node2D.new()
	child.set_meta("child", stage)
	child.position = cell_center(cell)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/sprites/player.png")
	sprite.scale = Vector2(0.55, 0.55)
	sprite.offset = Vector2(0, -8)
	child.add_child(sprite)
	_entities.add_child(child)
	block_cell(cell)
	_interactables[cell] = "child"


func _place_player() -> void:
	player.step_sound = "step_stone"
	super()


# ------------------------------------------------------------ meubles
## Poser le meuble tenu en main sur le plancher.
func _act_on_ground(cell: Vector2i) -> bool:
	var slot: Variant = Inventory.get_selected()
	if slot == null or str(GameData.item(slot.id).get("type", "")) != "furniture":
		return false
	if _ground_chars.get(cell, "") != "_" or _blocked.has(cell) or cell == player_cell() or _interactables.has(cell):
		EventBus.toast("Pose le meuble sur le plancher libre, devant toi.")
		return true
	Machines.furniture[cell] = str(slot.id)
	Inventory.remove_from_slot(Inventory.selected, 1)
	block_cell(cell)
	_furniture_seat(cell)
	player.play_use()
	Sfx.play("drop")
	furniture_changed.emit()
	return true


## Un fauteuil se comporte comme une chaise : on s'y assoit.
func _furniture_seat(cell: Vector2i) -> void:
	if GameData.item(str(Machines.furniture[cell])).get("seat", false):
		add_seat(cell, Vector2i.DOWN)


## Pioche en main : on reprend le meuble (même un fauteuil, au lieu de s'y asseoir).
func act_on(cell: Vector2i) -> void:
	if _holding_tool() == "pickaxe" and Machines.furniture.has(cell) and not player.seated:
		_use_pickaxe(cell, 0)
		return
	super(cell)


## La pioche reprend un meuble.
func _use_pickaxe(cell: Vector2i, _energy: int) -> void:
	if not Machines.furniture.has(cell):
		return
	var id := str(Machines.furniture[cell])
	if Inventory.add_item(id, 1) > 0:
		EventBus.toast("Inventaire plein !")
		return
	Machines.furniture.erase(cell)
	_blocked.erase(cell)
	if seats.has(cell):
		seats.erase(cell)
		_interactables.erase(cell)
	if _static_blocks.has(cell):
		_static_blocks[cell].queue_free()
		_static_blocks.erase(cell)
	player.play_use()
	Sfx.play("pickup")
	furniture_changed.emit()


func _interact(kind: String, _cell: Vector2i) -> void:
	match kind:
		"bed":
			EventBus.sleep_requested.emit()
		"child":
			EventBus.message_requested.emit(Marriage.child_name, Marriage.play_with_child())
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
