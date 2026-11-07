class_name Hud
extends CanvasLayer
## Interface en jeu, pensée pour le tactile : date/heure/or, énergie,
## barre rapide, joystick, bouton Action, menus (boutique, sommeil, pause).
## Les fenêtres mettent le jeu en pause (le temps s'arrête).

const SLOT_SIZE := 30  # cases de la barre rapide (icônes x1.5)
const ACTION_SCALE := 3.0
const ACTION_SIZE := 16.0 * ACTION_SCALE
const ACTION_MARGIN := Vector2(12, 36)

var _root: Control
var _date_label: Label
var _time_label: Label
var _gold_label: Label
var _water_label: Label
var _energy_bar: ProgressBar
var _health_bar: ProgressBar
var _location_label: Label
var _weather_icon: TextureRect
var _gold_panel: PanelContainer
var _top_panel: PanelContainer
var _menu_button: Button
var _bag_button: Button
var _story_button: Button
var _tutorial_panel: PanelContainer
var _tutorial_label: Label
var _closing_silently: bool = false
var _title_box: VBoxContainer
var _zone_label: Label
var _minimap: Minimap
var _last_selected: int = -1
var _picked: int = -1  # case choisie dans l'écran du sac
var _scroll_memory: Dictionary = {}  # titre de fenêtre -> position de défilement
var _hotbar: PanelContainer
var _slots: Array[Panel] = []
var _slot_icons: Array[TextureRect] = []
var _slot_labels: Array[Label] = []
var _joystick: VirtualJoystick
var _action_button: TouchScreenButton
var _action_icon: Sprite2D
var _hint_panel: PanelContainer
var _hint_label: Label
var _toast: Label
var _toast_tween: Tween
var _modal: Control
var _modal_closable: bool = true
var _modal_closed_at: int = -1000
var _dialog_label: Label
var _dialog_tween: Tween
var _fade: ColorRect
var _hearts_texture: Texture2D = load("res://assets/sprites/hearts.png")
var _slot_style: StyleBoxTexture
var _slot_selected_style: StyleBoxTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiTheme.build()
	Settings.changed.connect(func() -> void:
		# Taille du texte réglable (Menu -> Texte)
		_root.theme.default_font_size = Settings.font_size()
		_layout.call_deferred())
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build_top_panel()
	_build_energy_bar()
	_build_menu_button()
	_build_hotbar()
	_build_joystick()
	_build_action_button()
	_build_toast()
	_minimap = Minimap.new()
	_root.add_child(_minimap)
	_zone_label = Label.new()
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_label.modulate.a = 0.0
	_root.add_child(_zone_label)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.03, 0.08, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_fade)

	EventBus.inventory_changed.connect(_refresh_hotbar)
	EventBus.gold_changed.connect(func(_g: int) -> void: _refresh_status())
	EventBus.energy_changed.connect(_on_energy_changed)
	EventBus.health_changed.connect(func(v: int, m: int) -> void:
		_health_bar.max_value = m
		_health_bar.value = v)
	EventBus.eat_requested.connect(ask_eat)
	EventBus.elevator_requested.connect(open_elevator)
	EventBus.forge_requested.connect(open_crafting.bind("forge"))
	EventBus.chest_requested.connect(func(cell: Vector2i) -> void:
		Sfx.play("chest")
		open_chest(cell))
	EventBus.mail_requested.connect(func() -> void:
		Sfx.play("letter")
		open_mail())
	EventBus.water_changed.connect(func(_v: int, _m: int) -> void: _refresh_hotbar())
	EventBus.toast_requested.connect(show_toast)
	EventBus.shop_requested.connect(open_shop.bind("store"))
	EventBus.shop_opened.connect(open_shop)
	EventBus.animals_requested.connect(open_animals)
	EventBus.kitchen_requested.connect(open_crafting.bind("craft"))
	EventBus.zone_entered.connect(_on_zone_entered)
	EventBus.story_advanced.connect(_on_story_advanced)
	EventBus.booth_requested.connect(open_booth)
	EventBus.board_requested.connect(open_board)
	EventBus.heart_scene_requested.connect(_on_heart_scene)
	_build_tutorial()
	TimeManager.day_started.connect(func(_d: int, _s: int, _y: int) -> void:
		var fest := Events.festival_today()
		var bday := HeartEvents.birthday_today()
		if not fest.is_empty():
			show_toast("Aujourd'hui : %s au village, de %dh à %dh !" % [fest.name, int(fest.start), int(fest.end)])
		elif bday != "":
			show_toast("C'est l'anniversaire de %s aujourd'hui ! Un cadeau lui ferait plaisir." % GameData.npc(bday).name)
		elif Marriage.last_help != "":
			show_toast(Marriage.last_help)
		_nature_report())
	EventBus.npc_bubble.connect(func(npc_id: String, text: String) -> void:
		if View3D.current == null:
			show_toast("%s : %s" % [GameData.npc(npc_id).get("name", ""), text]))
	EventBus.sleep_requested.connect(ask_sleep)
	EventBus.day_summary.connect(show_summary)
	EventBus.dialogue_requested.connect(show_dialogue)
	EventBus.message_requested.connect(show_message)
	TimeManager.time_changed.connect(func(_h: int, _m: int) -> void: _refresh_status())
	TimeManager.day_started.connect(func(_d: int, _s: int, _y: int) -> void: _refresh_status())
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_hotbar()
	_refresh_status()
	_on_energy_changed(PlayerState.energy, PlayerState.MAX_ENERGY)
	_health_bar.max_value = PlayerState.MAX_HEALTH
	_health_bar.value = PlayerState.health


# ------------------------------------------------------------ construction
## Horloge en haut à droite : jour de la semaine, date, météo, heure, lieu ;
## la bourse est juste en dessous.
func _build_top_panel() -> void:
	_top_panel = PanelContainer.new()
	_root.add_child(_top_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	_top_panel.add_child(box)
	_date_label = Label.new()
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_date_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	_weather_icon = TextureRect.new()
	_weather_icon.custom_minimum_size = Vector2(12, 12)
	_weather_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(_weather_icon)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 16)
	row.add_child(_time_label)
	_location_label = Label.new()
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_label.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	box.add_child(_location_label)
	_gold_panel = PanelContainer.new()
	_root.add_child(_gold_panel)
	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 4)
	_gold_panel.add_child(gold_row)
	var coin := TextureRect.new()
	coin.texture = _hud_icon(3)
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	gold_row.add_child(coin)
	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	gold_row.add_child(_gold_label)
	_water_label = Label.new()  # gardé pour compatibilité (l'eau s'affiche sur l'arrosoir)


func _hud_icon(index: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = load("res://assets/sprites/hud_icons.png")
	tex.region = Rect2(index * 12, 0, 12, 12)
	return tex


func _build_energy_bar() -> void:
	_energy_bar = ProgressBar.new()
	_energy_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_energy_bar.show_percentage = false
	_energy_bar.custom_minimum_size = Vector2(12, 60)
	_energy_bar.size = Vector2(12, 60)
	_root.add_child(_energy_bar)
	_health_bar = ProgressBar.new()
	_health_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(12, 60)
	_health_bar.size = Vector2(12, 60)
	var red := StyleBoxFlat.new()
	red.bg_color = Color(0.86, 0.3, 0.3)
	red.set_expand_margin_all(-3)
	_health_bar.add_theme_stylebox_override("fill", red)
	_root.add_child(_health_bar)
	for pair in [[_energy_bar, "E"], [_health_bar, "V"]]:
		var tag := Label.new()
		tag.text = pair[1]
		tag.position = Vector2(2, 61)
		pair[0].add_child(tag)


func _build_menu_button() -> void:
	_menu_button = Button.new()
	_menu_button.text = "Menu"
	_menu_button.pressed.connect(open_pause_menu)
	_root.add_child(_menu_button)
	_bag_button = Button.new()
	_bag_button.text = "Sac"
	_bag_button.pressed.connect(open_bag)
	_root.add_child(_bag_button)
	_story_button = Button.new()
	_story_button.text = "Histoire"
	_story_button.pressed.connect(open_story)
	_root.add_child(_story_button)


func _build_hotbar() -> void:
	_slot_style = UiTheme.box("ui_slot", 4, 2)
	_slot_selected_style = UiTheme.box("ui_slot_selected", 4, 2)
	_hotbar = PanelContainer.new()
	_root.add_child(_hotbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	_hotbar.add_child(row)
	for i in Inventory.SIZE:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot)
		slot.pivot_offset = Vector2(SLOT_SIZE, SLOT_SIZE) / 2.0
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(3, 2)
		icon.size = Vector2(24, 24)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var qty := Label.new()
		qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty.position = Vector2(0, 18)
		qty.size = Vector2(SLOT_SIZE - 3, 10)
		slot.add_child(qty)
		_slots.append(slot)
		_slot_icons.append(icon)
		_slot_labels.append(qty)


func _build_joystick() -> void:
	_joystick = VirtualJoystick.new()
	_root.add_child(_joystick)


func _build_action_button() -> void:
	_action_button = TouchScreenButton.new()
	_action_button.texture_normal = load("res://assets/sprites/ui_round.png")
	_action_button.texture_pressed = load("res://assets/sprites/ui_round_dark.png")
	_action_button.scale = Vector2(ACTION_SCALE, ACTION_SCALE)
	_action_button.action = "use_tool"
	add_child(_action_button)
	# L'icône de l'objet en main s'affiche sur le bouton.
	_action_icon = Sprite2D.new()
	_action_icon.position = Vector2(8, 8)
	_action_icon.scale = Vector2.ONE * (2.0 / ACTION_SCALE)
	_action_button.add_child(_action_icon)
	# Ce que fera le bouton (« Labourer », « Parler », « Entrer »...)
	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override("panel", UiTheme.box("ui_button", 5, 3))
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint_panel)
	_hint_label = Label.new()
	_hint_label.add_theme_color_override("font_color", UiTheme.TEXT_DARK)
	_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint_label)


