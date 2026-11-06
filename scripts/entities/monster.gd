class_name Monster
extends CharacterBody2D
## Monstre de la mine. Comportements (data/monsters.json) :
##  - hop   : immobile puis bondit vers le joueur (gelée)
##  - fly   : vole en zigzag, traverse les murs (chauve-souris, fantôme)
##  - chase : rôde puis fonce sur le joueur quand il est proche (rats...)

signal died(monster: Monster)

const AGGRO_RANGE := 90.0
const CONTACT_RANGE := 10.0
const STUN_TIME := 0.35  # après un coup, le monstre recule sans attaquer

var kind: String = "slime"
var level: int = 1
var target: Player
var hp: int = 10

var _data: Dictionary
var _sprite: Sprite2D
var _knockback: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _time: float = 0.0
var _wander: Vector2 = Vector2.ZERO
var _hop_velocity: Vector2 = Vector2.ZERO
var _stun: float = 0.0


func _ready() -> void:
	_data = GameData.monsters.get(kind, {})
	# Les monstres se renforcent avec la profondeur.
	var scale_factor := 1.0 + level * 0.025
	hp = int(float(_data.get("hp", 10)) * scale_factor)
	collision_layer = 4
	collision_mask = 0 if _data.get("behavior") == "fly" else 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/monsters.png")
	_sprite.hframes = 7
	_sprite.frame = int(_data.get("sprite", 0))
	_sprite.offset = Vector2(0, -8)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	shape.position = Vector2(0, -4)
	add_child(shape)
	_timer = randf_range(0.3, 1.5)
	_time = randf() * 10.0


func damage() -> int:
	# Les dégâts grimpent moins vite que la vie : on doit pouvoir survivre.
	return int(float(_data.get("damage", 5)) * (1.0 + level * 0.015))


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_time += delta
	_timer -= delta
	var to_player := target.position - position
	var near := to_player.length() < AGGRO_RANGE
	var speed := float(_data.get("speed", 40))
	var move := Vector2.ZERO
	if _stun > 0.0:
		_stun -= delta
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		return
	match str(_data.get("behavior", "chase")):
		"hop":
			if _timer <= 0.0:
				_timer = randf_range(1.0, 1.8)
				var dir := to_player.normalized() if near else Vector2.RIGHT.rotated(randf() * TAU)
				_hop_velocity = dir * speed * 3.0
			move = _hop_velocity
			_hop_velocity = _hop_velocity.move_toward(Vector2.ZERO, speed * 6.0 * delta)
			_sprite.scale = Vector2(1.0 + _hop_velocity.length() / (speed * 12.0), 1.0 - _hop_velocity.length() / (speed * 12.0))
		"fly":
			var dir := to_player.normalized() if near else _wander_dir()
			move = (dir + Vector2(0, sin(_time * 6.0)) * 0.8).normalized() * speed
		_:
			move = to_player.normalized() * speed if near else _wander_dir() * speed * 0.4
	velocity = move + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	if absf(velocity.x) > 1.0:
		_sprite.flip_h = velocity.x < 0
	if to_player.length() < CONTACT_RANGE:
		target.take_damage(damage(), position)


func _wander_dir() -> Vector2:
	if _timer <= 0.0:
		_timer = randf_range(1.0, 3.0)
		_wander = Vector2.RIGHT.rotated(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
	return _wander


## Coup reçu : recul, flash blanc, mort éventuelle.
func hit(amount: int, from: Vector2, knockback: float) -> void:
	hp -= amount
	Sfx.play("hit")
	Fx.burst(get_parent(), position + Vector2(0, -6), [Color(1, 1, 1), Color(1, 0.85, 0.5)], 6, 45.0, true, 120.0, 0.25)
	_stun = STUN_TIME
	_hop_velocity = Vector2.ZERO
	_knockback = (position - from).normalized() * knockback
	_sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		died.emit(self)
		set_physics_process(false)
		var fade := create_tween()
		fade.tween_property(self, "scale", Vector2(1.4, 0.2), 0.15)
		fade.tween_callback(queue_free)
