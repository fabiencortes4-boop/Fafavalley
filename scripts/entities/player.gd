class_name Player
extends CharacterBody2D
## Personnage joueur : déplacement 8 directions, animation « vivante » (le
## sprite Kenney n'a qu'une image : on l'anime par souplesse, inclinaison,
## respiration, ombre et poussière), gestes d'outils avec impact, combat.

signal stepped  # un pas (pour les bruitages)
signal gesture_started(gesture: String)  # pour la vue 3D

const SPEED := 72.0
const INVULNERABLE_TIME := 1.0
const STEP_RATE := 14.0  # vitesse du balancement de marche

## Gestes d'outils : durée de préparation (s), durée du coup (s), pause.
const GESTURES := {
	"strike": [0.11, 0.06, 0.09],  # houe, hache, pioche : levé puis abattu
	"pour": [0.14, 0.32, 0.08],  # arrosoir : incliné, l'eau coule
	"sweep": [0.05, 0.12, 0.05],  # faux : grand balayage
	"cast": [0.16, 0.08, 0.10],  # canne à pêche : armé puis lancé
	"bend": [0.06, 0.05, 0.06],  # semer, cueillir, ramasser
}

var facing: Vector2i = Vector2i.DOWN
var locked: bool = false  # immobile (pêche...)
## Assis sur un banc ou une chaise (direction du regard dans facing)
var seated: bool = false
var step_sound: String = "step"

var _knockback: Vector2 = Vector2.ZERO
var _invulnerable: float = 0.0
var _swing_cooldown: float = 0.0
var _body: Node2D  # pivot aux pieds : souplesse et inclinaison
var _sprite: Sprite2D
var _shadow: Sprite2D
var _hand: Node2D
var _tool: Sprite2D
var _weapon: Sprite2D
var _bob: float = 0.0
var _breath: float = 0.0
var _gesture_time: float = 0.0  # > 0 pendant un geste d'outil
var _last_step_phase: int = 0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_shadow = Sprite2D.new()
	_shadow.texture = _shadow_texture()
	_shadow.modulate = Color(0, 0, 0, 0.28)
	_shadow.position = Vector2(0, -1)
	add_child(_shadow)
	_body = Node2D.new()
	add_child(_body)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/player.png")
	_sprite.offset = Vector2(0, -8)  # les pieds sur l'origine
	_body.add_child(_sprite)
	_hand = Node2D.new()
	_hand.position = Vector2(0, -7)
	add_child(_hand)
	_tool = Sprite2D.new()
	_tool.offset = Vector2(0, -7)  # le manche sur le point de rotation
	_tool.scale = Vector2(0.75, 0.75)  # un peu plus petit que le personnage
	_tool.visible = false
	_hand.add_child(_tool)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)
	EventBus.before_save.connect(_store_position)
	_weapon = Sprite2D.new()
	_weapon.offset = Vector2(0, -8)
	_weapon.visible = false
	_weapon.z_index = 1
	add_child(_weapon)


static func _shadow_texture() -> ImageTexture:
	var img := Image.create(12, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 12:
			var d := Vector2((x - 5.5) / 6.0, (y - 1.5) / 2.0).length()
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d < 0.8 else (0.5 if d < 1.0 else 0.0)))
	return ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	if seated:
		# Assis : on ne bouge pas (et on ne heurte pas le banc sur lequel on est)
		velocity = Vector2.ZERO
		_animate_idle(delta)
		_store_position()
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if locked or _gesture_time > 0.0:
		dir = Vector2.ZERO
	velocity = dir * SPEED + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()
	_swing_cooldown = maxf(_swing_cooldown - delta, 0.0)
	_gesture_time = maxf(_gesture_time - delta, 0.0)
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
		_animate_walk(delta, dir)
	elif _gesture_time <= 0.0:
		_animate_idle(delta)
	_store_position()


## Marche : petits bonds souples, inclinaison, pas sonores et poussière.
func _animate_walk(delta: float, dir: Vector2) -> void:
	_bob += delta * STEP_RATE
	var hop := absf(sin(_bob))
	_sprite.position.y = -hop * 1.6
	_body.scale = Vector2(1.0 + (1.0 - hop) * 0.06, 1.0 - (1.0 - hop) * 0.06)
	_body.rotation = lerpf(_body.rotation, dir.x * 0.09, 0.3)
	var phase := int(_bob / PI)
	if phase != _last_step_phase:
		_last_step_phase = phase
		stepped.emit()
		Sfx.play(step_sound)
		if phase % 2 == 0:
			Fx.puff(get_parent(), position + Vector2(randf_range(-3, 3), 0), Color(0.93, 0.88, 0.78, 0.55), 0.7)
	_breath = 0.0


## Arrêt : respiration lente, retour en douceur.
func _animate_idle(delta: float) -> void:
	_bob = 0.0
	_breath += delta * 2.4
	_sprite.position.y = lerpf(_sprite.position.y, 0.0, 0.3)
	_body.rotation = lerpf(_body.rotation, 0.0, 0.25)
	_body.scale = Vector2(1.0 - sin(_breath) * 0.012, 1.0 + sin(_breath) * 0.025)


func _store_position() -> void:
	PlayerState.position = position
	PlayerState.has_position = true


## S'asseoir à cette position, en regardant dans cette direction.
func sit(at: Vector2, look: Vector2i) -> void:
	seated = true
	position = at
	facing = look
	if facing.x != 0:
		_sprite.flip_h = facing.x < 0
	_store_position()


## Se lever et faire un pas pour quitter le siège.
func stand(at: Vector2) -> void:
	seated = false
	position = at
	_store_position()


