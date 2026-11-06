class_name Hud
extends CanvasLayer
## Interface en jeu, pensée pour le tactile : date/heure/or, énergie,
## barre rapide, joystick, bouton Action, menus (boutique, sommeil, pause).
## Les fenêtres mettent le jeu en pause (le temps s'arrête).

const SLOT_SIZE := 22
const ACTION_SCALE := 3.0
const ACTION_SIZE := 16.0 * ACTION_SCALE
const ACTION_MARGIN := Vector2(12, 36)

var _root: Control
var _date_label: Label
var _time_label: Label
var _gold_label: Label
var _water_label: Label
var _energy_bar: ProgressBar
var _top_panel: PanelContainer
var _menu_button: Button
var _hotbar: PanelContainer
var _slots: Array[Panel] = []
var _slot_icons: Array[TextureRect] = []
var _slot_labels: Array[Label] = []
var _joystick: VirtualJoystick
var _action_button: TouchScreenButton
var _action_icon: Sprite2D
var _toast: Label
var _toast_tween: Tween
var _modal: Control
var _modal_closable: bool = true
var _slot_style: StyleBoxTexture
var _slot_selected_style: StyleBoxTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiTheme.build()
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

	EventBus.inventory_changed.connect(_refresh_hotbar)
	EventBus.gold_changed.connect(func(_g: int) -> void: _refresh_status())
	EventBus.energy_changed.connect(_on_energy_changed)
	EventBus.water_changed.connect(func(_v: int, _m: int) -> void: _refresh_status())
	EventBus.toast_requested.connect(show_toast)
	EventBus.shop_requested.connect(open_shop)
	EventBus.sleep_requested.connect(ask_sleep)
	EventBus.day_summary.connect(show_summary)
	TimeManager.time_changed.connect(func(_h: int, _m: int) -> void: _refresh_status())
	TimeManager.day_started.connect(func(_d: int, _s: int, _y: int) -> void: _refresh_status())
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_hotbar()
	_refresh_status()
	_on_energy_changed(PlayerState.energy, PlayerState.MAX_ENERGY)


# ------------------------------------------------------------ construction
func _build_top_panel() -> void:
	_top_panel = PanelContainer.new()
	_top_panel.position = Vector2(4, 4)
	_root.add_child(_top_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_top_panel.add_child(box)
	_date_label = Label.new()
	_time_label = Label.new()
	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	_water_label = Label.new()
	_water_label.add_theme_font_size_override("font_size", 8)
	for l in [_date_label, _time_label, _gold_label, _water_label]:
		box.add_child(l)


func _build_energy_bar() -> void:
	_energy_bar = ProgressBar.new()
	_energy_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_energy_bar.show_percentage = false
	_energy_bar.custom_minimum_size = Vector2(12, 72)
	_energy_bar.size = Vector2(12, 72)
	_root.add_child(_energy_bar)


func _build_menu_button() -> void:
	_menu_button = Button.new()
	_menu_button.text = "Menu"
	_menu_button.pressed.connect(open_pause_menu)
	_root.add_child(_menu_button)


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
		var icon := TextureRect.new()
		icon.position = Vector2(3, 3)
		icon.size = Vector2(16, 16)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var qty := Label.new()
		qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty.position = Vector2(0, 12)
		qty.size = Vector2(SLOT_SIZE - 2, 10)
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


func _build_toast() -> void:
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_energy_bar.position = Vector2(vp.x - 18, vp.y - ACTION_SIZE - ACTION_MARGIN.y - 80)
	_menu_button.position = Vector2(vp.x - _menu_button.get_combined_minimum_size().x - 4, 4)
	var hb := _hotbar.get_combined_minimum_size()
	_hotbar.size = hb
	_hotbar.position = Vector2((vp.x - hb.x) / 2.0, vp.y - hb.y - 4)
	_joystick.position = Vector2(0, vp.y - 130)
	_joystick.size = Vector2(92, 130)
	_action_button.position = vp - Vector2(ACTION_SIZE, ACTION_SIZE) - ACTION_MARGIN
	_toast.position = Vector2(0, 44)
	_toast.size = Vector2(vp.x, 16)
	if _modal != null:
		_modal.size = vp


# ------------------------------------------------------------ rafraîchissement
func _refresh_status() -> void:
	_date_label.text = TimeManager.date_string()
	_time_label.text = "%s  %s" % [TimeManager.time_string(), TimeManager.weather_string()]
	_gold_label.text = "%d or" % Inventory.gold
	_water_label.text = "Arrosoir %d/%d" % [PlayerState.water, PlayerState.MAX_WATER]


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
	if _modal != null:
		return true
	for c: Control in [_top_panel, _menu_button, _hotbar, _joystick, _energy_bar]:
		if c.get_global_rect().has_point(point):
			return true
	return Rect2(_action_button.position, Vector2(ACTION_SIZE, ACTION_SIZE)).has_point(point)


# ------------------------------------------------------------ fenêtres
func _open_modal(title: String, closable: bool = true) -> VBoxContainer:
	close_modal()
	_modal_closable = closable
	_joystick.release()
	_joystick.visible = false
	_action_button.visible = false
	get_tree().paused = true
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
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	return box


func close_modal() -> void:
	if _modal == null:
		return
	_modal.queue_free()
	_modal = null
	_joystick.visible = true
	_action_button.visible = true
	get_tree().paused = false


func _add_button(box: Container, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 22)
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
	var box := _open_modal("Pause")
	_add_button(box, "Reprendre", close_modal)
	_add_button(box, "Sauvegarder", func() -> void:
		SaveManager.save_game()
		show_toast("Partie sauvegardée"))
	_add_button(box, "Sauvegarder et quitter", func() -> void:
		SaveManager.save_game()
		get_tree().quit())


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


func open_shop() -> void:
	var box := _open_modal("Étal de graines")
	var gold := _add_label(box, "")
	var list := VBoxContainer.new()
	box.add_child(list)
	var refresh := func() -> void:
		gold.text = "Ton or : %d" % Inventory.gold
		for child in list.get_children():
			child.queue_free()
		for id: String in GameData.items:
			var item := GameData.item(id)
			if item.get("type") != "seed":
				continue
			var row := HBoxContainer.new()
			list.add_child(row)
			var icon := TextureRect.new()
			icon.texture = GameData.item_icon(id)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icon.custom_minimum_size = Vector2(18, 18)
			row.add_child(icon)
			var in_season := GameData.crop_in_season(str(item.crop), TimeManager.season)
			var name_label := Label.new()
			name_label.text = "%s - %d or%s" % [item.name, int(item.buy), "" if in_season else " (hors saison)"]
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var buy := Button.new()
			buy.text = "Acheter"
			buy.disabled = not in_season or Inventory.gold < int(item.buy)
			buy.pressed.connect(_buy.bind(id))
			row.add_child(buy)
	refresh.call()
	_add_button(box, "Fermer", close_modal)


func _buy(id: String) -> void:
	var price := int(GameData.item(id).get("buy", 0))
	if not Inventory.can_add(id):
		show_toast("Inventaire plein !")
		return
	if Inventory.spend_gold(price):
		Inventory.add_item(id, 1)
		show_toast("+1 %s" % GameData.item_name(id))
		open_shop()  # reconstruit la liste (or et boutons à jour)
