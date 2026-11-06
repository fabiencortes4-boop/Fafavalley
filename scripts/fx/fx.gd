class_name Fx
extends RefCounted
## Effets visuels courts : gerbes de particules (terre, eau, copeaux,
## éclats de pierre, herbe), petits nuages de poussière, objets qui sautent
## puis filent vers le joueur.

const DIRT := [Color(0.48, 0.31, 0.2), Color(0.62, 0.42, 0.27), Color(0.36, 0.23, 0.15)]
const WATER := [Color(0.55, 0.8, 0.98), Color(0.8, 0.93, 1.0), Color(0.36, 0.66, 0.86)]
const WOOD := [Color(0.74, 0.47, 0.29), Color(0.92, 0.7, 0.48), Color(0.5, 0.3, 0.2)]
const STONE := [Color(0.62, 0.62, 0.66), Color(0.8, 0.8, 0.84), Color(0.45, 0.45, 0.5)]
const GRASS := [Color(0.5, 0.78, 0.36), Color(0.36, 0.62, 0.3), Color(0.66, 0.86, 0.45)]
const SPARK := [Color(1, 0.95, 0.6), Color(1, 0.8, 0.3)]

static var _pixel: ImageTexture
static var _round: ImageTexture


static func _pixel_texture() -> ImageTexture:
	if _pixel == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_pixel = ImageTexture.create_from_image(img)
	return _pixel


static func _round_texture() -> ImageTexture:
	if _round == null:
		var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
		for y in 6:
			for x in 6:
				var d := Vector2(x - 2.5, y - 2.5).length()
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d < 2.2 else (0.5 if d < 3.0 else 0.0)))
		_round = ImageTexture.create_from_image(img)
	return _round


## Gerbe de particules qui retombent (une seule fois, puis disparaît).
static func burst(parent: Node, at: Vector2, colors: Array, amount: int = 10, speed: float = 60.0,
		up: bool = true, gravity: float = 260.0, lifetime: float = 0.5) -> void:
	var p := CPUParticles2D.new()
	p.texture = _pixel_texture()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.position = at
	p.direction = Vector2.UP if up else Vector2.DOWN
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, colors[0])
	ramp.set_color(1, colors[colors.size() - 1])
	if colors.size() > 2:
		ramp.add_point(0.5, colors[1])
	p.color_initial_ramp = ramp
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.7, Color.WHITE)
	p.color_ramp = fade
	p.z_index = 6
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Petit nuage de poussière (pas, chute d'objet).
static func puff(parent: Node, at: Vector2, color: Color = Color(0.93, 0.88, 0.78, 0.8), size: float = 1.0) -> void:
	var s := Sprite2D.new()
	s.texture = _round_texture()
	s.position = at
	s.modulate = color
	s.scale = Vector2.ONE * 0.6 * size
	s.z_index = -1
	parent.add_child(s)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE * 1.4 * size, 0.35)
	tw.tween_property(s, "position", at + Vector2(randf_range(-3, 3), -3), 0.35)
	tw.tween_property(s, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(s.queue_free)


## Un objet saute hors de la case puis file vers le joueur (récolte).
static func item_pop(parent: Node, from: Vector2, texture: Texture2D, target: Node2D) -> void:
	var s := Sprite2D.new()
	s.texture = texture
	s.position = from
	s.z_index = 8
	parent.add_child(s)
	var peak := from + Vector2(randf_range(-6, 6), -22)
	var tw := s.create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position", peak, 0.18)
	tw.parallel().tween_property(s, "scale", Vector2(1.25, 1.25), 0.18)
	tw.tween_interval(0.12)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(target):
			s.position = peak.lerp(target.position + Vector2(0, -10), k)
		s.scale = Vector2.ONE * lerpf(1.25, 0.4, k), 0.0, 1.0, 0.22)
	tw.tween_callback(s.queue_free)
