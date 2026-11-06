class_name Farm
extends WorldMap
## La ferme : labour, arrosage, semis, récolte, expédition, sommeil.
## Affiche l'état de FarmState (la logique de croissance y vit).
##
## Caractères propres à la ferme : H maison (3x3), G grange (3x6),
## B coffre d'expédition, C poule, V vache.

const MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTT..T.T..T...TTT......T..TTT...G...TT",
	"TTT........f.........R................TT",
	"TT....H.........o...............C.....TT",
	"TTT........................Q..........TT",
	"TT........B.........'......==..V......TT",
	"TTT....==...b..............==....h...kTT",
	"TTT..f.==..................==...........",
	"TT.....=================================",
	"TTT....=================================",
	"TTT...............................'.....",
	"TTT................k....m.............TT",
	"TTT.....m.....,...............,.....bTTT",
	"TTT.R................................TTT",
	"TT....................'.....~~~~~~...TTT",
	"TTT........................~~~~~~~~..TTT",
	"TTT.......................~~~~~~~~~...TT",
	"TT........'...............~~~~~~~~~~..TT",
	"TT........................~~~~~~~~~~..TT",
	"TT.....................o..~~~~~~~~~~..TT",
	"TTT.............,.........~~~~~~~~~~..TT",
	"TT....,....................~~~~~~~~...TT",
	"TTT.........................~~~~~~...TTT",
	"TT...................................oTT",
	"TTT.........b......................m..TT",
	"TTT...............'......R............TT",
	"TTT..TTTT.T...TT....T......T..T.T.T...TT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]

const TILLABLE := [".", ",", "'", "C", "V"]
const CROP_STAGES := 4
const CROP_ROWS := 6

var _soil: TileMapLayer
var _crop_sprites: Dictionary = {}  # Vector2i -> Sprite2D
var _grass_coords := [
	WorldTiles.coords(WorldTiles.GRASS), WorldTiles.coords(WorldTiles.GRASS_TUFT),
	WorldTiles.coords(WorldTiles.GRASS_FLOWERS),
]


func _init() -> void:
	map_id = "farm"


func _map_rows() -> Array:
	return MAP


func display_name() -> String:
	return "Ferme"


func _place_special(cell: Vector2i, ch: String) -> void:
	match ch:
		"H":
			var door := _add_building(cell, Vector2i(3, 3), "res://assets/sprites/house.png", 1)
			_interactables[door] = "door"
			_spawn_cell = door + Vector2i.DOWN
		"G":
			_add_building(cell, Vector2i(3, 6), "res://assets/sprites/barn.png")
		"B":
			_add_building(cell, Vector2i(1, 1), "res://assets/sprites/shipping_bin.png")
			_interactables[cell] = "bin"
		"Q":
			_add_sign(cell, "Panneau", "Valfleur, le village : suis le chemin vers l'est. L'épicerie de Rosalie vend des graines de 9h à 17h.")
		"C", "V":
			var critter := Critter.new()
			critter.frame = 0 if ch == "C" else 1
			critter.position = Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE)
			_entities.add_child(critter)


func _after_build() -> void:
	_soil = TileMapLayer.new()
	_soil.tile_set = _ground.tile_set
	_soil.z_index = -1
	add_child(_soil)
	EventBus.farm_tile_changed.connect(_refresh_cell)
	_refresh_all()


func _warp_for(cell: Vector2i) -> Dictionary:
	if cell.x >= _map_size.x - 1:
		return {"map": "village", "cell": Vector2i(2, clampi(cell.y, 9, 10))}
	return {}


# ------------------------------------------------------------ actions
func _interact(kind: String, _cell: Vector2i) -> void:
	match kind:
		"door":
			EventBus.sleep_requested.emit()
		"bin":
			_ship_selected()


func _act_on_ground(cell: Vector2i) -> bool:
	if FarmState.is_mature(cell):
		_harvest(cell)
		return true
	var slot: Variant = Inventory.get_selected()
	if slot == null:
		return false
	var item := GameData.item(slot.id)
	match str(item.get("type", "")):
		"tool":
			_use_tool(str(item.get("tool", "")), int(item.get("energy", 2)), cell)
			return true
		"seed":
			_plant(cell, str(item.get("crop", "")))
			return true
	return false


func _use_tool(tool: String, energy: int, cell: Vector2i) -> void:
	match tool:
		"hoe":
			if not _can_till(cell):
				return
			if not spend_energy(energy):
				return
			player.play_use()
			FarmState.till(cell)
		"watering_can":
			if _ground_chars.get(cell, "") == "~":
				PlayerState.refill_water()
				player.play_use()
				EventBus.toast("Arrosoir rempli !")
				return
			if not FarmState.is_tilled(cell) or FarmState.is_watered(cell):
				return
			if PlayerState.water <= 0:
				EventBus.toast("Arrosoir vide : remplis-le à l'étang.")
				return
			if not spend_energy(energy):
				return
			PlayerState.use_water()
			player.play_use()
			FarmState.water(cell)