func _build_toast() -> void:
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var hb := _hotbar.get_combined_minimum_size()
	_hotbar.size = hb
	_hotbar.position = Vector2((vp.x - hb.x) / 2.0, vp.y - hb.y - 3)
	# Bouton Action au-dessus de la barre, à droite ; jauges au-dessus
	_action_button.position = Vector2(vp.x - ACTION_SIZE - 10, _hotbar.position.y - ACTION_SIZE - 8)
	_energy_bar.position = Vector2(vp.x - 18, _action_button.position.y - 74)
	_health_bar.position = _energy_bar.position - Vector2(15, 0)
	# Joystick flottant : moitié gauche, sous la mini-carte et au-dessus de la barre
	var top := 70.0
	if _minimap != null and not _minimap.big:
		top = _minimap.position.y + _minimap.size.y + 6
	_joystick.position = Vector2(0, top)
	_joystick.size = Vector2(minf(170, vp.x * 0.35), _hotbar.position.y - top - 4)
	if _zone_label != null:
		_zone_label.position = Vector2(0, 26)
		_zone_label.size = Vector2(vp.x, 14)
	# Boutons Menu et Sac en haut à gauche, horloge et bourse en haut à droite
	_menu_button.position = Vector2(4, 4)
	_bag_button.position = Vector2(8 + _menu_button.get_combined_minimum_size().x, 4)
	_story_button.position = Vector2(_bag_button.position.x + _bag_button.get_combined_minimum_size().x + 4, 4)
	var clock := _top_panel.get_combined_minimum_size()
	_top_panel.size = Vector2(maxf(clock.x, 84), clock.y)
	_top_panel.position = Vector2(vp.x - _top_panel.size.x - 4, 4)
	var gold := _gold_panel.get_combined_minimum_size()
	_gold_panel.size = Vector2(_top_panel.size.x, gold.y)
	_gold_panel.position = Vector2(_top_panel.position.x, _top_panel.position.y + _top_panel.size.y + 2)

	if _tutorial_panel != null:
		var tw := minf(360, vp.x - 120)
		_tutorial_panel.size = Vector2(tw, 0)
		_tutorial_panel.reset_size()
		var tsize := _tutorial_panel.get_combined_minimum_size()
		_tutorial_panel.size = Vector2(tw, tsize.y)
		_tutorial_panel.position = Vector2((vp.x - _tutorial_panel.size.x) / 2.0, _hotbar.position.y - _tutorial_panel.size.y - 4)
	_toast.position = Vector2(0, 44)
	_toast.size = Vector2(vp.x, 16)
	if _modal != null:
		_modal.size = vp


# ------------------------------------------------------------ rafraîchissement
func _refresh_status() -> void:
	_date_label.text = "%s %d - %s" % [TimeManager.weekday(), TimeManager.day, TimeManager.SEASONS[TimeManager.season]]
	_time_label.text = TimeManager.time_string()
	_weather_icon.texture = _hud_icon({"rain": 1, "snow": 2}.get(TimeManager.weather, 0))
	_gold_label.text = "%d" % Inventory.gold
	if _gold_panel != null:
		_layout()


func _on_energy_changed(value: int, max_value: int) -> void:
	_energy_bar.max_value = max_value
	_energy_bar.value = value


func _refresh_hotbar() -> void:
	for i in _slots.size():
		var slot: Variant = Inventory.slots[i]
		_slots[i].add_theme_stylebox_override(
			"panel", _slot_selected_style if i == Inventory.selected else _slot_style
		)
		if slot == null:
			_slot_icons[i].texture = null
			_slot_labels[i].text = ""
		else:
			_slot_icons[i].texture = GameData.item_icon(slot.id)
			_slot_labels[i].text = str(slot.qty) if int(slot.qty) > 1 else ""
			# L'eau restante s'affiche sur l'arrosoir.
			if GameData.item(slot.id).get("tool") == "watering_can":
				_slot_labels[i].text = str(PlayerState.water)
	# Case choisie : petit « pop » et un son
	if Inventory.selected != _last_selected:
		if _last_selected != -1:
			Sfx.play("select")
			var pop := create_tween()
			_slots[Inventory.selected].scale = Vector2(1.18, 1.18)
			pop.tween_property(_slots[Inventory.selected], "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
		_last_selected = Inventory.selected
	var selected: Variant = Inventory.get_selected()
	_action_icon.texture = null if selected == null else GameData.item_icon(selected.id)


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


# ------------------------------------------------------------ entrées
func _input(event: InputEvent) -> void:
	if _modal == null:
		if event is InputEventScreenTouch and event.pressed:
			var point := ui_position(event)
			for i in _slots.size():
				if _slots[i].get_global_rect().has_point(point):
					Inventory.select(i)
					get_viewport().set_input_as_handled()
					return
		elif event is InputEventKey and event.pressed and not event.echo:
			var k: int = event.physical_keycode
			if k >= KEY_1 and k <= KEY_9:
				Inventory.select(k - KEY_1)
			elif k == KEY_0:
				Inventory.select(9)
			elif k == KEY_MINUS:
				Inventory.select(10)
			elif k == KEY_EQUAL:
				Inventory.select(11)
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				Inventory.select((Inventory.selected + 1) % Inventory.SIZE)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				Inventory.select((Inventory.selected + Inventory.SIZE - 1) % Inventory.SIZE)
	if _dialog_label != null and _modal != null and event.is_action_pressed("use_tool"):
		_advance_dialog()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu"):
		_toggle_menu()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # bouton retour Android
		_toggle_menu()


func _toggle_menu() -> void:
	if _modal != null:
		if _modal_closable:
			close_modal()
	else:
		open_pause_menu()


## Position d'un événement tactile dans les coordonnées de l'interface.
func ui_position(event: InputEvent) -> Vector2:
	return (_root.make_input_local(event) as InputEventScreenTouch).position


## Le toucher est-il sur un élément d'interface ?
func is_over_ui(event: InputEvent) -> bool:
	var point := ui_position(event)
	# Le toucher qui vient de fermer une fenêtre ne doit pas agir sur le monde.
	if _modal != null or Time.get_ticks_msec() - _modal_closed_at < 300:
		return true
	for c: Control in [_top_panel, _gold_panel, _menu_button, _bag_button, _story_button, _tutorial_panel, _hotbar, _joystick, _energy_bar, _health_bar, _minimap]:
		if c.get_global_rect().has_point(point):
			return true
	return Rect2(_action_button.position, Vector2(ACTION_SIZE, ACTION_SIZE)).has_point(point)


# ------------------------------------------------------------ fenêtres
func _open_modal(title: String, closable: bool = true) -> VBoxContainer:
	if _modal == null:
		Sfx.play("open")
	_closing_silently = true
	close_modal()
	_closing_silently = false
	_modal_closable = closable
	_joystick.release()
	_joystick.visible = false
	_action_button.visible = false
	get_tree().paused = true
	if DisplayServer.get_name() != "headless":
		Engine.max_fps = 20  # menu ouvert : on économise la batterie
	_modal = Control.new()
	_modal.size = get_viewport().get_visible_rect().size
	_root.add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 0)
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(24, 0)
	title_row.add_child(left_pad)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(heading)
	if closable:
		# Croix de fermeture, et toucher en dehors de la fenêtre pour la fermer
		var x := Button.new()
		x.text = "X"
		x.custom_minimum_size = Vector2(24, 22)
		x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		x.pressed.connect(close_modal)
		title_row.add_child(x)
		center.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and not panel.get_global_rect().has_point(event.global_position):
				close_modal())
	else:
		var right_pad := Control.new()
		right_pad.custom_minimum_size = Vector2(24, 0)
		title_row.add_child(right_pad)
	return box