func face_towards(offset: Vector2i) -> void:
	if offset == Vector2i.ZERO:
		return
	if absi(offset.x) >= absi(offset.y):
		facing = Vector2i.RIGHT if offset.x > 0 else Vector2i.LEFT
	else:
		facing = Vector2i.DOWN if offset.y > 0 else Vector2i.UP
	if facing.x != 0:
		_sprite.flip_h = facing.x < 0


## Un geste d'outil est en cours (on ne peut pas en enchaîner un autre).
func busy() -> bool:
	return _gesture_time > 0.0


## Geste d'outil animé. on_impact est appelé au moment où l'outil touche
## (effets, sons) ; l'outil disparaît ensuite.
func play_tool(gesture: String, texture: Texture2D, on_impact: Callable = Callable()) -> void:
	var timing: Array = GESTURES.get(gesture, GESTURES["bend"])
	gesture_started.emit(gesture)
	_gesture_time = float(timing[0]) + float(timing[1]) + float(timing[2])
	var side := -1.0 if facing == Vector2i.LEFT else 1.0
	var target := Vector2(facing).angle() + PI / 2.0  # outil pointé vers la case visée
	_tool.texture = texture
	_tool.flip_h = side < 0
	_tool.visible = texture != null and gesture != "bend"
	_tool.z_index = -1 if facing == Vector2i.UP else 1
	# Main au bord du corps, du côté visé (devant si on regarde en bas)
	match facing:
		Vector2i.RIGHT, Vector2i.LEFT:
			_hand.position = Vector2(6.0 * side, -6)
		Vector2i.DOWN:
			_hand.position = Vector2(4, -4)
		_:
			_hand.position = Vector2(-4, -9)
	var tw := create_tween()
	match gesture:
		"strike", "cast":
			# Préparation : outil levé derrière la tête, corps qui s'étire
			_tool.z_index = -1
			_tool.rotation = target - 2.5 * side
			tw.tween_property(_tool, "rotation", target - 2.9 * side, timing[0]).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(_body, "scale", Vector2(0.93, 1.1), timing[0])
			tw.parallel().tween_property(_body, "rotation", -0.12 * side, timing[0])
			# Coup : rapide, corps écrasé vers l'avant ; l'outil passe devant
			tw.tween_callback(func() -> void: _tool.z_index = -1 if facing == Vector2i.UP else 1)
			tw.tween_property(_tool, "rotation", target + (0.25 if gesture == "strike" else -0.3) * side, timing[1]).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_body, "scale", Vector2(1.12, 0.88), timing[1])
			tw.parallel().tween_property(_body, "rotation", 0.14 * side, timing[1])
			tw.parallel().tween_property(_sprite, "position", Vector2(Vector2(facing) * 1.5), timing[1])
		"pour":
			_tool.rotation = target - PI / 2.0 * side if facing.x != 0 else 0.0
			var tilt := _tool.rotation + 0.9 * side
			tw.tween_property(_tool, "rotation", tilt, timing[0])
			tw.parallel().tween_property(_body, "rotation", 0.08 * side, timing[0])
			tw.tween_interval(timing[1])
		"sweep":
			_tool.rotation = target - 1.9 * side
			tw.tween_property(_body, "rotation", -0.1 * side, timing[0])
			tw.tween_property(_tool, "rotation", target + 1.9 * side, timing[1]).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(_body, "rotation", 0.12 * side, timing[1])
		_:
			tw.tween_property(_body, "scale", Vector2(1.1, 0.86), timing[0])
			tw.parallel().tween_property(_sprite, "position", Vector2(Vector2(facing) * 1.5) + Vector2(0, 1), timing[0])
	if on_impact.is_valid():
		tw.tween_callback(on_impact)
	tw.tween_interval(float(timing[2]))
	tw.tween_callback(_end_gesture)


func _end_gesture() -> void:
	_tool.visible = false
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_body, "rotation", 0.0, 0.1)
	tw.parallel().tween_property(_sprite, "position", Vector2.ZERO, 0.1)


## Ancien petit geste (gardé pour les actions sans outil).
func play_use() -> void:
	play_tool("bend", null)


## Position de la pointe de l'outil (bec de l'arrosoir...).
func tool_tip() -> Vector2:
	return position + _hand.position + Vector2(0, -10).rotated(_tool.rotation)


## Coup d'arme : animation d'arc devant le joueur. Renvoie false si
## l'arme n'est pas encore prête (temps de recharge).
func swing(weapon_texture: Texture2D, cooldown: float) -> bool:
	if _swing_cooldown > 0.0 or locked:
		return false
	_swing_cooldown = cooldown
	gesture_started.emit("strike")
	_weapon.texture = weapon_texture
	_weapon.visible = true
	_weapon.position = Vector2(0, -6)
	var base := Vector2(facing).angle() + PI / 2.0
	_weapon.rotation = base - 1.3
	var tween := create_tween()
	tween.tween_property(_weapon, "rotation", base + 1.3, cooldown * 0.45).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_body, "rotation", 0.12 * (-1.0 if facing == Vector2i.LEFT else 1.0), cooldown * 0.2)
	tween.tween_callback(func() -> void: _weapon.visible = false)
	tween.tween_property(_body, "rotation", 0.0, 0.08)
	Sfx.play("sword")
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
	EventBus.player_hurt.emit(from)
	Settings.vibrate(80)
	Sfx.play("hurt")
	EventBus.camera_shake.emit(3.0, 0.2)
	var flash := create_tween()
	_sprite.modulate = Color(1, 0.4, 0.4)
	flash.tween_property(_sprite, "modulate", Color.WHITE, 0.3)
	if PlayerState.hurt(amount):
		EventBus.player_fainted.emit()
