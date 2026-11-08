extends Node
## Point d'entrée : écran titre, puis lancement de la ferme et du HUD.

var _title_layer: CanvasLayer
var _hud: Hud
var _world: WorldMap
var _arrival: Vector2 = Vector2.INF
var _view: View3D


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
	_title_box = box
	_show_slots()
	var hint := _install_hint()
	if hint != "":
		var label := Label.new()
		label.text = hint
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.19))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		box.add_child(label)


## Sur le web, explique comment installer le jeu sur l'écran d'accueil
## (sauf s'il est déjà lancé depuis l'écran d'accueil).
func _install_hint() -> String:
	if not OS.has_feature("web"):
		return ""
	var standalone: Variant = JavaScriptBridge.eval(
		"(window.navigator.standalone === true || window.matchMedia('(display-mode: fullscreen)').matches || window.matchMedia('(display-mode: standalone)').matches) ? 1 : 0")
	if standalone != null and int(standalone) == 1:
		return ""
	var agent_value: Variant = JavaScriptBridge.eval("navigator.userAgent + (navigator.maxTouchPoints > 1 ? ' Touch' : '')")
	var agent := "" if agent_value == null else str(agent_value)
	# iPadOS se présente comme un Mac : on le reconnaît à l'écran tactile.
	if agent.contains("iPhone") or agent.contains("iPad") or (agent.contains("Macintosh") and agent.contains("Touch")):
		return "Astuce : Partager puis « Sur l'écran d'accueil »\npour jouer en plein écran."
	if agent.contains("Android"):
		return "Astuce : menu du navigateur puis « Ajouter à l'écran d'accueil »\npour jouer en plein écran."
	return ""


var _title_box: VBoxContainer
var _slot_list: VBoxContainer
var _identity: Dictionary = {}


## Les trois emplacements de sauvegarde : continuer, ou commencer une partie.
func _show_slots() -> void:
	if _slot_list != null:
		_slot_list.queue_free()
	_slot_list = VBoxContainer.new()
	_slot_list.add_theme_constant_override("separation", 4)
	_title_box.add_child(_slot_list)
	_title_box.move_child(_slot_list, 2)
	for s in SaveManager.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_slot_list.add_child(row)
		var info := SaveManager.summary(s)
		var label := Label.new()
		label.custom_minimum_size = Vector2(220, 0)
		label.text = "Partie %d : vide" % (s + 1) if info.is_empty() else "%s - %s\n%s, %d or" % [info.name, info.farm, info.date, info.gold]
		row.add_child(label)
		if not info.is_empty():
			_add_button(row, "Continuer", func() -> void:
				SaveManager.slot = s
				_start(true))
		_add_button(row, "Nouvelle", func() -> void:
			SaveManager.slot = s
			_show_creation())
	_add_button(_slot_list, "Importer une partie", _show_import)


## Création du personnage : nom, nom de la ferme, tenue.
func _show_creation() -> void:
	_slot_list.queue_free()
	_slot_list = VBoxContainer.new()
	_slot_list.add_theme_constant_override("separation", 4)
	_title_box.add_child(_slot_list)
	_title_box.move_child(_slot_list, 2)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Ton prénom"
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(220, 24)
	_slot_list.add_child(name_edit)
	var farm_edit := LineEdit.new()
	farm_edit.placeholder_text = "Nom de ta ferme (ex. Les Tournesols)"
	farm_edit.max_length = 22
	_slot_list.add_child(farm_edit)
	var looks := HBoxContainer.new()
	looks.alignment = BoxContainer.ALIGNMENT_CENTER
	looks.add_theme_constant_override("separation", 4)
	_slot_list.add_child(looks)
	var chosen := [0]
	var buttons: Array = []
	for i in 4:
		var b := Button.new()
		b.text = ["Salopette", "Bleu de travail", "Robe d'été", "Chemise rouge"][i]
		b.toggle_mode = true
		b.button_pressed = i == 0
		looks.add_child(b)
		buttons.append(b)
		b.pressed.connect(func() -> void:
			chosen[0] = i
			for k in buttons.size():
				(buttons[k] as Button).button_pressed = k == i)
	_add_button(_slot_list, "Commencer l'aventure", func() -> void:
		var n := name_edit.text.strip_edges()
		var f := farm_edit.text.strip_edges()
		_identity = {"name": n if n != "" else "Fermier", "farm": f if f != "" else "La ferme", "look": chosen[0]}
		_start(false))
	_add_button(_slot_list, "Retour", _show_slots)


## Importer une partie exportée (texte copié) dans le premier emplacement libre.
func _show_import() -> void:
	var text := DisplayServer.clipboard_get()
	var target := 0
	for s in SaveManager.SLOTS:
		if not SaveManager.has_save(s):
			target = s
			break
	var ok := SaveManager.import_text(text, target)
	_show_slots()
	var msg := Label.new()
	msg.text = ("Partie importée dans l'emplacement %d !" % (target + 1)) if ok else "Rien à importer : copie d'abord le texte d'une partie exportée (Menu > Réglages > Exporter)."
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(300, 0)
	_slot_list.add_child(msg)


