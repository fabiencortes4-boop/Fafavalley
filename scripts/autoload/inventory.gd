extends Node
## Inventaire du joueur (barre rapide) et argent.

const SIZE := 12

var slots: Array = []  # null ou {"id": String, "qty": int}
var selected: int = 0
var gold: int = 0


func _ready() -> void:
	reset()


func reset() -> void:
	slots.clear()
	slots.resize(SIZE)
	slots.fill(null)
	selected = 0
	gold = 0


func _stack_max(id: String) -> int:
	return int(GameData.item(id).get("stack", 99))


## Ajoute des objets ; renvoie la quantité qui n'a pas pu être rangée.
func add_item(id: String, qty: int = 1) -> int:
	var remaining := qty
	var max_stack := _stack_max(id)
	for slot: Variant in slots:
		if remaining <= 0:
			break
		if slot != null and slot.id == id and slot.qty < max_stack:
			var moved: int = mini(remaining, max_stack - slot.qty)
			slot.qty += moved
			remaining -= moved
	for i in SIZE:
		if remaining <= 0:
			break
		if slots[i] == null:
			var moved := mini(remaining, max_stack)
			slots[i] = {"id": id, "qty": moved}
			remaining -= moved
	EventBus.inventory_changed.emit()
	return remaining


func can_add(id: String, qty: int = 1) -> bool:
	var space := 0
	var max_stack := _stack_max(id)
	for slot: Variant in slots:
		if slot == null:
			space += max_stack
		elif slot.id == id:
			space += max_stack - int(slot.qty)
	return space >= qty


func count_of(id: String) -> int:
	var total := 0
	for slot: Variant in slots:
		if slot != null and slot.id == id:
			total += int(slot.qty)
	return total


func remove_from_slot(index: int, qty: int = 1) -> void:
	var slot: Variant = slots[index]
	if slot == null:
		return
	slot.qty -= qty
	if slot.qty <= 0:
		slots[index] = null
	EventBus.inventory_changed.emit()


func get_selected() -> Variant:
	return slots[selected]


func select(index: int) -> void:
	selected = clampi(index, 0, SIZE - 1)
	EventBus.inventory_changed.emit()


func add_gold(amount: int) -> void:
	gold += amount
	EventBus.gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold)
	return true


func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true), "selected": selected, "gold": gold}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Array = data.get("slots", [])
	for i in mini(saved.size(), SIZE):
		var s: Variant = saved[i]
		if s is Dictionary:
			slots[i] = {"id": str(s.id), "qty": int(s.qty)}
	selected = int(data.get("selected", 0))
	gold = int(data.get("gold", 0))
	EventBus.inventory_changed.emit()
	EventBus.gold_changed.emit(gold)
