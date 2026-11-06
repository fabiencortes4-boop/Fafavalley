class_name Pickup
extends Node2D
## Objet tombé au sol (minerai, butin) : il saute un peu, puis est attiré
## par le joueur et rejoint l'inventaire.

const MAGNET_RANGE := 28.0
const COLLECT_RANGE := 6.0

var item_id: String = ""
var target: Player

var _sprite: Sprite2D
var _time: float = 0.0
var _velocity: Vector2


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = GameData.item_icon(item_id)
	_sprite.scale = Vector2(0.75, 0.75)
	_sprite.offset = Vector2(0, -8)
	add_child(_sprite)
	_velocity = Vector2(randf_range(-30, 30), randf_range(-10, 10))


func _process(delta: float) -> void:
	_time += delta
	position += _velocity * delta
	_velocity = _velocity.move_toward(Vector2.ZERO, 120.0 * delta)
	_sprite.position.y = -absf(sin(_time * 3.0)) * 2.0 - maxf(0.0, 0.3 - _time) * 20.0
	if target == null or _time < 0.4:
		return
	var distance := position.distance_to(target.position)
	if distance < MAGNET_RANGE and Inventory.can_add(item_id):
		position = position.move_toward(target.position, (MAGNET_RANGE - distance + 20.0) * 4.0 * delta)
		if distance < COLLECT_RANGE:
			Inventory.add_item(item_id, 1)
			Sfx.play("pickup", -2.0, 0.15)
			EventBus.toast("+1 %s" % GameData.item_name(item_id))
			queue_free()
