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
	if SaveManager.has_save():
		_add_button(box, "Continuer", _start.bind(true))
	_add_button(box, "Nouvelle partie", _start.bind(false))
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
	elif map_id == "farm":
		_hud.title_card("La ferme", "%s, jour %d" % [seasons[TimeManager.season % 4], TimeManager.day], Color(0.75, 1, 0.65))
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
