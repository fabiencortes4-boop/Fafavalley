class_name Critter
extends Node2D
## Animal décoratif qui se promène tranquillement autour de son point d'origine.

const SPEED := 14.0
const WANDER_RADIUS := 40.0

var frame: int = 0
var _sprite: Sprite2D
var _home: Vector2
var _target: Vector2
var _wait: float = 0.0
var _bob: float = 0.0


func _ready() -> void:
	_home = position
	_target = position
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/animals.png")
	_sprite.hframes = 3
	_sprite.frame = frame
	_sprite.offset = Vector2(0, -8)
	add_child(_sprite)
	_wait = randf_range(0.5, 3.0)


func _process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		_sprite.position.y = 0.0
		if _wait <= 0.0:
			_target = _home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * WANDER_RADIUS
		return
	var to_target := _target - position
	if to_target.length() < 1.0:
		_wait = randf_range(1.5, 5.0)
		return
	position += to_target.normalized() * SPEED * delta
	_sprite.flip_h = to_target.x > 0
	_bob += delta * 10.0
	_sprite.position.y = -absf(sin(_bob))
