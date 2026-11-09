extends Node
## Animal de compagnie (chat ou chien) : adopté au ranch de Léon, il suit
## le joueur dehors, dort près du lit, et se fait caresser une fois par jour.
## Le chien fait fuir les corbeaux plus souvent.

var kind: String = ""  # "", "cat" ou "dog"
var pet_name: String = ""
var petted_today: bool = false
var love: int = 0  # caresses reçues (il devient plus joueur)


func reset() -> void:
	kind = ""
	pet_name = ""
	petted_today = false
	love = 0


func adopt(k: String, n: String) -> void:
	kind = k
	pet_name = n
	Tips.show("pet")


func new_day() -> void:
	petted_today = false


func pet() -> bool:
	if kind == "" or petted_today:
		return false
	petted_today = true
	love += 1
	return true


func to_dict() -> Dictionary:
	return {"kind": kind, "name": pet_name, "petted": petted_today, "love": love}


func from_dict(data: Dictionary) -> void:
	kind = str(data.get("kind", ""))
	pet_name = str(data.get("name", ""))
	petted_today = bool(data.get("petted", false))
	love = int(data.get("love", 0))
