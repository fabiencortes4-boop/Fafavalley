class_name Npc
extends Node2D
## Habitant du village : suit son emploi du temps (data/npcs.json), marche
## le long d'un chemin calculé par le village, rentre chez lui le soir.

const SPEED := 30.0

var id: String = ""
var village: Village
var home_cell: Vector2i  # case devant la porte de sa maison

var _schedule: Array = []  # [{"minutes": int, "cell": Vector2i, "home": bool}]
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _going_home: bool = false
var _inside: bool = false
var _entry_index: int = -2
var _bob: float = 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = GameData.npc_texture(id)
	_sprite.offset = Vector2(0, -8)
	add_child(_sprite)
	# Le joueur ne traverse pas les habitants.
	var body := StaticBody2D.new()
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	_shape.shape = rect
	_shape.position = Vector2(0, -3)
	body.add_child(_shape)
	add_child(body)
	for entry: Dictionary in GameData.npc(id).get("schedule", []):
		var parts := str(entry.get("time", "06:00")).split(":")
		var cell: Array = entry.get("cell", [0, 0])
		_schedule.append({
			"minutes": int(parts[0]) * 60 + int(parts[1]),
			"cell": Vector2i(int(cell[0]), int(cell[1])),
			"home": bool(entry.get("home", false)),
		})
	sync_to_time()


func cell() -> Vector2i:
	return Vector2i((position / WorldMap.TILE).floor())


func is_inside() -> bool:
	return _inside


func _entry_at(minutes: int) -> int:
	var index := -1
	for i in _schedule.size():
		if _schedule[i].minutes <= minutes:
			index = i
	return index


## Place directement l'habitant là où il doit être à l'heure actuelle
## (arrivée sur la carte, nouveau jour).
func sync_to_time() -> void:
	_entry_index = _entry_at(TimeManager.minutes)
	_path.clear()
	if _entry_index < 0 or _schedule[_entry_index].home:
		position = village.cell_center(home_cell)
		_set_inside(true)
	else:
		position = village.cell_center(_schedule[_entry_index].cell)
		_set_inside(false)


## Appelé à chaque changement d'heure : part vers la prochaine étape.
func on_time_changed() -> void:
	var index := _entry_at(TimeManager.minutes)
	if index == _entry_index or index < 0:
		return
	_entry_index = index
	var entry: Dictionary = _schedule[index]
	if _inside:
		if entry.home:
			return
		position = village.cell_center(home_cell)
		_set_inside(false)
	_going_home = entry.home
	var target: Vector2i = home_cell if entry.home else entry.cell
	_path = village.find_path(cell(), target)
	_path_index = 0
	if _path.is_empty():  # pas de chemin : on se téléporte
		position = village.cell_center(target)
		_arrive()


func _process(delta: float) -> void:
	if _inside or _path_index >= _path.size():
		_sprite.position.y = 0.0
		return
	var target := village.cell_center(_path[_path_index])
	var to_target := target - position
	var step := SPEED * delta
	if to_target.length() <= step:
		position = target
		_path_index += 1
		if _path_index >= _path.size():
			_arrive()
	else:
		position += to_target.normalized() * step
		if absf(to_target.x) > 0.5:
			_sprite.flip_h = to_target.x < 0
	_bob += delta * 12.0
	_sprite.position.y = -absf(sin(_bob)) * 1.5


func _arrive() -> void:
	_path.clear()
	_path_index = 0
	if _going_home:
		_set_inside(true)


func _set_inside(value: bool) -> void:
	_inside = value
	visible = not value
	_shape.set_deferred("disabled", value)


func face(point: Vector2) -> void:
	if absf(point.x - position.x) > 1.0:
		_sprite.flip_h = point.x < position.x
