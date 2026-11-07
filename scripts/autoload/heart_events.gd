extends Node
## Scènes de cœur (data/heart_events.json) : en parlant à un habitant dont
## l'amitié atteint 2 puis 5 cœurs, une petite scène se joue, avec un choix
## de réponse qui compte. Et les anniversaires : un cadeau ce jour-là vaut
## cinq fois plus.

const BIRTHDAY_FACTOR := 5

var events: Dictionary = {}
var seen: Dictionary = {}  # "npc:cœurs" -> true


func _ready() -> void:
	var file := FileAccess.open("res://data/heart_events.json", FileAccess.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			events = data


func reset() -> void:
	seen.clear()


## Scène à jouer maintenant avec cet habitant ({} sinon).
func pending(npc_id: String) -> Dictionary:
	for e: Dictionary in events.get(npc_id, []):
		var key := "%s:%d" % [npc_id, int(e.hearts)]
		if not seen.has(key) and Relations.hearts(npc_id) >= int(e.hearts):
			return e
	return {}


func mark_seen(npc_id: String, e: Dictionary) -> void:
	seen["%s:%d" % [npc_id, int(e.hearts)]] = true


func choose(npc_id: String, e: Dictionary, option: int) -> String:
	var opt: Array = e.choice.options[option]
	Relations.add_points(npc_id, int(opt[1]))
	mark_seen(npc_id, e)
	return str(opt[2])


## Nombre de scènes vues / existantes (pour le journal des habitants).
func count_seen(npc_id: String) -> int:
	var n := 0
	for e: Dictionary in events.get(npc_id, []):
		if seen.has("%s:%d" % [npc_id, int(e.hearts)]):
			n += 1
	return n


func is_birthday(npc_id: String) -> bool:
	var b: Array = GameData.npc(npc_id).get("birthday", [-1, -1])
	return int(b[0]) == TimeManager.season and int(b[1]) == TimeManager.day


## Habitant dont c'est l'anniversaire aujourd'hui ("" sinon).
func birthday_today() -> String:
	for id: String in GameData.npcs:
		if is_birthday(id):
			return id
	return ""


func birthday_text(npc_id: String) -> String:
	var b: Array = GameData.npc(npc_id).get("birthday", [0, 1])
	return "%d %s" % [int(b[1]), ["printemps", "été", "automne", "hiver"][int(b[0])]]


func to_dict() -> Dictionary:
	return {"seen": seen.keys()}


func from_dict(data: Dictionary) -> void:
	reset()
	for k: Variant in data.get("seen", []):
		seen[str(k)] = true
