class_name Npc
extends Node2D
## Habitant du village : suit son emploi du temps (data/npcs.json), marche
## le long d'un chemin calculé par le village, rentre chez lui le soir.

const SPEED := 30.0

var id: String = ""
var village: WorldMap  # carte où l'habitant se déplace (village, port), ou null
var home_cell: Vector2i  # case devant la porte de sa maison
## Invité venu d'ailleurs (le port) pour une fête : il repart ensuite
var guest: bool = false

var _schedule: Array = []  # [{"minutes": int, "cell": Vector2i, "home": bool}]
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _going_home: bool = false
var _inside: bool = false
var _entry_index: int = -2
var _bob: float = 0.0
var _working: bool = false  # commerçant dans sa boutique pendant les heures d'ouverture
## Assis sur un banc ou une chaise (vue 3D : pose assise, regard)
var seated: bool = false
var seat_facing: Vector2i = Vector2i.DOWN
var _seat_cell: Vector2i = Vector2i(-1, -1)
var _stand_cell: Vector2i = Vector2i(-1, -1)
## Sièges occupés par des habitants (case -> habitant), toutes cartes
static var taken_seats: Dictionary = {}
## Quelqu'un sur le passage : on attend, puis on contourne ; en dernier
## recours (coincé plus de BLOCK_GIVE_UP secondes), on passe quand même.
const BLOCK_GIVE_UP := 2.0
var _blocked_time: float = 0.0
var _rerouted: bool = false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = GameData.npc_sprite(id)
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
			"place": str(entry.get("place", "")),  # "tavern" : soirée à la taverne
		})
	if village != null:  # dans un intérieur, l'habitant ne bouge pas
		sync_to_time()


func cell() -> Vector2i:
	return Vector2i((position / WorldMap.TILE).floor())


func is_inside() -> bool:
	return _inside


## Case où se rendre pour un événement du village (sinon (-1, -1)).
func _event_spot() -> Vector2i:
	var p := Events.place_for(id)
	if p.is_empty() or village == null:
		return Vector2i(-1, -1)
	if not village is Village:
		return Vector2i(-1, -1)  # les fêtes ont lieu sur la place du village
	return village.gather_cell(p.place, int(p.index))


## Le commerçant tient sa boutique pendant ses heures d'ouverture.
func _works_now() -> bool:
	var shop := str(GameData.npc(id).get("shop", ""))
	return Shops.shops.has(shop) and Shops.is_open(shop)


## Est-ce que l'habitant est chez lui (ou dans sa boutique) à cette heure ?
static func is_home_at(npc_id: String, minutes: int) -> bool:
	if VillageLife.sick == npc_id:
		return true  # malade : au lit toute la journée
	var data := GameData.npc(npc_id)
	var shop := str(data.get("shop", ""))
	if Shops.shops.has(shop) and Shops.is_open(shop):
		return true
	if Events.gathering_now():
		return false  # tout le monde est à la fête
	var home := true
	for entry: Dictionary in data.get("schedule", []):
		var parts := str(entry.get("time", "06:00")).split(":")
		if int(parts[0]) * 60 + int(parts[1]) <= minutes:
			home = bool(entry.get("home", false))
	return home


## Lieu de sortie de l'habitant à cette heure ("tavern"...), "" sinon.
static func place_at(npc_id: String, minutes: int) -> String:
	var place := ""
	for entry: Dictionary in GameData.npc(npc_id).get("schedule", []):
		var parts := str(entry.get("time", "06:00")).split(":")
		if int(parts[0]) * 60 + int(parts[1]) <= minutes:
			place = str(entry.get("place", ""))
	return place


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
	if VillageLife.sick == id:
		position = village.cell_center(home_cell)
		_set_inside(true)
		return
	_working = _works_now()
	var gather := _event_spot()
	if gather != Vector2i(-1, -1) and not _working:
		_gather_target = gather
		position = village.cell_center(gather)
		_set_inside(false)
		return
	if guest:
		position = village.cell_center(home_cell)
		_set_inside(true)
		return
	if _working or _entry_index < 0 or _schedule[_entry_index].home or _schedule[_entry_index].place != "":
		position = village.cell_center(home_cell)
		_set_inside(true)
	else:
		position = village.cell_center(_schedule[_entry_index].cell)
		_set_inside(false)


## Appelé à chaque changement d'heure : part vers la prochaine étape.
func on_time_changed() -> void:
	if VillageLife.sick == id:
		return
	var index := _entry_at(TimeManager.minutes)
	var working := _works_now()
	var gather := _event_spot()
	if gather != Vector2i(-1, -1) and not working:
		# Événement au village : tout le monde se rassemble
		if _gather_target != gather:
			_gather_target = gather
			_walk_to(gather, false)
		return
	if _gather_target != Vector2i(-1, -1):
		_gather_target = Vector2i(-1, -1)
		_entry_index = -2  # fin de l'événement : on reprend l'emploi du temps
		if guest and village is Village:
			_walk_to((village as Village).tavern_cell(), true)  # rentre au port
			return
	if guest:
		return
	if working != _working:
		_working = working
		_entry_index = -2
		if working:
			_walk_to(home_cell, true)
			_entry_index = index
			return
	if working:
		return
	if index == _entry_index or index < 0:
		return
	_entry_index = index
	var entry: Dictionary = _schedule[index]
	if entry.place != "":
		# Soirée à la taverne : on part vers le port (ou sa porte) et on disparaît
		var target: Vector2i = village.tavern_cell()
		if target == Vector2i(-1, -1):
			_set_inside(true)
		else:
			if _inside:
				position = village.cell_center(home_cell)
				_set_inside(false)
			_walk_to(target, true)
		return
	if _inside:
		if entry.home:
			return
		position = village.cell_center(home_cell)
		_set_inside(false)
	_walk_to(home_cell if entry.home else entry.cell, entry.home)


