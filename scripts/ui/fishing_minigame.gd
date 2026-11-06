class_name FishingMinigame
extends Control
## Mini-jeu de pêche, pensé pour un écran en paysage : le poisson file
## de gauche à droite ; appuyer (n'importe où) pousse le filet vers la
## droite, relâcher le laisse revenir à gauche. Garder le poisson dans le
## filet remplit la jauge ; s'il en sort trop longtemps, il s'échappe.

signal finished(success: bool)

const TRACK_SIZE := Vector2(260, 30)
const BAR_HEIGHT := 8.0
const NET_ACCEL := 2.4
const NET_MAX_SPEED := 1.3
const START_PROGRESS := 0.35
const GRACE_TIME := 0.6

var difficulty: float = 0.3  # 0 = facile, 1 = très difficile
var behavior: String = "calm"  # calm, dart, sink
var fish_texture: Texture2D

var progress: float = START_PROGRESS
var _net_pos: float = 0.3
var _net_vel: float = 0.0
var _net_width: float = 0.3
var _fish_pos: float = 0.5
var _fish_target: float = 0.5
var _fish_speed: float = 0.3
var _fish_timer: float = 0.0
var _elapsed: float = 0.0
var _touches: Dictionary = {}
var _done: bool = false


func _ready() -> void:
	custom_minimum_size = TRACK_SIZE + Vector2(0, BAR_HEIGHT + 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_net_width = lerpf(0.36, 0.19, difficulty)
	_net_pos = 0.5 - _net_width / 2.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
		else:
			_touches.erase(event.index)


func is_holding() -> bool:
	return not _touches.is_empty() or Input.is_action_pressed("use_tool")


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	# Filet : appuyer = accélérer vers la droite, relâcher = vers la gauche.
	_net_vel += (NET_ACCEL if is_holding() else -NET_ACCEL) * delta
	_net_vel = clampf(_net_vel, -NET_MAX_SPEED, NET_MAX_SPEED)
	_net_pos += _net_vel * delta
	if _net_pos < 0.0:
		_net_pos = 0.0
		_net_vel = -_net_vel * 0.3
	elif _net_pos > 1.0 - _net_width:
		_net_pos = 1.0 - _net_width
		_net_vel = -_net_vel * 0.3
	if _elapsed > GRACE_TIME:
		_move_fish(delta)
	var inside := _fish_pos >= _net_pos and _fish_pos <= _net_pos + _net_width
	if inside:
		progress += 0.5 * delta
	else:
		progress -= lerpf(0.12, 0.3, difficulty) * delta
	if progress >= 1.0:
		_end(true)
	elif progress <= 0.0:
		_end(false)
	queue_redraw()


func _move_fish(delta: float) -> void:
	_fish_timer -= delta
	if _fish_timer <= 0.0:
		var calm_speed := lerpf(0.12, 0.52, difficulty)
		match behavior:
			"dart":
				# Longues pauses puis brusques accélérations.
				if randf() < 0.35 + difficulty * 0.3:
					_fish_target = randf()
					_fish_speed = calm_speed * 2.5
				else:
					_fish_target = clampf(_fish_pos + randf_range(-0.12, 0.12), 0.0, 1.0)
					_fish_speed = calm_speed * 0.6
			"sink":
				# Tire vers la gauche (le fond), remonte parfois.
				_fish_target = clampf(_fish_pos + randf_range(-0.4, 0.15), 0.0, 1.0)
				_fish_speed = calm_speed
			_:
				_fish_target = clampf(_fish_pos + randf_range(-0.3, 0.3), 0.05, 0.95)
				_fish_speed = calm_speed
		_fish_timer = randf_range(0.5, 1.6) * lerpf(1.2, 0.6, difficulty)
	_fish_pos = move_toward(_fish_pos, _fish_target, _fish_speed * delta)


func _end(success: bool) -> void:
	_done = true
	finished.emit(success)


func _draw() -> void:
	var outline := Color(0.25, 0.15, 0.19)
	var track := Rect2(Vector2.ZERO, TRACK_SIZE)
	draw_rect(track, Color(0.36, 0.66, 0.84))
	draw_rect(Rect2(0, TRACK_SIZE.y * 0.65, TRACK_SIZE.x, TRACK_SIZE.y * 0.35), Color(0.25, 0.52, 0.77))
	# Filet
	var net := Rect2(_net_pos * TRACK_SIZE.x, 2, _net_width * TRACK_SIZE.x, TRACK_SIZE.y - 4)
	var inside := _fish_pos >= _net_pos and _fish_pos <= _net_pos + _net_width
	draw_rect(net, Color(0.55, 0.85, 0.45, 0.55 if inside else 0.35))
	draw_rect(net, Color(0.3, 0.6, 0.3) if inside else Color(0.95, 0.95, 0.9, 0.8), false, 2.0)
	# Poisson
	if fish_texture != null:
		var x := _fish_pos * TRACK_SIZE.x
		var wiggle := sin(_elapsed * 14.0) * 1.5
		draw_texture_rect(fish_texture, Rect2(x - 8, TRACK_SIZE.y / 2.0 - 8 + wiggle, 16, 16), false)
	draw_rect(track, outline, false, 2.0)
	# Jauge de prise
	var bar := Rect2(0, TRACK_SIZE.y + 4, TRACK_SIZE.x, BAR_HEIGHT)
	draw_rect(bar, Color(0.15, 0.1, 0.08))
	var fill_color := Color(0.9, 0.35, 0.3).lerp(Color(0.45, 0.82, 0.36), progress)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(progress, 0.0, 1.0), bar.size.y)), fill_color)
	draw_rect(bar, outline, false, 1.0)
