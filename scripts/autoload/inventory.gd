extends Node
## Inventaire du joueur et argent. Les 12 premières cases forment la barre
## rapide (objets utilisables) ; le reste du sac (jusqu'à 36 cases avec les
## agrandissements) sert au rangement. Les fonctions *_slots() travaillent
## sur n'importe quel tableau de cases (sac ou coffre).

const HOTBAR := 12
const SIZE := HOTBAR  # compatibilité : taille de la barre rapide
const MAX_CAPACITY := 36

var slots: Array = []  # null ou {"id": String, "qty": int}
var capacity: int = HOTBAR
var selected: int = 0
var gold: int = 0


func _ready() -> void:
	reset()


func reset() -> void:
	capacity = HOTBAR
	slots.clear()
	slots.resize(capacity)
	slots.fill(null)
	selected = 0
	gold = 0


func set_capacity(value: int) -> void:
	capacity = clampi(value, HOTBAR, MAX_CAPACITY)
	slots.resize(capacity)  # les nouvelles cases valent null
	EventBus.inventory_changed.emit()


static func stack_max(id: String) -> int:
	return int(GameData.item(id).get("stack", 99))


# ------------------------------------------------------------ tableaux de cases
## Ajoute dans un tableau de cases ; renvoie la quantité non rangée.
static func add_to_slots(arr: Array, id: String, qty: int) -> int:
	var remaining := qty
	var max_stack := stack_max(id)
	for slot: Variant in arr:
		if remaining <= 0:
			break
		if slot != null and slot.id == id and slot.qty < max_stack:
			var moved: int = mini(remaining, max_stack - slot.qty)
			slot.qty += moved
			remaining -= moved
	for i in arr.size():
		if remaining <= 0:
			break
		if arr[i] == null:
			var moved := mini(remaining, max_stack)
			arr[i] = {"id": id, "qty": moved}
			remaining -= moved
	return remaining


static func space_in_slots(arr: Array, id: String) -> int:
	var space := 0
	var max_stack := stack_max(id)
	for slot: Variant in arr:
		if slot == null:
			space += max_stack
		elif slot.id == id:
			space += max_stack - int(slot.qty)
	return space


## Échange deux cases (ou fusionne deux piles du même objet).
static func swap_slots(a_arr: Array, a: int, b_arr: Array, b: int) -> void:
	var first: Variant = a_arr[a]
	var second: Variant = b_arr[b]
	if first != null and second != null and first.id == second.id:
		var moved: int = mini(int(first.qty), stack_max(first.id) - int(second.qty))
		second.qty += moved
		first.qty -= moved
		a_arr[a] = null if first.qty <= 0 else first
		return
	a_arr[a] = second
	b_arr[b] = first


## Déplace toute la pile d'une case vers un autre tableau (coffre <-> sac).
static func transfer(from_arr: Array, index: int, to_arr: Array) -> void:
	var slot: Variant = from_arr[index]
	if slot == null:
		return
	var left := add_to_slots(to_arr, slot.id, int(slot.qty))
	from_arr[index] = null if left <= 0 else {"id": slot.id, "qty": left}


# ------------------------------------------------------------ sac du joueur
## Ajoute des objets ; renvoie la quantité qui n'a pas pu être rangée.
func add_item(id: String, qty: int = 1) -> int:
	var left := add_to_slots(slots, id, qty)
	if left < qty:
		Collections.discover(GameData.base_id(id))
	EventBus.inventory_changed.emit()
	return left


func can_add(id: String, qty: int = 1) -> bool:
	return space_in_slots(slots, id) >= qty


## Quantité d'un objet. Avec un identifiant de base (« carrot »), toutes
## les qualités comptent ; avec « carrot@2 », seulement celle-là.
func count_of(id: String) -> int:
	return count_min_quality(id, 0) if not id.contains("@") else _count_exact(id)


func _count_exact(id: String) -> int:
	var total := 0
	for slot: Variant in slots:
		if slot != null and slot.id == id:
			total += int(slot.qty)
	return total


## Quantité d'un objet de qualité au moins `min_quality` (demandes).
func count_min_quality(base: String, min_quality: int) -> int:
	var total := 0
	for slot: Variant in slots:
		if slot != null and GameData.base_id(str(slot.id)) == base and GameData.quality_of(str(slot.id)) >= min_quality:
			total += int(slot.qty)
	return total


## Retire une quantité d'un objet, quelles que soient les cases. Avec un
## identifiant de base, on prend d'abord la qualité la plus basse.
func remove_item(id: String, qty: int) -> void:
	if id.contains("@"):
		_remove_matching(func(sid: String) -> bool: return sid == id, qty)
	else:
		remove_min_quality(id, qty, 0)


## Qualités des `qty` objets que prendrait remove_item (les moins bons d'abord).
func lowest_qualities(base: String, qty: int) -> Array:
	var out: Array = []
	for q in 4:
		var n := mini(_count_exact(GameData.with_quality(base, q)), qty - out.size())
		for i in n:
			out.append(q)
		if out.size() >= qty:
			break
	return out


## Retire `qty` objets de qualité au moins `min_quality`, les moins bons d'abord.
func remove_min_quality(base: String, qty: int, min_quality: int) -> void:
	for q in range(min_quality, 4):
		if qty <= 0:
			return
		var target := GameData.with_quality(base, q)
		var have := _count_exact(target)
		var take := mini(have, qty)
		if take > 0:
			_remove_matching(func(sid: String) -> bool: return sid == target, take)
			qty -= take


func _remove_matching(match_id: Callable, qty: int) -> void:
	for i in slots.size():
		if qty <= 0:
			break
		var slot: Variant = slots[i]
		if slot != null and match_id.call(str(slot.id)):
			var taken := mini(qty, int(slot.qty))
			remove_from_slot(i, taken)
			qty -= taken


## Remplace un objet par un autre dans la même case (amélioration d'outil).
func replace_item(old_id: String, new_id: String) -> void:
	for i in slots.size():
		if slots[i] != null and slots[i].id == old_id:
			slots[i] = {"id": new_id, "qty": 1}
			EventBus.inventory_changed.emit()
			return


func remove_from_slot(index: int, qty: int = 1) -> void:
	var slot: Variant = slots[index]
	if slot == null:
		return
	slot.qty -= qty
	if slot.qty <= 0:
		slots[index] = null
	EventBus.inventory_changed.emit()


func swap(a: int, b: int) -> void:
	swap_slots(slots, a, slots, b)
	EventBus.inventory_changed.emit()


func get_selected() -> Variant:
	return slots[selected]


func select(index: int) -> void:
	selected = clampi(index, 0, HOTBAR - 1)
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
	return {"slots": slots.duplicate(true), "selected": selected, "gold": gold, "capacity": capacity}


func from_dict(data: Dictionary) -> void:
	reset()
	set_capacity(int(data.get("capacity", HOTBAR)))
	var saved: Array = data.get("slots", [])
	for i in mini(saved.size(), capacity):
		var s: Variant = saved[i]
		if s is Dictionary:
			slots[i] = {"id": str(s.id), "qty": int(s.qty)}
	selected = int(data.get("selected", 0))
	gold = int(data.get("gold", 0))
	EventBus.inventory_changed.emit()
	EventBus.gold_changed.emit(gold)
