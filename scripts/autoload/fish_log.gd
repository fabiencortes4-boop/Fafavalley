extends Node
## Carnet de pêche : espèces attrapées, nombre de prises, plus grande taille.

var caught: Dictionary = {}  # id -> {"count": int, "best": int}


func reset() -> void:
	caught.clear()


## Enregistre une prise. Renvoie "new", "record" ou "".
func record(id: String, size: int) -> String:
	if not caught.has(id):
		caught[id] = {"count": 1, "best": size}
		return "new"
	caught[id].count += 1
	if size > int(caught[id].best):
		caught[id].best = size
		return "record"
	return ""


func to_dict() -> Dictionary:
	return {"caught": caught.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("caught", {})
	for id: String in saved:
		caught[id] = {"count": int(saved[id].get("count", 0)), "best": int(saved[id].get("best", 0))}
