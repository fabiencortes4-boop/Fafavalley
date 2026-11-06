class_name VirtualJoystick
extends Control
## Joystick tactile « flottant » : il apparaît là où le pouce se pose dans
## sa zone. Il pilote les actions move_* (le clavier marche donc aussi).
## Gère le multitouch : on peut marcher et appuyer sur Action en même temps.

const RADIUS := 28.0
const KNOB_RADIUS := 12.0

var _touch_index: int = -1
var _rest_center: Vector2
var _center: Vector2
var _knob: Vector2
var output: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_reset_center)
	_reset_center()


func _reset_center() -> void:
	_rest_center = Vector2(RADIUS + 14, size.y - RADIUS - 14)
	if _touch_index == -1:
		_center = _rest_center
		_knob = _rest_center
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var local: Vector2 = event.position - global_position
		if event.pressed and _touch_index == -1 and Rect2(Vector2.ZERO, size).has_point(local):
			_touch_index = event.index
			_center = local
			_update_knob(local)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_knob(event.position - global_position)
		get_viewport().set_input_as_handled()


func _update_knob(local: Vector2) -> void:
	var offset := (local - _center).limit_length(RADIUS)
	_knob = _center + offset
	output = offset / RADIUS
	_apply("move_left", -output.x)
	_apply("move_right", output.x)
	_apply("move_up", -output.y)
	_apply("move_down", output.y)
	queue_redraw()


func _apply(action: String, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func release() -> void:
	_touch_index = -1
	output = Vector2.ZERO
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	_center = _rest_center
	_knob = _rest_center
	queue_redraw()


func _draw() -> void:
	var alpha := 0.55 if _touch_index != -1 else 0.25
	draw_circle(_center, RADIUS, Color(0.1, 0.06, 0.03, alpha))
	draw_arc(_center, RADIUS, 0, TAU, 32, Color(0.95, 0.85, 0.6, alpha), 1.5)
	draw_circle(_knob, KNOB_RADIUS, Color(0.95, 0.85, 0.6, alpha + 0.2))