func close_modal() -> void:
	if _modal == null:
		return
	if not _closing_silently:
		Sfx.play("close")
	if _dialog_tween != null:
		_dialog_tween.kill()
		_dialog_tween = null
	_modal.queue_free()
	_modal = null
	Settings.apply_quality()
	_dialog_label = null
	_modal_closed_at = Time.get_ticks_msec()
	_joystick.visible = true
	_action_button.visible = true
	get_tree().paused = false


func _add_button(box: Container, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 22)
	b.pressed.connect(func() -> void: Sfx.play("click"))
	b.pressed.connect(callback)
	box.add_child(b)
	return b


func _add_label(box: Container, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return l


func open_pause_menu() -> void:
	var outer := _open_modal("Pause")
	# Trois colonnes : tout tient sur l'écran d'un téléphone en paysage
	var box := _menu_grid(outer)
	_add_button(box, "Reprendre", close_modal)
	_add_button(box, "Sac", open_bag)
	_add_button(box, "Histoire", open_story)
	_add_button(box, "Fabrication", open_crafting.bind("craft"))
	_add_button(box, "Compétences", open_skills)
	_add_button(box, "Habitants", open_relations)
	_add_button(box, "Demandes", open_requests)
	_add_button(box, "Carnet de pêche", open_fish_log)
	_add_button(box, "Réglages", open_settings)
	_add_button(box, "Sauvegarder", func() -> void:
		SaveManager.save_game()
		show_toast("Partie sauvegardée"))
	_size_menu(box)
	if not OS.has_feature("web"):  # on ne « quitte » pas une page web
		_add_button(outer, "Sauvegarder et quitter", func() -> void:
			SaveManager.save_game()
			get_tree().quit())


func open_settings() -> void:
	var outer := _open_modal("Réglages")
	var box := _menu_grid(outer)
	_add_button(box, "Zoom : x%s" % str(Settings.zoom), func() -> void:
		Settings.cycle_zoom()
		open_settings())
	_add_button(box, "Vue : %s" % ("3D" if Settings.view_3d else "2D"), func() -> void:
		Settings.toggle_view()
		open_settings())
	_add_button(box, "Texte : %s" % Settings.TEXT_NAMES[Settings.text_size], func() -> void:
		Settings.cycle_text_size()
		open_settings())
	_add_button(box, "Qualité : %s" % Settings.QUALITY_NAMES[Settings.quality], func() -> void:
		Settings.cycle_quality()
		open_settings())
	_add_button(box, "Son : %s" % ("oui" if Settings.sound else "non"), func() -> void:
		Settings.toggle_sound()
		open_settings())
	_add_button(box, "Musique : %s" % ("oui" if Settings.music else "non"), func() -> void:
		Settings.toggle_music()
		open_settings())
	_add_button(box, "Revoir le tutoriel", func() -> void:
		Tutorial.restart()
		close_modal())
	_size_menu(box)
	_add_button(outer, "Retour", open_pause_menu)


func _menu_grid(outer: Container) -> GridContainer:
	var box := GridContainer.new()
	box.columns = 3
	box.add_theme_constant_override("h_separation", 6)
	box.add_theme_constant_override("v_separation", 6)
	outer.add_child(box)
	return box


func _size_menu(box: GridContainer) -> void:
	for b in box.get_children():
		b.custom_minimum_size = Vector2(124, 28)


func ask_sleep() -> void:
	var box := _open_modal("Aller dormir ?")
	_add_label(box, "La journée se terminera et ta récolte expédiée sera vendue.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_add_button(row, "Dormir", func() -> void:
		close_modal()
		GameFlow.end_day(false))
	_add_button(row, "Pas encore", close_modal)


func show_summary(report: Dictionary) -> void:
	var box := _open_modal("Fin de journée", false)
	Sfx.play("sleep")
	if report.get("passed_out", false):
		_add_label(box, "Tu t'es effondré·e de fatigue... Tu récupères moins d'énergie.")
	var sold: Array = report.get("sold", [])
	if sold.is_empty():
		_add_label(box, "Rien n'a été expédié.")
	for line: Dictionary in sold:
		_add_label(box, "%d x %s : %d or" % [line.qty, GameData.item_name(line.id), line.total])
	var total := _add_label(box, "Total : %d or" % int(report.get("earned", 0)))
	total.add_theme_color_override("font_color", UiTheme.ACCENT)
	_add_label(box, "Nouveau jour : %s (%s)" % [TimeManager.date_string(), TimeManager.weather_string()])
	_add_button(box, "Continuer", close_modal)


var _current_shop: String = "store"


## Boutique d'un habitant : objets, animaux (Léon) ou constructions (Mathis).
func open_shop(shop_id: String = "store") -> void:
	_current_shop = shop_id
	var shop := Shops.info(shop_id)
	var box := _open_modal(str(shop.get("name", "Boutique")))
	var owner := str(shop.get("owner", ""))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	box.add_child(header)
	if owner != "":
		var face := TextureRect.new()
		face.texture = GameData.npc_texture(owner)
		header.add_child(face)
	var gold := Label.new()
	gold.text = "Ton or : %d" % Inventory.gold
	header.add_child(gold)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 160)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_remember_scroll(scroll, "shop:" + shop_id)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if shop.get("animals", false):
		for type: String in Animals.data.get("animals", {}):
			list.add_child(_animal_row(type))
	elif shop.get("buildings", false):
		for id: String in Animals.data.get("buildings", {}):
			list.add_child(_building_row(id))
	else:
		for id: String in Shops.items(shop_id):
			list.add_child(_item_row(id))
	_add_button(box, "Fermer", close_modal)


func _shop_row(texture: Texture2D, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(18, 18)
	_fit_icon(icon)
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	return row


func _item_row(id: String) -> HBoxContainer:
	var item := GameData.item(id)
	var is_seed: bool = item.get("type") == "seed"
	var in_season := not is_seed or GameData.crop_in_season(str(item.crop), TimeManager.season)
	var is_bag: bool = item.get("type") == "backpack"
	var owned: bool = (item.get("type") == "tool" and Inventory.count_of(id) > 0) or (is_bag and Inventory.capacity >= int(item.capacity))
	# Le sac de voyageur demande d'avoir déjà le grand sac.
	var locked: bool = is_bag and Inventory.capacity < int(item.capacity) - Inventory.HOTBAR
	var price := Shops.price(_current_shop, id)
	var row := _shop_row(GameData.item_icon(id), "%s - %d or%s" % [item.name, price, "" if in_season else " (hors saison)"])
	var buy := Button.new()
	buy.text = "Acquis" if owned else "Acheter"
	buy.disabled = not in_season or owned or locked or Inventory.gold < price
	buy.pressed.connect(_buy.bind(id))
	row.add_child(buy)
	# Achat par 5 pour ce qui s'empile (graines, foin...)
	if int(item.get("stack", 99)) > 1 and not is_bag and item.get("type") != "tool":
		var five := Button.new()
		five.text = "x5"
		five.disabled = not in_season or Inventory.gold < price * 5
		five.pressed.connect(_buy.bind(id, 5))
		row.add_child(five)
	return row


## Grandes icônes (rendus 3D des animaux) : réduites à la taille d'une ligne.
func _fit_icon(icon: TextureRect) -> void:
	if icon.texture != null and icon.texture.get_width() > 16:
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)


