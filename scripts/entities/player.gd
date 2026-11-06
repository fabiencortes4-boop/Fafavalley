class_name Player
extends CharacterBody2D
## Personnage joueur : déplacement 8 directions, orientation, petite animation
## de marche (le sprite Kenney n'a qu'une image : on le fait sautiller).

const SPEED := 72.0

var facing: Vector2i = Vector2i.DOWN
var locked: bool = false  # immobile (pêche...)
const INVULNERABLE_TIME := 1.0

var _knockback: Vector2 = Vector2.ZERO
var _invulnerable: float = 0.0
var _swing_cooldown: float = 0.0
var _weapon: Sprite2D
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
	_weapon = Sprite2D.new()
	_weapon.offset = Vector2(0, -8)  # la poignée sur le point de rotation
	_weapon.visible = false
	_weapon.z_index = 1
	add_child(_weapon)


func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if locked:
		dir = Vector2.ZERO
	velocity = dir * SPEED + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()
	_swing_cooldown = maxf(_swing_cooldown - delta, 0.0)
	if _invulnerable > 0.0:
		_invulnerable -= delta
		_sprite.visible = _invulnerable <= 0.0 or int(_invulnerable * 12.0) % 2 == 0
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


## Coup d'arme : animation d'arc devant le joueur. Renvoie false si
## l'arme n'est pas encore prête (temps de recharge).
func swing(weapon_texture: Texture2D, cooldown: float) -> bool:
	if _swing_cooldown > 0.0 or locked:
		return false
	_swing_cooldown = cooldown
	_weapon.texture = weapon_texture
	_weapon.visible = true
	_weapon.position = Vector2(0, -6)
	var base := Vector2(facing).angle() + PI / 2.0
	_weapon.rotation = base - 1.2
	var tween := create_tween()
	tween.tween_property(_weapon, "rotation", base + 1.2, cooldown * 0.5)
	tween.tween_callback(func() -> void: _weapon.visible = false)
	return true


## Centre de la zone touchée par un coup d'arme.
func hit_point() -> Vector2:
	return position + Vector2(facing) * 12.0 + Vector2(0, -6)


## Dégâts reçus d'un monstre (avec recul et invulnérabilité temporaire).
func take_damage(amount: int, from: Vector2) -> void:
	if _invulnerable > 0.0:
		return
	_invulnerable = INVULNERABLE_TIME
	_knockback = (position - from).normalized() * 160.0
	Input.vibrate_handheld(80)
	var flash := create_tween()
	_sprite.modulate = Color(1, 0.4, 0.4)
	flash.tween_property(_sprite, "modulate", Color.WHITE, 0.3)
	if PlayerState.hurt(amount):
		EventBus.player_fainted.emit()
