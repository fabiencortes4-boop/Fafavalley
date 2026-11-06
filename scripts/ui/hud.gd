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
var _health_bar: ProgressBar
var _location_label: Label
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
	EventBus.water_changed.connect(func(_v: int, _m: int) -> void: _refresh_status())
	EventBus.toast_requested.connect(show_toast)
	EventBus.shop_requested.connect(open_shop)
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
func _build_top_panel() -> void:
	_top_panel = PanelContainer.new()
	_top_panel.position = Vector2(4, 4)
	_root.add_child(_top_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_top_panel.add_child(box)
	_location_label = Label.new()
	_location_label.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	box.add_child(_location_label)
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
	_health_bar = ProgressBar.new()
	_health_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(12, 72)
	_health_bar.size = Vector2(12, 72)
	var red := StyleBoxFlat.new()
	red.bg_color = Color(0.86, 0.3, 0.3)
	red.set_expand_margin_all(-3)
	_health_bar.add_theme_stylebox_override("fill", red)
	_root.add_child(_health_bar)


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
	_health_bar.position = _energy_bar.position - Vector2(15, 0)
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
	for c: Control in [_top_panel, _menu_button, _hotbar, _joystick, _energy_bar, _health_bar]:
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
	if _dialog_tween != null:
		_dialog_tween.kill()
		_dialog_tween = null
	_modal.queue_free()
	_modal = null
	_dialog_label = null
	_modal_closed_at = Time.get_ticks_msec()
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
	_add_button(box, "Habitants", open_relations)
	_add_button(box, "Carnet de pêche", open_fish_log)
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
	var box := _open_modal("Épicerie de Rosalie")
	var gold := _add_label(box, "")
	var list := VBoxContainer.new()
	box.add_child(list)
	var refresh := func() -> void:
		gold.text = "Ton or : %d" % Inventory.gold
		for child in list.get_children():
			child.queue_free()
		for id: String in GameData.items:
			var item := GameData.item(id)
			if item.get("type") != "seed" and not item.get("shop", false):
				continue
			var row := HBoxContainer.new()
			list.add_child(row)
			var icon := TextureRect.new()
			icon.texture = GameData.item_icon(id)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icon.custom_minimum_size = Vector2(18, 18)
			row.add_child(icon)
			var is_seed: bool = item.get("type") == "seed"
			var in_season := not is_seed or GameData.crop_in_season(str(item.crop), TimeManager.season)
			var owned := not is_seed and Inventory.count_of(id) > 0
			var name_label := Label.new()
			name_label.text = "%s - %d or%s" % [item.name, int(item.buy), "" if in_season else " (hors saison)"]
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var buy := Button.new()
			buy.text = "Acheter"
			buy.disabled = not in_season or owned or Inventory.gold < int(item.buy)
			if owned:
				buy.text = "Acquis"
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
	for id: String in GameData.npcs:
		var data := GameData.npc(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var face := TextureRect.new()
		face.texture = GameData.npc_texture(id)
		face.custom_minimum_size = Vector2(16, 16)
		row.add_child(face)
		var label := Label.new()
		var known := Relations.met.has(id)
		label.text = "%s, %s" % [data.name, data.get("title", "")] if known else "???"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(110, 0)
		row.add_child(label)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		info.add_child(_hearts_row(Relations.hearts(id)))
		var status := Label.new()
		status.text = "Cadeau offert" if Relations.gifted_today.has(id) else ("Déjà vu aujourd'hui" if Relations.talked_today.has(id) else "")
		status.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		info.add_child(status)
	_add_button(box, "Retour", open_pause_menu)


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
		close_modal())
	_add_button(row, "Non", close_modal)


func open_elevator(levels: Array) -> void:
	var box := _open_modal("Ascenseur de la mine")
	_add_label(box, "Descendre jusqu'au niveau :")
	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for level: int in levels:
		_add_button(grid, str(level), func() -> void:
			close_modal()
			EventBus.map_change_requested.emit("mine:%d" % level, Vector2i.ZERO))
	_add_button(box, "Annuler", close_modal)
