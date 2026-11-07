extends Node
## Chapitre du port (data/port_story.json) : « Le phare du Héron ».
## Une suite d'étapes auprès de Marius et Nina (objets à apporter, poissons
## à pêcher), jusqu'à rallumer le phare un soir. Il raconte aussi ce qu'est
## devenu Firmin.

signal changed

var data: Dictionary = {}
var step: int = 0
var _fish_base: int = 0


func _ready() -> void:
	var file := FileAccess.open("res://data/port_story.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed


func reset() -> void:
	step = 0
	_fish_base = 0


func steps() -> Array:
	return data.get("steps", [])


func finished() -> bool:
	return step >= steps().size()


func current() -> Dictionary:
	return {} if finished() else steps()[step]


## Avancement de l'étape (pour le journal) : "2/5 poissons", "1/3 quartz"...
func progress_text() -> String:
	var c := current()
	var parts: Array = []
	var need: Dictionary = c.get("need", {})
	for item: String in need:
		parts.append("%s %d/%d" % [GameData.item_name(item), mini(Inventory.count_of(item), int(need[item])), int(need[item])])
	if c.has("stat"):
		parts.append("poissons %d/%d" % [mini(_fish_count(), int(c.stat[1])), int(c.stat[1])])
	return ", ".join(parts)


func _fish_count() -> int:
	return int(Story.stats.get("fish", 0)) - _fish_base


func _ready_to_finish(c: Dictionary) -> bool:
	var need: Dictionary = c.get("need", {})
	for item: String in need:
		if Inventory.count_of(item) < int(need[item]):
			return false
	if c.has("stat") and _fish_count() < int(c.stat[1]):
		return false
	if c.get("night", false) and TimeManager.minutes < 20 * 60:
		return false
	return true


## En parlant à un habitant : l'étape avance si c'est la bonne personne et
## que tout est prêt. Renvoie la réplique ("" si rien ne se passe).
func try_talk(npc_id: String) -> String:
	var c := current()
	if c.is_empty() or str(c.get("npc", "")) != npc_id or c.get("night", false):
		return ""
	if not _ready_to_finish(c):
		return ""
	return _complete(c)


## Au pied du phare (dernière étape, le soir).
func try_place(place: String) -> bool:
	var c := current()
	if c.is_empty() or not c.get("night", false) or place != "phare":
		return false
	if not _ready_to_finish(c):
		EventBus.message_requested.emit("Le phare", "La lanterne est prête. Il faut revenir le soir, après 20h, pour l'allumer.")
		return true
	EventBus.dialogue_requested.emit("nina", _complete(c))
	return true


func _complete(c: Dictionary) -> String:
	var need: Dictionary = c.get("need", {})
	for item: String in need:
		Inventory.remove_item(item, int(need[item]))
	step += 1
	_fish_base = int(Story.stats.get("fish", 0))
	Sfx.play("levelup")
	if finished():
		PlayerState.flags["story_port"] = true  # recette débloquée, phare allumé
		Inventory.add_gold(int(data.get("reward_gold", 0)))
		EventBus.toast(str(data.get("reward_text", "")))
		EventBus.story_advanced.emit("port", str(data.get("title", "")))
	else:
		EventBus.toast("%s : étape %d/%d" % [data.get("title", ""), step + 1, steps().size()])
	changed.emit()
	return str(c.get("say", ""))


static func lighthouse_lit() -> bool:
	return PlayerState.flags.has("story_port")


func to_dict() -> Dictionary:
	return {"step": step, "fish_base": _fish_base}


func from_dict(saved: Dictionary) -> void:
	reset()
	step = clampi(int(saved.get("step", 0)), 0, steps().size())
	_fish_base = int(saved.get("fish_base", 0))
