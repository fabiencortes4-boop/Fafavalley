class_name Player
extends CharacterBody2D
## Personnage joueur : déplacement 8 directions, orientation, animation.

const SPEED := 72.0
const FRAME_TIME := 0.15
const DIR_ROWS := {Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3}

var facing: Vector2i = Vector2i.DOWN
var _sprite: Sprite2D
var _anim_time: float = 0.0
var _frame: int = 0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/player.png")
	_sprite.hframes = 4
	_sprite.vframes = 4
	_sprite.offset = Vector2(0, -12)  # les pieds sur l'origine
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)
	EventBus.before_save.connect(_store_position)


func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	if dir.length() > 0.1:
		if absf(dir.x) > absf(dir.y):
			facing = Vector2i.RIGHT if dir.x > 0 else Vector2i.LEFT
		else:
			facing = Vector2i.DOWN if dir.y > 0 else Vector2i.UP
		_anim_time += delta
		if _anim_time >= FRAME_TIME:
			_anim_time = 0.0
			_frame = (_frame + 1) % 4
	else:
		_frame = 0
		_anim_time = 0.0
	_sprite.frame = DIR_ROWS[facing] * 4 + _frame
	_store_position()


func _store_position() -> void:
	PlayerState.position = position
	PlayerState.has_position = true


func face_towards(offset: Vector2i) -> void:
	if offset == Vector2i.ZERO:
		return
	if absi(offset.x) >= absi(offset.y):
		facing = Vector2i.RIGHT if offset.x > 0 else Vector2i.LEFT
	else:
		facing = Vector2i.DOWN if offset.y > 0 else Vector2i.UP
	_sprite.frame = DIR_ROWS[facing] * 4


## Petit « coup d'outil » visuel.
func play_use() -> void:
	var tween := create_tween()
	var push := Vector2(facing) * 2.0
	tween.tween_property(_sprite, "position", push, 0.06)
	tween.tween_property(_sprite, "position", Vector2.ZERO, 0.08)
