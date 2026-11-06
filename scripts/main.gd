extends Node
## Point d'entrée : écran titre, puis lancement de la ferme et du HUD.

var _title_layer: CanvasLayer
var _hud: Hud
var _world: WorldMap
var _arrival: Vector2 = Vector2.INF


func _ready() -> void:
	_title_layer = CanvasLayer.new()
	add_child(_title_layer)
	var root := Control.new()
	root.theme = UiTheme.build()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.52, 0.78, 0.41)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	var title := Label.new()
	title.text = "Fafavalley"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Une petite ferme, une grande aventure"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	if SaveManager.has_save():
		_add_button(box, "Continuer", _start.bind(true))
	_add_button(box, "Nouvelle partie", _start.bind(false))


func _add_button(box: Container, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 26)
	b.pressed.connect(callback)
	box.add_child(b)


func _start(load_save: bool) -> void:
	if not (load_save and GameFlow.continue_game()):
		GameFlow.new_game()
	_title_layer.queue_free()
	_hud = Hud.new()
	add_child(_hud)
	_load_map(PlayerState.map)
	EventBus.map_change_requested.connect(_on_map_change_requested)
	TimeManager.day_started.connect(_on_day_started)
	GameFlow.begin()


func current_map() -> WorldMap:
	return _world


## Remplace la carte affichée (la précédente est libérée).
func _load_map(map_id: String) -> void:
	if _world != null:
		remove_child(_world)
		_world.queue_free()
	PlayerState.map = map_id
	if map_id.begins_with("mine:"):
		var mine := MineLevel.new()
		mine.setup(int(map_id.trim_prefix("mine:")))
		_world = mine
	elif map_id == "village":
		_world = Village.new()
	else:
		_world = Farm.new()
	_world.hud = _hud
	add_child(_world)
	move_child(_world, 0)
	_hud.set_location(_world.display_name())


func _on_map_change_requested(map_id: String, cell: Vector2i) -> void:
	_arrival = Vector2(cell * WorldMap.TILE) + Vector2(WorldMap.TILE / 2.0, WorldMap.TILE * 0.75)
	# Différé : on ne libère pas une carte pendant son propre traitement physique.
	_switch_to.call_deferred(map_id)


func _switch_to(map_id: String) -> void:
	if _arrival != Vector2.INF:
		# Appliqué ici : le joueur de l'ancienne carte a pu réécrire sa position.
		PlayerState.position = _arrival
		PlayerState.has_position = true
		_arrival = Vector2.INF
	_load_map(map_id)
	_hud.fade_in()


## Au réveil, on est toujours à la ferme.
func _on_day_started(_day: int, _season: int, _year: int) -> void:
	if _world != null and _world.map_id != PlayerState.map:
		_switch_to.call_deferred(PlayerState.map)
