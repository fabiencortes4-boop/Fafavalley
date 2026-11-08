extends Node
## Succès (data/achievements.json) : des objectifs au long cours, vérifiés
## après chaque action comptée et régulièrement pour les états du monde.
## Chaque succès débloqué s'affiche, sonne et peut rapporter de l'or.

signal unlocked(id: String)

var list: Array = []
var done: Dictionary = {}  # id -> numéro de jour du déblocage
var _check_timer: float = 0.0


func _ready() -> void:
	var file := FileAccess.open("res://data/achievements.json", FileAccess.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Array:
			list = data
	Story.changed.connect(check)
	Collections.discovered.connect(func(_id: String, _c: String) -> void: check())


func reset() -> void:
	done.clear()


func get_achievement(id: String) -> Dictionary:
	for a: Dictionary in list:
		if a.id == id:
			return a
	return {}


## Valeur actuelle d'une statistique de succès (totaux de la partie).
func value(stat: String) -> int:
	if stat.begins_with("flag:"):
		return 1 if PlayerState.flags.has(stat.trim_prefix("flag:")) else 0
	match stat:
		"met", "hearts_max", "hearts_sum", "mine_depth", "buildings":
			return Story.value(stat)
		"chapter":
			return Story.chapter
		"port":
			return 1 if PortStory.finished() else 0
		"married":
			return 1 if Marriage.spouse != "" else 0
		"fish_species":
			return FishLog.caught.size()
		"legends":
			var n := 0
			for id: String in GameData.fishes:
				if GameData.fish(id).get("legendary", false) and FishLog.caught.has(id):
					n += 1
			return n
		"collection":
			return Collections.total_found()
		"collection_full":
			var n := 0
			for c: Dictionary in Collections.CATEGORIES:
				if Collections.rewarded.has(str(c.id) + "_full"):
					n += 1
			return n
		"skill_max":
			var best := 0
			for s: String in Skills.NAMES:
				best = maxi(best, Skills.level(s))
			return best
	return int(Story.stats.get(stat, 0))


func progress(a: Dictionary) -> float:
	return clampf(float(value(str(a.stat))) / maxf(1.0, float(a.goal)), 0.0, 1.0)


func check() -> void:
	for a: Dictionary in list:
		if not done.has(a.id) and value(str(a.stat)) >= int(a.goal):
			done[a.id] = Marriage.day_number()
			var gold := int(a.get("gold", 0))
			if gold > 0:
				Inventory.add_gold(gold)
			unlocked.emit(str(a.id))


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 3.0
		if TimeManager.running:
			check()


func to_dict() -> Dictionary:
	return {"done": done.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("done", {})
	for id: String in saved:
		done[id] = int(saved[id])