func _add_button(box: Container, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 26)
	b.pressed.connect(callback)
	box.add_child(b)


func _start(load_save: bool) -> void:
	if not (load_save and GameFlow.continue_game()):
		GameFlow.new_game()
		PlayerState.player_name = str(_identity.get("name", "Fermier"))
		PlayerState.farm_name = str(_identity.get("farm", "La ferme"))
		PlayerState.look = int(_identity.get("look", 0))
	_title_layer.queue_free()
	_hud = Hud.new()
	add_child(_hud)
	_load_map(PlayerState.map)
	EventBus.map_change_requested.connect(_on_map_change_requested)
	Settings.view_changed.connect(_apply_view)
	TimeManager.day_started.connect(_on_day_started)
	GameFlow.begin()
	if not PlayerState.flags.has("arrived"):
		PlayerState.flags["arrived"] = true
		if Story.play_arrival and DisplayServer.get_name() != "headless":
			_play_arrival()


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
	elif map_id == "home":
		_world = HomeMap.new()
	elif map_id == "forest":
		_world = ForestMap.new()
	elif map_id == "port":
		_world = PortMap.new()
	elif map_id == "sea":
		_world = SeaMap.new()
	elif map_id.begins_with("in:"):
		var inside := InteriorMap.new()
		inside.setup(map_id.trim_prefix("in:"))
		_world = inside
	else:
		_world = Farm.new()
	_world.hud = _hud
	add_child(_world)
	move_child(_world, 0)
	_hud.set_location(_world.display_name())
	_hud.set_world(_world)
	Music.set_place(map_id)
	Tutorial.world = _world
	_apply_view()


## Vue 3D (modèles Kenney) par-dessus la logique de la carte, ou vue 2D.
func _apply_view() -> void:
	if _view != null:
		_view.queue_free()
		_view = null
		View3D.current = null
	if _world == null:
		return
	_world.visible = not Settings.view_3d
	if Settings.view_3d:
		_view = View3D.new()
		add_child(_view)
		_view.setup(_world)


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
	var previous := PlayerState.map
	_load_map(map_id)
	_hud.fade_in()
	_announce(map_id, previous)


## Nouvelle partie : arrivée sur la place de Valfleur, accueil par le maire,
## puis direction la ferme.
func _play_arrival() -> void:
	_arrival = Vector2(29 * 16 + 8, 29 * 16 + 12)  # sur la place, devant la fontaine
	_switch_to("village")
	await get_tree().create_timer(0.6).timeout
	_hud.play_scene("Arrivée à Valfleur", Story.arrival, {}, Callable(), func() -> void:
		_arrival = Vector2(7 * 16 + 8, 7 * 16 + 12)  # devant la maison de la ferme
		_switch_to("farm"))


## Carte de titre + ambiance sonore à chaque changement de lieu : chaque
## lieu a son identité (couleur, sous-titre, bruitage).
func _announce(map_id: String, previous: String) -> void:
	var seasons := ["Printemps", "Été", "Automne", "Hiver"]
	if map_id == "home":
		_hud.title_card("Chez toi", "La maison de Firmin", Color(1, 0.82, 0.6))
	elif map_id == "port" and not previous.begins_with("in:"):
		_hud.title_card("Port du Héron", "À l'est de Valfleur", Color(0.6, 0.85, 1.0))
	elif map_id == "forest":
		_hud.title_card("Forêt de la source", "Au nord de la ferme", Color(0.6, 0.95, 0.7))
	elif map_id == "sea":
		_hud.title_card("Au large", "Thons, espadons... et peut-être une légende", Color(0.5, 0.75, 1.0))
	elif map_id == "farm":
		_hud.title_card(PlayerState.farm_name, "%s, jour %d" % [seasons[TimeManager.season % 4], TimeManager.day], Color(0.75, 1, 0.65))
	elif map_id == "village" and not previous.begins_with("in:"):
		var fest := Events.festival_today()
		if not fest.is_empty():
			_hud.title_card(str(fest.name), "Sur la place, de %dh à %dh" % [int(fest.start), int(fest.end)], Color(1, 0.75, 0.9))
		else:
			_hud.title_card("Valfleur", "Le village", Color(1, 0.92, 0.55))
	elif map_id.begins_with("in:"):
		var layout: Dictionary = InteriorMap.LAYOUTS.get(map_id.trim_prefix("in:"), {})
		_hud.title_card(str(layout.get("name", "")), "", Color(1, 0.9, 0.75))
	elif map_id.begins_with("mine:") and not previous.begins_with("mine:"):
		_hud.title_card("La mine", "Niveau %s" % map_id.trim_prefix("mine:"), Color(0.65, 0.8, 1))


## Au réveil, on est toujours à la ferme.
func _on_day_started(_day: int, _season: int, _year: int) -> void:
	if _world != null and _world.map_id != PlayerState.map:
		_switch_to.call_deferred(PlayerState.map)