func _animal_texture(type: String) -> Texture2D:
	var path := "res://assets/sprites/pets/%s.png" % type
	if ResourceLoader.exists(path):
		return load(path)
	var tex := AtlasTexture.new()
	tex.atlas = load("res://assets/sprites/animals.png")
	tex.region = Rect2(int(Animals.animal_info(type).get("frame", 0)) * 16, 0, 16, 16)
	return tex


func _animal_row(type: String) -> HBoxContainer:
	var info := Animals.animal_info(type)
	var building := str(info.building)
	var bname := str(Animals.building_info(building).get("name", building)).to_lower()
	var room := Animals.has_room(building)
	var note := "" if room else (" (il te faut un %s)" % bname if not Animals.is_built(building) else " (%s plein)" % bname)
	var row := _shop_row(_animal_texture(type), "%s - %d or%s" % [info.name, int(info.price), note])
	var buy := Button.new()
	buy.text = "Acheter"
	buy.disabled = not room or Inventory.gold < int(info.price)
	buy.pressed.connect(func() -> void:
		if Animals.buy(type):
			Sfx.play("coins")
			var a: Dictionary = Animals.animals[-1]
			show_toast("Bienvenue à %s, ta nouvelle %s !" % [a.name, str(info.name).to_lower()])
		open_shop(_current_shop))
	row.add_child(buy)
	return row


func _building_row(id: String) -> VBoxContainer:
	var info := Animals.building_info(id)
	var col := VBoxContainer.new()
	var row := _shop_row(GameData.item_icon("chest"), "%s - %d or : %s" % [info.name, int(info.price), info.get("description", "")])
	col.add_child(row)
	var needs := HBoxContainer.new()
	needs.add_theme_constant_override("separation", 6)
	var mats: Dictionary = info.get("materials", {})
	for item: String in mats:
		needs.add_child(_ingredient(item, int(mats[item])))
	col.add_child(needs)
	var build := Button.new()
	if Animals.is_built(id):
		build.text = "Déjà construit"
		build.disabled = true
	elif Animals.under_construction(id):
		build.text = "Chantier en cours"
		build.disabled = true
	else:
		build.text = "Construire (%d jours)" % int(info.get("days", 2))
		build.disabled = not Animals.construction_missing(id).is_empty()
	build.pressed.connect(func() -> void:
		if Animals.start_construction(id):
			Sfx.play("craft")
			show_toast("Mathis commence le chantier demain matin !")
		open_shop(_current_shop))
	needs.add_child(build)
	return col


func _buy(id: String, qty: int = 1) -> void:
	var item := GameData.item(id)
	var price := Shops.price(_current_shop, id)
	if item.get("type") == "backpack":
		var target := int(item.capacity)
		# Jamais de sac plus petit, et on agrandit un palier à la fois.
		if Inventory.capacity >= target or Inventory.capacity < target - Inventory.HOTBAR:
			return
		if Inventory.spend_gold(price):
			Sfx.play("coins")
			Inventory.set_capacity(int(item.capacity))
			show_toast("Ton sac a maintenant %d places !" % Inventory.capacity)
			open_shop(_current_shop)
		return
	if not Inventory.can_add(id, qty):
		show_toast("Inventaire plein !")
		return
	if Inventory.spend_gold(price * qty):
		Sfx.play("coins")
		Inventory.add_item(id, qty)
		show_toast("+%d %s" % [qty, GameData.item_name(id)])
		open_shop(_current_shop)  # reconstruit la liste (or et boutons à jour)


# ------------------------------------------------------------ élevage
func open_animals(building: String) -> void:
	var info := Animals.building_info(building)
	var box := _open_modal(str(info.get("name", building)))
	var b: Dictionary = Animals.buildings[building]
	var feeder := HBoxContainer.new()
	feeder.add_theme_constant_override("separation", 6)
	box.add_child(feeder)
	var hay := Label.new()
	hay.text = "Mangeoire : %d / %d foin" % [int(b.hay), Animals.FEEDER_MAX]
	hay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feeder.add_child(hay)
	var fill := Button.new()
	fill.text = "Remplir (%d dans ton sac)" % Inventory.count_of("hay")
	fill.disabled = Inventory.count_of("hay") == 0 or int(b.hay) >= Animals.FEEDER_MAX
	fill.pressed.connect(func() -> void:
		var n := Animals.fill_feeder(building)
		Sfx.play("drop")
		show_toast("+%d foin dans la mangeoire" % n)
		open_animals(building))
	feeder.add_child(fill)
	var indices := Animals.in_building(building)
	var ready := 0
	for i: int in indices:
		if Animals.animals[i].ready and str(Animals.animal_info(Animals.animals[i].type).get("tool", "")) == "":
			ready += 1
	if ready > 0:
		_add_button(box, "Ramasser les produits (%d)" % ready, func() -> void:
			var got := Animals.collect(building)
			Sfx.play("harvest")
			show_toast("Ramassé : %d produit(s)" % got.size())
			open_animals(building))
	if indices.is_empty():
		_add_label(box, "Aucun animal pour l'instant. Léon en vend au ranch, à l'est du village.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, minf(130, 34 * indices.size()))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i: int in indices:
		list.add_child(_animal_care_row(i, building))
	_add_label(box, "Chaque nuit, chaque animal mange 1 foin. Nourri, il produit au matin.")
	_add_button(box, "Fermer", close_modal)


func _animal_care_row(index: int, building: String) -> HBoxContainer:
	var a: Dictionary = Animals.animals[index]
	var info := Animals.animal_info(a.type)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = _animal_texture(a.type)
	_fit_icon(icon)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name := Label.new()
	name.text = "%s (%s)%s" % [a.name, str(info.name).to_lower(), "" if a.fed else (" - tout juste arrivé·e" if int(a.age) == 0 else " - affamé·e !")]
	col.add_child(name)
	var hearts := HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 0)
	for k in 5:
		var h := TextureRect.new()
		var tex := AtlasTexture.new()
		tex.atlas = _hearts_texture
		tex.region = Rect2(0 if k < Animals.hearts(index) else 8, 0, 8, 8)
		h.texture = tex
		hearts.add_child(h)
	col.add_child(hearts)
	var pet := Button.new()
	pet.text = "Caresser"
	pet.disabled = a.petted
	pet.pressed.connect(func() -> void:
		Animals.pet(index)
		Sfx.play("harvest")
		open_animals(building))
	row.add_child(pet)
	if Inventory.count_of("brush") > 0:
		var brush := Button.new()
		brush.text = "Brosser"
		brush.disabled = a.brushed
		brush.pressed.connect(func() -> void:
			Animals.brush(index)
			Sfx.play("swish")
			open_animals(building))
		row.add_child(brush)
	if str(info.get("tool", "")) != "":
		var milk := Button.new()
		milk.text = "Traire"
		milk.disabled = not a.ready or Inventory.count_of(str(info.tool)) == 0
		milk.pressed.connect(func() -> void:
			var got := Animals.milk(index)
			if got != "":
				Sfx.play("water")
				show_toast("+1 %s" % GameData.item_name(got))
			open_animals(building))
		row.add_child(milk)
	return row


# ------------------------------------------------------------ lieux : transitions et quartiers
## Grand titre du lieu, au centre de l'écran, qui s'efface tout seul.
func title_card(title: String, subtitle: String, tint: Color = Color(1, 0.95, 0.8)) -> void:
	if _title_box != null:
		_title_box.queue_free()
	_title_box = VBoxContainer.new()
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var vp := get_viewport().get_visible_rect().size
	_title_box.position = Vector2(0, vp.y * 0.28)
	_title_box.size = Vector2(vp.x, 50)
	_root.add_child(_title_box)
	var big := Label.new()
	big.text = title
	big.add_theme_font_size_override("font_size", 24)
	big.add_theme_color_override("font_color", tint)
	big.add_theme_constant_override("shadow_offset_x", 2)
	big.add_theme_constant_override("shadow_offset_y", 2)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(big)
	var small := Label.new()
	small.text = subtitle
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(small)
	_title_box.modulate.a = 0.0
	var tw := _title_box.create_tween()
	tw.tween_property(_title_box, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.4)
	tw.tween_property(_title_box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_title_box.queue_free)


func _on_zone_entered(name: String) -> void:
	if _zone_label == null:
		return
	_zone_label.text = name
	var tw := _zone_label.create_tween()
	_zone_label.modulate.a = 0.0
	tw.tween_property(_zone_label, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.2)
	tw.tween_property(_zone_label, "modulate:a", 0.0, 0.6)


var _world: WorldMap


