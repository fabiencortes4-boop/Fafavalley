extends Node
## Point d'entrée : écran titre, puis lancement de la ferme et du HUD.

var _title_layer: CanvasLayer


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
	var hud := Hud.new()
	var farm := Farm.new()
	farm.hud = hud
	add_child(farm)
	add_child(hud)
	GameFlow.begin()
