extends Node
## État persistant du joueur (énergie, eau de l'arrosoir, position).

const MAX_ENERGY := 100
const MAX_WATER := 30

var energy: int = MAX_ENERGY
var water: int = MAX_WATER
var position: Vector2 = Vector2.ZERO
var has_position: bool = false


func reset() -> void:
	energy = MAX_ENERGY
	water = MAX_WATER
	has_position = false
	_emit()


func spend_energy(amount: int) -> bool:
	if energy < amount:
		return false
	energy -= amount
	_emit()
	return true


func use_water() -> bool:
	if water <= 0:
		return false
	water -= 1
	_emit()
	return true


func refill_water() -> void:
	water = MAX_WATER
	_emit()


## Récupération nocturne : moins d'énergie si on s'est évanoui.
func restore(passed_out: bool) -> void:
	energy = MAX_ENERGY / 2 if passed_out else MAX_ENERGY
	has_position = false
	_emit()


func _emit() -> void:
	EventBus.energy_changed.emit(energy, MAX_ENERGY)
	EventBus.water_changed.emit(water, MAX_WATER)


func to_dict() -> Dictionary:
	return {
		"energy": energy,
		"water": water,
		"position": [position.x, position.y],
		"has_position": has_position,
	}


func from_dict(data: Dictionary) -> void:
	energy = int(data.get("energy", MAX_ENERGY))
	water = int(data.get("water", MAX_WATER))
	var p: Array = data.get("position", [0, 0])
	position = Vector2(float(p[0]), float(p[1]))
	has_position = bool(data.get("has_position", false))
	_emit()
