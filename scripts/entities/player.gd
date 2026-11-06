class_name Player
extends CharacterBody2D
## Personnage joueur : déplacement 8 directions, orientation, petite animation
## de marche (le sprite Kenney n'a qu'une image : on le fait sautiller).

const SPEED := 72.0

var facing: Vector2i = Vector2i.DOWN
var _sprite: Sprite2D
var _bob: float = 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/player.png")
	_sprite.offset = Vector2(0, -8)  # les pieds sur l'origine
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
		if facing.x != 0:
			_sprite.flip_h = facing.x < 0
		_bob += delta * 14.0
		_sprite.position.y = -absf(sin(_bob)) * 1.5
	else:
		_bob = 0.0
		_sprite.position.y = 0.0
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
	if facing.x != 0:
		_sprite.flip_h = facing.x < 0


## Petit « coup d'outil » visuel.
func play_use() -> void:
	var tween := create_tween()
	var push := Vector2(facing) * 2.0
	tween.tween_property(_sprite, "position", push, 0.06)
	tween.tween_property(_sprite, "position", Vector2.ZERO, 0.08)
	var squash := create_tween()
	squash.tween_property(_sprite, "scale", Vector2(1.15, 0.85), 0.06)
	squash.tween_property(_sprite, "scale", Vector2.ONE, 0.1)
