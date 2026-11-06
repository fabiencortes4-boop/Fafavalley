extends Node
## Test automatique : lance une partie, simule un doigt sur le joystick,
## vérifie que le joueur se déplace. Lancer :
##   godot --headless res://tests/movement_test.tscn

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.call("_start", false)
	await get_tree().create_timer(0.3).timeout
	var farm: Farm = main.get_children().filter(func(c: Node) -> bool: return c is Farm)[0]
	var start: Vector2 = farm.player.position
	print("Départ joueur : ", start, " viewport : ", get_viewport().get_visible_rect().size)
	var hud: Hud = farm.hud
	var joy: Control = hud.get("_joystick")
	print("Joystick rect : ", joy.get_global_rect())
	# Coordonnées « écran » comme sur un vrai téléphone.
	var to_screen := get_viewport().get_screen_transform()
	print("Transform écran : ", to_screen)
	var p: Vector2 = to_screen * joy.get_global_rect().get_center()
	_touch(p, true)
	for i in 10:
		_drag(p + to_screen.basis_xform(Vector2(i * 3, 0)))
		await get_tree().physics_frame
	await get_tree().create_timer(0.5).timeout
	print("Après joystick : ", farm.player.position, " get_vector=", Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	_touch(p, false)
	Input.action_press("move_down")
	await get_tree().create_timer(0.3).timeout
	Input.action_release("move_down")
	print("Après action clavier bas : ", farm.player.position)
	get_tree().quit()


func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = pos
	Input.parse_input_event(ev)