var _gather_target: Vector2i = Vector2i(-1, -1)


func _walk_to(target: Vector2i, going_home: bool) -> void:
	stand_up()
	if _inside:
		if going_home:
			return
		position = village.cell_center(home_cell)
		_set_inside(false)
	_going_home = going_home
	_path = village.find_path(cell(), target)
	_path_index = 0
	if _path.is_empty():  # pas de chemin : on se téléporte
		position = village.cell_center(target)
		_arrive()


func _process(delta: float) -> void:
	if village == null or _inside or _path_index >= _path.size():
		_sprite.position.y = 0.0
		return
	var target := village.cell_center(_path[_path_index])
	var to_target := target - position
	var step := SPEED * delta
	var blocker := _blocker(to_target)
	if blocker == null:
		_blocked_time = 0.0
	elif _blocked_time < BLOCK_GIVE_UP:
		_blocked_time += delta
		if _blocked_time > 0.6 and not _rerouted:
			# Un seul détour par case : on contourne la case occupée si possible
			_rerouted = true
			var goal := _path[_path_size() - 1]
			var around := village.find_path(cell(), goal, [Vector2i((blocker.position / WorldMap.TILE).floor())])
			if around.size() > 2 and around.slice(1) != _path.slice(_path_index):
				_path = around
				_path_index = 1
		_sprite.position.y = 0.0
		return
	if to_target.length() <= step:
		position = target
		_path_index += 1
		_rerouted = false
		if _path_index >= _path.size():
			_arrive()
	else:
		position += to_target.normalized() * step
		if absf(to_target.x) > 0.5:
			_sprite.flip_h = to_target.x < 0
	_bob += delta * 12.0
	_sprite.position.y = -absf(sin(_bob)) * 1.5


## Direction de marche actuelle (nulle à l'arrêt).
func heading() -> Vector2:
	if village == null or _inside or _path_index >= _path.size():
		return Vector2.ZERO
	var to := village.cell_center(_path[_path_index]) - position
	return to.normalized() if to.length() > 0.5 else Vector2.ZERO


func _path_size() -> int:
	return _path.size()


## Le joueur ou un autre habitant juste devant, dans le sens de la marche.
func _blocker(to_target: Vector2) -> Node2D:
	if to_target.length() < 0.5:
		return null
	var dir := to_target.normalized()
	var others: Array = [village.player]
	var list: Variant = village.get("npcs")
	if list is Array:
		others.append_array(list)
	for o: Variant in others:
		if o == null or o == self or not is_instance_valid(o):
			continue
		if o is Npc and ((o as Npc)._inside or (o as Npc).seated or not (o as Npc).visible):
			continue
		if o is Npc and (o as Npc).heading().dot(dir) > 0.3:
			continue  # il marche devant nous dans le même sens : on le suit
		var rel: Vector2 = (o as Node2D).position - position
		if rel.length() < 12.0 and rel.dot(dir) > 3.0:
			return o
	return null


func _arrive() -> void:
	_path.clear()
	_path_index = 0
	if _going_home:
		_set_inside(true)
		return
	# Un banc libre juste à côté ? On s'y assoit un moment.
	if village != null:
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var c := cell() + d
			if village.seats.has(c) and not taken_seats.has(c) and village.player_cell() != c:
				sit_on(c, village.seats[c], village.cell_center(c) + Vector2(0, -4))
				break


## S'asseoir sur ce siège (position du siège, regard).
func sit_on(seat: Vector2i, look: Vector2i, at: Vector2) -> void:
	_stand_cell = cell()
	_seat_cell = seat
	taken_seats[seat] = id
	seated = true
	seat_facing = look
	position = at
	if look.x != 0:
		_sprite.flip_h = look.x < 0


func stand_up() -> void:
	if not seated:
		return
	seated = false
	taken_seats.erase(_seat_cell)
	if village != null and _stand_cell != Vector2i(-1, -1):
		position = village.cell_center(_stand_cell)
	_seat_cell = Vector2i(-1, -1)


func _exit_tree() -> void:
	if seated:
		taken_seats.erase(_seat_cell)


func _set_inside(value: bool) -> void:
	_inside = value
	visible = not value
	_shape.set_deferred("disabled", value)


func face(point: Vector2) -> void:
	if absf(point.x - position.x) > 1.0:
		_sprite.flip_h = point.x < position.x
