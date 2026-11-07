extends Node
## Courrier : lettres des habitants (data/letters.json) déposées dans la
## boîte aux lettres de la ferme selon le jour, la saison ou les progrès.
## Certaines contiennent des objets ou de l'or.

signal mail_changed

var letters: Dictionary = {}
var received: Dictionary = {}  # id -> true (déjà déposée)
var pending: Array = []  # ids non lues


func _ready() -> void:
	var file := FileAccess.open("res://data/letters.json", FileAccess.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			letters = data


func reset() -> void:
	received.clear()
	pending.clear()


## Dépose les lettres dont les conditions sont remplies (chaque matin).
func check() -> void:
	for id: String in letters:
		if received.has(id):
			continue
		var when: Dictionary = letters[id].get("when", {})
		if when.has("day_min") and TimeManager.day < int(when.day_min) and TimeManager.season == 0 and TimeManager.year == 1:
			continue
		if when.has("season") and TimeManager.season != int(when.season):
			continue
		if when.has("day") and TimeManager.day != int(when.day):
			continue
		if when.has("flag") and not PlayerState.flags.has(str(when.flag)):
			continue
		if when.has("flag_min"):
			var f: Array = when.flag_min
			if int(PlayerState.flags.get(str(f[0]), 0)) < int(f[1]):
				continue
		received[id] = true
		pending.append(id)
	mail_changed.emit()


func has_mail() -> bool:
	return not pending.is_empty()


## Ouvre la prochaine lettre : donne ses pièces jointes, la renvoie.
func open_next() -> Dictionary:
	if pending.is_empty():
		return {}
	var id: String = pending.pop_front()
	var letter: Dictionary = letters.get(id, {})
	for entry: Array in letter.get("items", []):
		var item := str(entry[0])
		if item == "gold":
			Inventory.add_gold(int(entry[1]))
		elif not (GameData.item(item).get("type") == "tool" and Inventory.count_of(item) > 0):
			var left := Inventory.add_item(item, int(entry[1]))
			if left > 0:
				EventBus.toast("Sac plein : %s laissé dans la boîte." % GameData.item_name(item))
				pending.push_front(id)  # on retentera plus tard
				mail_changed.emit()
				return letter
	mail_changed.emit()
	return letter


func to_dict() -> Dictionary:
	return {"received": received.keys(), "pending": pending.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	for id: Variant in data.get("received", []):
		received[str(id)] = true
	for id: Variant in data.get("pending", []):
		pending.append(str(id))