func set_world(world: WorldMap) -> void:
	_world = world
	_minimap.setup(world)
	_layout()


# ------------------------------------------------------------ dialogues
func show_dialogue(npc_id: String, text: String) -> void:
	var data := GameData.npc(npc_id)
	_open_dialog(str(data.get("name", npc_id)), GameData.npc_texture(npc_id), text, Relations.hearts(npc_id))


func show_message(title: String, text: String) -> void:
	_open_dialog(title, null, text, -1)


func _open_dialog(title: String, portrait: Texture2D, text: String, hearts: int) -> void:
	close_modal()
	_modal_closable = true
	_joystick.release()
	_joystick.visible = false
	_action_button.visible = false
	get_tree().paused = true
	if DisplayServer.get_name() != "headless":
		Engine.max_fps = 20  # menu ouvert : on économise la batterie
	_modal = Control.new()
	_modal.size = get_viewport().get_visible_rect().size
	_modal.gui_input.connect(_on_dialog_input)
	_root.add_child(_modal)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_top = -86
	panel.offset_bottom = -6
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	if portrait != null:
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UiTheme.box("ui_slot_selected", 4, 4))
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(frame)
		var face := TextureRect.new()
		face.texture = portrait
		face.custom_minimum_size = Vector2(48, 48)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(header)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	header.add_child(name_label)
	if hearts >= 0:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(spacer)
		header.add_child(_hearts_row(hearts))
	_dialog_label = Label.new()
	_dialog_label.text = text
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog_label.visible_ratio = 0.0
	col.add_child(_dialog_label)
	_dialog_tween = create_tween()
	_dialog_tween.tween_property(_dialog_label, "visible_ratio", 1.0, clampf(text.length() * 0.02, 0.3, 2.5))


func _on_dialog_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _modal != null:
			_modal.accept_event()
		_advance_dialog()


## Premier toucher : affiche tout le texte. Second : ferme.
func _advance_dialog() -> void:
	if _dialog_label == null:
		return
	if _dialog_label.visible_ratio < 1.0:
		_dialog_label.visible_ratio = 1.0
	else:
		close_modal()