func _can_till(cell: Vector2i) -> bool:
	return (
		str(_ground_chars.get(cell, "")) in TILLABLE
		and _ground.get_cell_atlas_coords(cell) in _grass_coords
		and not _blocked.has(cell)
		and not _interactables.has(cell)
		and not FarmState.is_tilled(cell)
		and cell != player_cell()
	)


func _plant(cell: Vector2i, crop_id: String) -> void:
	if crop_id == "" or not FarmState.is_tilled(cell) or FarmState.get_crop(cell) != "":
		return
	if not GameData.crop_in_season(crop_id, TimeManager.season):
		EventBus.toast("Ce n'est pas la saison pour planter ça.")
		return
	if FarmState.plant(cell, crop_id):
		Inventory.remove_from_slot(Inventory.selected, 1)


func _harvest(cell: Vector2i) -> void:
	var harvest_id := str(GameData.crop(FarmState.get_crop(cell)).get("harvest", ""))
	if not Inventory.can_add(harvest_id):
		EventBus.toast("Inventaire plein !")
		return
	var got := FarmState.harvest(cell)
	if got != "":
		Inventory.add_item(got, 1)
		player.play_use()
		EventBus.toast("+1 %s" % GameData.item_name(got))


func _ship_selected() -> void:
	var slot: Variant = Inventory.get_selected()
	if slot == null or int(GameData.item(slot.id).get("sell", 0)) <= 0 or GameData.item(slot.id).get("type") == "tool":
		EventBus.toast("Sélectionne un objet à vendre, puis touche le coffre.")
		return
	var qty: int = slot.qty
	FarmState.ship(slot.id, qty)
	EventBus.toast("Expédié : %d x %s (payé cette nuit)" % [qty, GameData.item_name(slot.id)])
	Inventory.remove_from_slot(Inventory.selected, qty)


# ------------------------------------------------------------ affichage
func _on_day_started(day: int, season: int, year: int) -> void:
	super(day, season, year)
	_refresh_all()


func _refresh_all() -> void:
	_soil.clear()
	for cell: Vector2i in _crop_sprites.keys():
		if FarmState.get_crop(cell) == "":
			_crop_sprites[cell].queue_free()
			_crop_sprites.erase(cell)
	for cell: Vector2i in FarmState.tiles:
		_refresh_soil(cell)
		_refresh_crop(cell)


func _refresh_cell(cell: Vector2i) -> void:
	# Une parcelle change l'apparence de ses voisines (rangées continues).
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		_refresh_soil(cell + offset)
	_refresh_crop(cell)


func _refresh_soil(cell: Vector2i) -> void:
	if not FarmState.is_tilled(cell):
		_soil.erase_cell(cell)
		return
	var left := FarmState.is_tilled(cell + Vector2i.LEFT)
	var right := FarmState.is_tilled(cell + Vector2i.RIGHT)
	var up := FarmState.is_tilled(cell + Vector2i.UP)
	var down := FarmState.is_tilled(cell + Vector2i.DOWN)
	var index := WorldTiles.SOIL_SINGLE
	if left or right:
		index = WorldTiles.SOIL_H_LEFT if not left else (WorldTiles.SOIL_H_RIGHT if not right else WorldTiles.SOIL_H_MID)
	elif up or down:
		index = WorldTiles.SOIL_V_TOP if not up else (WorldTiles.SOIL_V_BOTTOM if not down else WorldTiles.SOIL_V_MID)
	if FarmState.is_watered(cell):
		index += 1
	_soil.set_cell(cell, 0, WorldTiles.coords(index))


func _refresh_crop(cell: Vector2i) -> void:
	var stage := FarmState.crop_stage(cell)
	if stage < 0:
		if _crop_sprites.has(cell):
			_crop_sprites[cell].queue_free()
			_crop_sprites.erase(cell)
		return
	var sprite: Sprite2D = _crop_sprites.get(cell)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.texture = load("res://assets/sprites/crops.png")
		sprite.hframes = CROP_STAGES
		sprite.vframes = CROP_ROWS
		sprite.centered = false
		sprite.offset = Vector2(0, -13)
		sprite.position = Vector2(cell.x * TILE, cell.y * TILE + 12)
		_entities.add_child(sprite)
		_crop_sprites[cell] = sprite
	var row := int(GameData.crop(FarmState.get_crop(cell)).get("sprite_row", 0))
	sprite.frame = row * CROP_STAGES + mini(stage, CROP_STAGES - 1)
