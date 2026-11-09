extends Node
## Fossiles et musée : en labourant ou en cassant la pierre de la mine, on
## trouve parfois un morceau de squelette. Donnés au musée (Journal), ils
## reconstituent le grand squelette de la vallée.

signal changed

const PIECES := ["fossil_skull", "fossil_ribs", "fossil_leg", "fossil_tail", "fossil_shell"]
const REWARD := 3000

var donated: Dictionary = {}  # id -> true


func reset() -> void:
	donated.clear()


## Un fossile trouvé au hasard (de préférence un morceau qui manque).
func roll_find(chance: float) -> String:
	if randf() >= chance:
		return ""
	var missing := PIECES.filter(func(p: String) -> bool: return not donated.has(p) and Inventory.count_of(p) == 0)
	var pool: Array = missing if not missing.is_empty() else PIECES
	return pool[randi() % pool.size()]


func donate(id: String) -> bool:
	if not id in PIECES or donated.has(id) or Inventory.count_of(id) == 0:
		return false
	Inventory.remove_item(id, 1)
	donated[id] = true
	Story.bump("fossils")
	if complete():
		Inventory.add_gold(REWARD)
		PlayerState.flags["museum_complete"] = true
		Mail.send_custom("musee_complet", {
			"from": "Bertrand, maire de Valfleur",
			"text": "Le squelette est complet ! Les savants de la ville n'en reviennent pas : un ancien cerf géant, qui vivait dans la vallée il y a des milliers d'années. Le musée t'offre %d pièces d'or. Viens l'admirer à la mairie !" % REWARD,
		})
	changed.emit()
	return true


func complete() -> bool:
	return PIECES.all(func(p: String) -> bool: return donated.has(p))


func to_dict() -> Dictionary:
	return {"donated": donated.keys()}


func from_dict(data: Dictionary) -> void:
	reset()
	for k: Variant in data.get("donated", []):
		donated[str(k)] = true