func _hearts_row(count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Relations.MAX_HEARTS:
		var heart := TextureRect.new()
		var tex := AtlasTexture.new()
		tex.atlas = _hearts_texture
		tex.region = Rect2(0 if i < count else 8, 0, 8, 8)
		heart.texture = tex
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(heart)
	return row


func open_relations() -> void:
	var box := _open_modal("Habitants de Valfleur")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for id: String in GameData.npcs:
		var data := GameData.npc(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		list.add_child(row)
		var face := TextureRect.new()
		face.texture = GameData.npc_texture(id)
		face.custom_minimum_size = Vector2(16, 16)
		row.add_child(face)
		var known := Relations.met.has(id)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var label := Label.new()
		label.text = "%s, %s" % [data.name, data.get("title", "")] if known else "???"
		col.add_child(label)
		if known:
			var extra := Label.new()
			var scenes: Array = HeartEvents.events.get(id, [])
			extra.text = "Anniversaire : %s  -  Souvenirs : %d/%d" % [HeartEvents.birthday_text(id), HeartEvents.count_seen(id), scenes.size()]
			if HeartEvents.is_birthday(id):
				extra.text = "C'est son anniversaire aujourd'hui !"
			extra.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
			extra.add_theme_font_size_override("font_size", maxi(8, Settings.font_size() - 2))
			col.add_child(extra)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		info.add_child(_hearts_row(Relations.hearts(id)))
		var status := Label.new()
		status.text = "Cadeau offert" if Relations.gifted_today.has(id) else ("Déjà vu aujourd'hui" if Relations.talked_today.has(id) else "")
		status.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		info.add_child(status)
	_add_button(box, "Retour", open_pause_menu)


# ------------------------------------------------------------ scènes
## Petite scène : une suite de répliques (portrait, nom, texte), puis
## éventuellement un choix. lines : [[id de l'habitant ou "", texte], ...]
func play_scene(title: String, lines: Array, choice: Dictionary = {}, on_choice: Callable = Callable(), on_done: Callable = Callable()) -> void:
	_scene_step(title, lines, 0, choice, on_choice, on_done)


func _scene_step(title: String, lines: Array, index: int, choice: Dictionary, on_choice: Callable, on_done: Callable) -> void:
	if index >= lines.size():
		if choice.is_empty():
			close_modal()
			if on_done.is_valid():
				on_done.call()
			return
		var box := _open_modal(title, false)
		_add_label(box, str(choice.get("prompt", "Ta réponse :")))
		var options: Array = choice.get("options", [])
		for k in options.size():
			var opt: Array = options[k]
			_add_button(box, str(opt[0]), func() -> void:
				var reply := str(on_choice.call(k)) if on_choice.is_valid() else ""
				if reply != "":
					var speaker: String = str(lines[lines.size() - 1][0])
					_scene_step(title, [[speaker, reply]], 0, {}, Callable(), on_done)
				else:
					close_modal()
					if on_done.is_valid():
						on_done.call())
		return
	var entry: Array = lines[index]
	var who := str(entry[0])
	var box := _open_modal(title, false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	if who != "":
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UiTheme.box("ui_slot_selected", 4, 4))
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(frame)
		var face := TextureRect.new()
		face.texture = GameData.npc_texture(who)
		face.custom_minimum_size = Vector2(40, 40)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.add_child(face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(280, 0)
	row.add_child(col)
	if who != "":
		var name_label := Label.new()
		name_label.text = str(GameData.npc(who).get("name", who))
		name_label.add_theme_color_override("font_color", UiTheme.ACCENT)
		col.add_child(name_label)
	var text := _add_label(col, str(entry[1]))
	if who == "":
		text.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))  # narration
	text.visible_ratio = 0.0
	create_tween().tween_property(text, "visible_ratio", 1.0, clampf(str(entry[1]).length() * 0.015, 0.2, 1.8))
	_add_button(box, "Suivant  >" if index < lines.size() - 1 or not choice.is_empty() else "Fermer", func() -> void:
		if text.visible_ratio < 1.0:
			text.visible_ratio = 1.0
		else:
			Sfx.play("page")
			_scene_step(title, lines, index + 1, choice, on_choice, on_done))


func _on_heart_scene(npc_id: String, scene: Dictionary) -> void:
	var lines: Array = []
	var raw: Array = scene.get("lines", [])
	for k in raw.size():
		# La première ligne décrit la scène ; les suivantes sont des répliques
		lines.append(["" if k == 0 else npc_id, str(raw[k])])
	title_card("Souvenir", str(scene.get("title", "")), Color(1, 0.7, 0.8))
	Sfx.play("levelup")
	play_scene(str(scene.get("title", "")), lines, scene.get("choice", {}), func(option: int) -> String:
		return HeartEvents.choose(npc_id, scene, option))


# ------------------------------------------------------------ tableau des demandes
func open_board() -> void:
	var box := _open_modal("Tableau des demandes")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	var offers := Quests.offers()
	for i in offers.size():
		var q: Dictionary = offers[i]
		var row := _quest_row(q, false)
		var accept := Button.new()
		accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		accept.text = "Prise" if Quests.taken_today.has(i) else "Accepter"
		accept.disabled = not Quests.can_accept(i)
		accept.pressed.connect(func() -> void:
			if Quests.accept(i):
				Sfx.play("page")
				show_toast("Demande acceptée : apporte-la à %s." % GameData.npc(str(q.npc)).name)
				open_board())
		row.add_child(accept)
		list.add_child(row)
	_requests_section(list)
	var cal := _add_label(list, Events.calendar_text())
	cal.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	var bday := HeartEvents.birthday_today()
	if bday != "":
		_add_label(list, "Aujourd'hui, c'est l'anniversaire de %s !" % GameData.npc(bday).name)
	_add_button(box, "Fermer", close_modal)


## Demandes en cours (aussi dans le menu).
func open_requests() -> void:
	var box := _open_modal("Mes demandes")
	_requests_section(box)
	if Quests.active.is_empty():
		_add_label(box, "Aucune demande en cours. Le tableau des demandes est sur la place du village, près de la mairie.")
	_add_button(box, "Retour", open_pause_menu)


func _requests_section(list: Container) -> void:
	if Quests.active.is_empty():
		return
	var header := _add_label(list, "En cours (%d/%d) - parle à l'habitant pour livrer :" % [Quests.active.size(), Quests.MAX_ACTIVE])
	header.add_theme_color_override("font_color", UiTheme.ACCENT)
	for q: Dictionary in Quests.active:
		list.add_child(_quest_row(q, true))


func _quest_row(q: Dictionary, progress: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var face := TextureRect.new()
	face.texture = GameData.npc_texture(str(q.npc))
	face.custom_minimum_size = Vector2(16, 16)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	var icon := TextureRect.new()
	icon.texture = GameData.item_icon(str(q.item))
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = "%s : « %s »" % [GameData.npc(str(q.npc)).name, q.text]
	col.add_child(text)
	var reward := Label.new()
	var have := Inventory.count_of(str(q.item))
	reward.text = "Récompense : %d or et de l'amitié" % int(q.gold)
	if progress:
		reward.text = "%d/%d  -  %d or  -  encore %d jour(s)" % [mini(have, int(q.qty)), int(q.qty), int(q.gold), int(q.days_left)]
		reward.add_theme_color_override("font_color", INGREDIENT_OK if have >= int(q.qty) else Color(0.85, 0.8, 0.7))
	else:
		reward.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	col.add_child(reward)
	return row


## Fondu au noir qui s'efface (changement de carte).
func fade_in() -> void:
	_fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.4)


# ------------------------------------------------------------ pêche
func start_fishing(fish_id: String, on_done: Callable) -> void:
	var box := _open_modal("Ça mord !", false)
	var hint := _add_label(box, "Garde le poisson dans le filet : appuie pour aller à droite, relâche pour revenir.")
	hint.custom_minimum_size = Vector2(260, 0)
	var data := GameData.fish(fish_id)
	var game := FishingMinigame.new()
	game.difficulty = float(data.get("difficulty", 30)) / 100.0
	game.behavior = str(data.get("behavior", "calm"))
	game.fish_texture = GameData.item_icon(fish_id)
	game.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(game)
	game.finished.connect(func(success: bool) -> void:
		close_modal()
		on_done.call(success))


func open_fish_log() -> void:
	var box := _open_modal("Carnet de pêche")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	box.add_child(grid)
	for id: String in GameData.fishes:
		var row := HBoxContainer.new()
		grid.add_child(row)
		var icon := TextureRect.new()
		icon.texture = GameData.item_icon(id)
		var entry: Variant = FishLog.caught.get(id)
		if entry == null:
			icon.modulate = Color(0, 0, 0, 0.6)  # silhouette : pas encore attrapé
		row.add_child(icon)
		var label := Label.new()
		if entry == null:
			label.text = "???"
		else:
			label.text = "%s\nx%d - record %d cm" % [GameData.fish(id).name, entry.count, entry.best]
		row.add_child(label)
	_add_label(box, "Espèces : %d / %d" % [FishLog.caught.size(), GameData.fishes.size()])
	_add_button(box, "Retour", open_pause_menu)


# ------------------------------------------------------------ mine
func set_location(text: String) -> void:
	_location_label.text = text
	_location_label.visible = text != ""


func ask_eat(item_id: String) -> void:
	var item := GameData.item(item_id)
	var values: Array = item.get("edible", [0, 0])
	var box := _open_modal("Manger ?")
	_add_label(box, "%s : +%d énergie, +%d vie." % [item.name, int(values[0]), int(values[1])])
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_add_button(row, "Manger", func() -> void:
		var slot: Variant = Inventory.get_selected()
		if slot != null and slot.id == item_id:
			Inventory.remove_from_slot(Inventory.selected, 1)
			PlayerState.heal(int(values[0]), int(values[1]))
			Sfx.play("eat")
		close_modal())
	_add_button(row, "Non", close_modal)


func open_elevator(levels: Array) -> void:
	var box := _open_modal("Ascenseur de la mine")
	var here := (_world as MineLevel).level if _world is MineLevel else 0
	_add_label(box, "Un nouvel arrêt tous les 5 étages atteints. Où aller ?")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for level: int in levels:
		var b := _add_button(grid, "Niveau %d" % level, func() -> void:
			close_modal()
			Sfx.play("door")
			EventBus.map_change_requested.emit("mine:%d" % level, Vector2i.ZERO))
		b.custom_minimum_size = Vector2(70, 26)
		b.disabled = level == here
	if here > 0:
		_add_button(box, "Remonter au village", func() -> void:
			close_modal()
			Sfx.play("door")
			EventBus.map_change_requested.emit("village", MineLevel.VILLAGE_EXIT))
	_add_button(box, "Annuler", close_modal)


# ------------------------------------------------------------ fabrication
const INGREDIENT_OK := Color(0.6, 0.95, 0.45)
const INGREDIENT_MISSING := Color(1.0, 0.32, 0.28)


## station : "craft" (Menu → Fabrication) ou "forge" (enclume de Gaston).
func open_crafting(station: String) -> void:
	var title := "Forge de Gaston" if station == "forge" else "Fabrication"
	var box := _open_modal(title)
	if station == "forge":
		_add_label(box, "Gaston améliore tes outils contre du minerai et un peu d'or.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_remember_scroll(scroll, station)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	var category := ""
	for id: String in Crafting.for_station(station):
		var recipe: Dictionary = Crafting.recipes[id]
		var cat := str(recipe.get("category", ""))
		if cat != "" and cat != category:
			category = cat
			var header := Label.new()
			header.text = cat
			header.add_theme_color_override("font_color", UiTheme.ACCENT)
			list.add_child(header)
		list.add_child(_recipe_row(id, recipe, station))
	_add_label(box, "Ton or : %d" % Inventory.gold)
	_add_button(box, "Retour" if station == "craft" else "Fermer", open_pause_menu if station == "craft" else close_modal)


func _recipe_row(id: String, recipe: Dictionary, station: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.texture = GameData.item_icon(id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(18, 18)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name_label := Label.new()
	var count := int(recipe.get("count", 1))
	name_label.text = GameData.item_name(id) + (" x%d" % count if count > 1 else "")
	col.add_child(name_label)
	var needs := HBoxContainer.new()
	needs.add_theme_constant_override("separation", 6)
	col.add_child(needs)
	var ingredients: Dictionary = recipe.get("ingredients", {})
	if recipe.has("upgrade"):
		needs.add_child(_ingredient(str(recipe.upgrade), 1))
	for item: String in ingredients:
		needs.add_child(_ingredient(item, int(ingredients[item])))
	if int(recipe.get("gold", 0)) > 0:
		var gold := Label.new()
		gold.text = "%d or" % int(recipe.gold)
		gold.add_theme_color_override("font_color", INGREDIENT_OK if Inventory.gold >= int(recipe.gold) else INGREDIENT_MISSING)
		needs.add_child(gold)
	var button := Button.new()
	button.text = "Améliorer" if recipe.has("upgrade") else ("Cuisiner" if recipe.get("category") == "Cuisine" else "Fabriquer")
	button.disabled = not Crafting.can_craft(id)
	if not Crafting.is_unlocked(id):
		# Recette encore secrète : on dit quel chapitre de l'histoire la débloque
		icon.modulate = Color(0, 0, 0, 0.55)
		name_label.text = "???"
		for child in needs.get_children():
			child.queue_free()
		var hint := Label.new()
		hint.text = "Débloquée par l'histoire : " + Story.chapter_title(str(recipe.unlock))
		hint.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		needs.add_child(hint)
		button.text = "Verrouillée"
	button.pressed.connect(func() -> void:
		if Crafting.craft(id):
			Sfx.play("craft")
			show_toast("%s : c'est prêt !" % GameData.item_name(id))
		open_crafting(station))
	row.add_child(button)
	return row


func _ingredient(item: String, qty: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var icon := TextureRect.new()
	icon.texture = GameData.item_icon(item)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(10, 10)
	box.add_child(icon)
	var label := Label.new()
	label.text = "%d/%d" % [mini(Inventory.count_of(item), 99), qty]
	label.add_theme_color_override("font_color", INGREDIENT_OK if Inventory.count_of(item) >= qty else INGREDIENT_MISSING)
	box.add_child(label)
	return box


# ------------------------------------------------------------ sac et coffres
const GRID_SLOT := 19


## Grille de cases cliquables pour un tableau de cases (sac ou coffre).
func _slot_grid(arr: Array, from: int, to: int, on_tap: Callable, picked: int = -1) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = Inventory.HOTBAR
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	for i in range(from, to):
		var button := Button.new()
		button.custom_minimum_size = Vector2(GRID_SLOT, GRID_SLOT)
		var style := _slot_selected_style if i == picked else _slot_style
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		var slot: Variant = arr[i]
		if slot != null:
			var icon := TextureRect.new()
			icon.texture = GameData.item_icon(slot.id)
			icon.position = Vector2(2, 1)
			icon.size = Vector2(16, 16)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(icon)
			if int(slot.qty) > 1:
				var qty := Label.new()
				qty.text = str(slot.qty)
				qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				qty.position = Vector2(0, 9)
				qty.size = Vector2(GRID_SLOT - 1, 10)
				qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
				button.add_child(qty)
		button.pressed.connect(on_tap.bind(i))
		grid.add_child(button)
	return grid


func open_bag() -> void:
	var box := _open_modal("Sac - %d places" % Inventory.capacity)
	box.add_child(_section_label("Barre rapide"))
	box.add_child(_slot_grid(Inventory.slots, 0, Inventory.HOTBAR, _on_bag_slot, _picked))
	if Inventory.capacity > Inventory.HOTBAR:
		box.add_child(_section_label("Sac"))
		box.add_child(_slot_grid(Inventory.slots, Inventory.HOTBAR, Inventory.capacity, _on_bag_slot, _picked))
	else:
		_add_label(box, "Un sac plus grand s'achète à l'épicerie de Rosalie.")
	var info := _add_label(box, "Touche un objet, puis la case où le ranger.")
	info.custom_minimum_size = Vector2(240, 0)
	if _picked >= 0 and Inventory.slots[_picked] != null:
		var item := GameData.item(Inventory.slots[_picked].id)
		var text := str(item.get("name", ""))
		if item.has("description"):
			text += " : " + str(item.description)
		if int(item.get("sell", 0)) > 0:
			text += " (vente : %d or)" % int(item.sell)
		info.text = text
	_add_button(box, "Fermer", func() -> void:
		_picked = -1
		close_modal())


func _on_bag_slot(index: int) -> void:
	if _picked < 0:
		if Inventory.slots[index] != null:
			_picked = index
	elif _picked == index:
		_picked = -1
	else:
		Inventory.swap(_picked, index)
		_picked = -1
	open_bag()


func open_chest(cell: Vector2i) -> void:
	var chest: Array = FarmState.chests.get(cell, [])
	if chest.is_empty():
		return
	var box := _open_modal("Coffre")
	box.add_child(_section_label("Coffre (touche un objet pour le prendre)"))
	box.add_child(_slot_grid(chest, 0, chest.size(), func(i: int) -> void:
		Sfx.play("drop", -6.0)
		Inventory.transfer(chest, i, Inventory.slots)
		EventBus.inventory_changed.emit()
		open_chest(cell)))
	box.add_child(_section_label("Ton sac (touche un objet pour le ranger)"))
	box.add_child(_slot_grid(Inventory.slots, 0, Inventory.capacity, func(i: int) -> void:
		Sfx.play("drop", -6.0)
		Inventory.transfer(Inventory.slots, i, chest)
		EventBus.inventory_changed.emit()
		open_chest(cell)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_add_button(row, "Ranger les piles", func() -> void:
		_stack_into(chest)
		open_chest(cell))
	_add_button(row, "Fermer", close_modal)


## Range dans le coffre tout ce qui y a déjà une pile (hors barre rapide).
func _stack_into(chest: Array) -> void:
	var present := {}
	for slot: Variant in chest:
		if slot != null:
			present[slot.id] = true
	for i in range(Inventory.HOTBAR, Inventory.capacity):
		var slot: Variant = Inventory.slots[i]
		if slot != null and present.has(slot.id):
			Inventory.transfer(Inventory.slots, i, chest)
	EventBus.inventory_changed.emit()


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiTheme.ACCENT)
	return label


## Garde la position de défilement d'une liste entre deux reconstructions
## (après un achat ou une fabrication, la liste ne remonte pas en haut).
func _remember_scroll(scroll: ScrollContainer, key: String) -> void:
	scroll.set_deferred("scroll_vertical", int(_scroll_memory.get(key, 0)))
	scroll.get_v_scroll_bar().value_changed.connect(func(v: float) -> void: _scroll_memory[key] = int(v))


# ------------------------------------------------------------ courrier et compétences
func open_mail() -> void:
	var letter := Mail.open_next()
	if letter.is_empty():
		close_modal()
		return
	var box := _open_modal("Une lettre !")
	var paper := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.95, 0.84)
	style.border_color = Color(0.72, 0.55, 0.36)
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(8)
	paper.add_theme_stylebox_override("panel", style)
	box.add_child(paper)
	var col := VBoxContainer.new()
	paper.add_child(col)
	var text := Label.new()
	text.text = str(letter.get("text", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(260, 0)
	text.add_theme_color_override("font_color", Color(0.25, 0.15, 0.19))
	text.add_theme_constant_override("shadow_offset_x", 0)
	text.add_theme_constant_override("shadow_offset_y", 0)
	col.add_child(text)
	var sign := Label.new()
	sign.text = "- " + str(letter.get("from", ""))
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sign.add_theme_color_override("font_color", Color(0.55, 0.3, 0.2))
	sign.add_theme_constant_override("shadow_offset_x", 0)
	sign.add_theme_constant_override("shadow_offset_y", 0)
	col.add_child(sign)
	var items: Array = letter.get("items", [])
	if not items.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(row)
		var label := Label.new()
		label.text = "Joint : "
		row.add_child(label)
		for entry: Array in items:
			var icon := TextureRect.new()
			icon.texture = _hud_icon(3) if entry[0] == "gold" else GameData.item_icon(str(entry[0]))
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			row.add_child(icon)
			var qty := Label.new()
			qty.text = ("%d or" % int(entry[1])) if entry[0] == "gold" else ("%s x%d" % [GameData.item_name(str(entry[0])), int(entry[1])])
			row.add_child(qty)
	if Mail.has_mail():
		_add_button(box, "Lettre suivante", func() -> void:
			Sfx.play("page")
			open_mail())
	else:
		_add_button(box, "Fermer", close_modal)


# ------------------------------------------------------------ tutoriel
func _build_tutorial() -> void:
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.add_theme_stylebox_override("panel", UiTheme.box("ui_panel", 5, 5))
	_tutorial_panel.modulate.a = 0.95
	_root.add_child(_tutorial_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_tutorial_panel.add_child(row)
	_tutorial_label = Label.new()
	_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_label.custom_minimum_size = Vector2(220, 0)
	row.add_child(_tutorial_label)
	var skip := Button.new()
	skip.text = "Passer"
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(Tutorial.skip)
	row.add_child(skip)
	Tutorial.changed.connect(_refresh_tutorial)
	_refresh_tutorial()


var _hint_timer: float = 0.0
var _wedding_playing: bool = false


func _play_wedding() -> void:
	_wedding_playing = true
	title_card("Le mariage", "Sur la place de Valfleur", Color(1, 0.75, 0.85))
	Sfx.play("levelup")
	play_scene("Le mariage", Marriage.wedding_lines(), {}, Callable(), func() -> void:
		Marriage.wedding_pending = false
		_wedding_playing = false
		show_toast("%s vit maintenant avec toi à la ferme." % GameData.npc(Marriage.spouse).name))


func _process(_delta: float) -> void:
	# Le matin du mariage : la scène, dès qu'aucune fenêtre n'est ouverte
	if Marriage.wedding_pending and _modal == null and not _wedding_playing:
		_play_wedding()
	# Le bandeau du tutoriel s'efface derrière les fenêtres et dialogues
	if _tutorial_panel != null:
		_tutorial_panel.visible = Tutorial.active() and _modal == null
	# Étiquette du bouton Action (10 fois par seconde)
	_hint_timer -= _delta
	if _hint_panel != null and _hint_timer <= 0.0:
		_hint_timer = 0.1
		var text := ""
		if _modal == null and _world != null and is_instance_valid(_world):
			text = _world.action_hint(_world.get("_target_cell"))
		_hint_panel.visible = text != ""
		if text != _hint_label.text:
			_hint_label.text = text
			_hint_panel.reset_size()
		var ps := _hint_panel.get_combined_minimum_size()
		var vp := get_viewport().get_visible_rect().size
		# À gauche du bouton Action, à mi-hauteur : ne cache pas les jauges
		_hint_panel.position = Vector2(_action_button.position.x - ps.x - 4, _action_button.position.y + (ACTION_SIZE - ps.y) / 2.0)


func _refresh_tutorial() -> void:
	_tutorial_panel.visible = Tutorial.active()
	if not Tutorial.active():
		return
	_tutorial_label.text = "%d/%d  %s" % [Tutorial.step + 1, Tutorial.STEPS.size(), Tutorial.text()]
	_tutorial_label.add_theme_font_size_override("font_size", maxi(9, Settings.font_size() - 1))
	# Petite animation pour attirer l'œil sur la nouvelle consigne
	_tutorial_panel.scale = Vector2(1.06, 1.06)
	_tutorial_panel.pivot_offset = _tutorial_panel.size / 2.0
	create_tween().tween_property(_tutorial_panel, "scale", Vector2.ONE, 0.25)
	_layout.call_deferred()


## Au réveil : ce que la nature a repris pendant la nuit.
func _nature_report() -> void:
	var n: Dictionary = FarmState.last_night
	var parts: Array = []
	if int(n.get("withered", 0)) > 0:
		parts.append("%d culture(s) fanée(s) faute d'arrosage" % int(n.withered))
	if int(n.get("weeds", 0)) > 0:
		parts.append("%d sillon(s) abandonné(s) envahi(s) d'herbes" % int(n.weeds))
	if int(n.get("spread", 0)) > 2:
		parts.append("les mauvaises herbes gagnent du terrain")
	if parts.is_empty():
		return
	await get_tree().create_timer(2.5).timeout
	show_toast("La nature reprend ses droits : " + ", ".join(parts) + ".")


# ------------------------------------------------------------ fêtes du village
func open_booth() -> void:
	var activity := Events.booth_activity()
	var fest := Events.festival_today()
	var title := str(fest.get("name", "Marché du samedi"))
	if not Events.booth_open():
		var hours: Dictionary = fest if not fest.is_empty() else Events.weekly_today()
		show_message(title, "Le stand n'est pas encore ouvert (de %dh à %dh)." % [int(hours.get("start", 9)), int(hours.get("end", 14))])
		return
	if activity == "market":
		open_shop("market")
		return
	var box := _open_modal(title)
	_add_label(box, str(fest.get("desc", "")))
	if Events.is_done(str(fest.id)):
		_add_label(box, "Tu as déjà participé cette année. Profite de la fête !")
	elif activity == "contest":
		var slot: Variant = Inventory.get_selected()
		var item := {} if slot == null else GameData.item(slot.id)
		if slot == null or int(item.get("sell", 0)) <= 0 or item.get("type") in ["tool", "weapon", "seed"]:
			_add_label(box, "Choisis dans ta barre l'objet à présenter (légume, poisson, produit d'élevage, plat...), puis reviens au stand.")
		else:
			var id := str(slot.id)
			_add_button(box, "Présenter : %s" % GameData.item_name(id), func() -> void:
				var result := Events.enter_contest(id)
				if result.is_empty():
					return
				Sfx.play("levelup")
				show_message(str(result.title), "Le jury goûte, soupèse, admire... %s ! Tu gagnes %d or, et tout le village t'applaudit." % [result.title, int(result.gold)]))
	elif activity == "dance":
		_add_label(box, "Qui veux-tu inviter à danser ?")
		var row := HFlowContainer.new()
		box.add_child(row)
		for id: String in GameData.npcs:
			if not Relations.met.has(id):
				continue
			var b := Button.new()
			b.text = str(GameData.npc(id).name)
			b.pressed.connect(func() -> void:
				Events.dance_with(id)
				Sfx.play("levelup")
				show_message("Nuit des lanternes", "Tu danses avec %s autour de la fontaine, sous les lanternes. Un moment inoubliable !" % GameData.npc(id).name))
			row.add_child(b)
		if row.get_child_count() == 0:
			_add_label(box, "Tu ne connais encore personne... Va saluer les habitants !")
	_add_button(box, "Fermer", close_modal)


# ------------------------------------------------------------ histoire
func open_story() -> void:
	Tutorial.notify("story")
	var box := _open_modal("Histoire de Valfleur")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 165)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	var lead := _add_label(list, Story.prologue if Story.chapter == 0 else "")
	lead.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	lead.visible = Story.chapter == 0
	# Échelle de progression : les 5 chapitres
	var ladder := HBoxContainer.new()
	ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	ladder.add_theme_constant_override("separation", 3)
	list.add_child(ladder)
	for i in Story.chapters.size():
		var step := Label.new()
		step.text = " %d " % (i + 1)
		var done := i < Story.chapter
		var now := i == Story.chapter
		step.add_theme_color_override("font_color", UiTheme.ACCENT if done else (Color.WHITE if now else Color(0.5, 0.45, 0.4)))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.55, 0.3) if done else (Color(0.55, 0.38, 0.22) if now else Color(0.25, 0.18, 0.12))
		style.set_corner_radius_all(3)
		step.add_theme_stylebox_override("normal", style)
		ladder.add_child(step)
		if i < Story.chapters.size() - 1:
			var link := Label.new()
			link.text = "-"
			ladder.add_child(link)
	if Story.finished():
		var end := _add_label(list, "Valfleur a retrouvé sa source et sa fête. Merci !")
		end.add_theme_color_override("font_color", UiTheme.ACCENT)
	else:
		var c: Dictionary = Story.current()
		var title := _add_label(list, "Chapitre %d : %s" % [Story.chapter + 1, c.title])
		title.add_theme_color_override("font_color", UiTheme.ACCENT)
		_add_label(list, str(c.intro))
		var hint := _add_label(list, "Une seule de ces voies suffit :")
		hint.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		for path: Dictionary in c.paths:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			list.add_child(row)
			var label := Label.new()
			label.text = str(path.label)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(label)
			var value := mini(Story.value(str(path.stat)), int(path.goal))
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(60, 9)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.value = 100.0 * value / float(path.goal)
			row.add_child(bar)
			var count := Label.new()
			count.text = "%d/%d" % [value, int(path.goal)]
			count.custom_minimum_size = Vector2(44, 0)
			row.add_child(count)
		var reward := _add_label(list, "Récompense : " + str(c.get("unlock_text", "")))
		reward.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	# Le chapitre du port
	var port_title := _add_label(list, "Au port : %s" % PortStory.data.get("title", ""))
	port_title.add_theme_color_override("font_color", UiTheme.ACCENT)
	if PortStory.finished():
		_add_label(list, "Terminé ! Le phare brille de nouveau chaque nuit.")
	else:
		if PortStory.step == 0:
			_add_label(list, str(PortStory.data.get("intro", "")))
		_add_label(list, "Étape %d/%d : %s" % [PortStory.step + 1, PortStory.steps().size(), PortStory.current().get("text", "")])
		var prog := PortStory.progress_text()
		if prog != "":
			var pl := _add_label(list, prog)
			pl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	for i in Story.chapter:
		var past := _add_label(list, "Terminé : %d. %s" % [i + 1, Story.chapters[i].title])
		past.add_theme_color_override("font_color", Color(0.6, 0.75, 0.6))
	_add_button(box, "Fermer", close_modal)


func _on_story_advanced(chapter_id: String, path_label: String) -> void:
	var done: Dictionary = {}
	for c: Dictionary in Story.chapters:
		if str(c.id) == chapter_id:
			done = c
	if chapter_id == "port":
		done = {"title": "Le phare du Héron", "unlock_text": "Soupe du marin ; le phare brille chaque nuit"}
	title_card("Chapitre terminé !", str(done.get("title", "")), UiTheme.ACCENT)
	show_toast("%s - nouvelle lettre dans ta boîte !" % path_label)
	if done.has("unlock_text"):
		await get_tree().create_timer(3.0).timeout
		show_toast("Débloqué : " + str(done.unlock_text))


func open_skills() -> void:
	var box := _open_modal("Compétences")
	for skill: String in Skills.NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var name_label := Label.new()
		name_label.text = "%s  niv. %d" % [Skills.NAMES[skill], Skills.level(skill)]
		name_label.custom_minimum_size = Vector2(110, 0)
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(70, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.value = Skills.progress(skill) * 100.0
		row.add_child(bar)
		var perk := Label.new()
		perk.text = Skills.PERKS[skill]
		perk.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		row.add_child(perk)
	_add_button(box, "Retour", open_pause_menu)
