extends Node
## Défi du jour : un petit objectif chaque matin (récolter, pêcher, abattre,
## cuisiner...), suivi par les compteurs de l'histoire. Réussi, il rapporte
## de l'or tout de suite. Un but court pour chaque partie sur téléphone.

signal changed

## [compteur, texte, quantité min, max, or par unité, condition]
const TEMPLATES := [
	["harvest", "Récolte %d cultures", 6, 14, 15, ""],
	["fish", "Pêche %d poissons", 3, 6, 40, ""],
	["cleared", "Défriche %d herbes, branches ou pierres", 8, 18, 8, ""],
	["gifts", "Offre %d cadeaux à des habitants", 2, 3, 60, ""],
	["cooked", "Cuisine %d plats", 1, 3, 70, ""],
	["products", "Récupère %d produits (machines ou animaux)", 2, 5, 35, "products"],
	["trees_felled", "Abats %d arbres en forêt ou à la ferme", 2, 4, 60, "story_ch1"],
	["ores", "Casse %d rochers à minerai", 3, 7, 30, "story_ch2"],
	["monsters", "Bats %d monstres dans la mine", 4, 9, 20, "story_ch2"],
]

var today: Dictionary = {}  # {"stat", "text", "goal", "base", "gold", "done"}
var streak: int = 0  # défis réussis d'affilée


func _ready() -> void:
	Story.changed.connect(check)


func reset() -> void:
	today.clear()
	streak = 0
	new_day()


func _available(t: Array) -> bool:
	match str(t[5]):
		"":
			return true
		"products":
			return not Animals.animals.is_empty() or not Machines.state.is_empty()
	return PlayerState.flags.has(str(t[5]))


## Nouveau défi (le matin). Un défi manqué remet la série à zéro.
func new_day() -> void:
	if not today.is_empty() and not bool(today.get("done", false)):
		streak = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["defi", TimeManager.year, TimeManager.season, TimeManager.day])
	var pool := TEMPLATES.filter(_available)
	var t: Array = pool[rng.randi() % pool.size()]
	var goal := rng.randi_range(int(t[2]), int(t[3]))
	today = {
		"stat": str(t[0]), "text": str(t[1]) % goal, "goal": goal,
		"base": int(Story.stats.get(str(t[0]), 0)), "gold": goal * int(t[4]) + 50, "done": false,
	}
	changed.emit()


func progress() -> int:
	if today.is_empty():
		return 0
	return clampi(int(Story.stats.get(str(today.stat), 0)) - int(today.base), 0, int(today.goal))


func check() -> void:
	if today.is_empty() or bool(today.done) or progress() < int(today.goal):
		changed.emit()
		return
	today.done = true
	streak += 1
	# Série : +10 % par jour réussi d'affilée (jusqu'à +50 %)
	var gold := int(int(today.gold) * (1.0 + 0.1 * mini(streak - 1, 5)))
	Inventory.add_gold(gold)
	Sfx.play("achievement")
	EventBus.toast("Défi du jour réussi : %s ! +%d or%s" % [str(today.text).to_lower(), gold, "  (série de %d jours)" % streak if streak > 1 else ""])
	changed.emit()


func summary() -> String:
	if today.is_empty():
		return ""
	if bool(today.done):
		return "Défi du jour réussi : %s." % today.text
	return "%s : %d/%d  (+%d or)" % [today.text, progress(), int(today.goal), int(today.gold)]


func to_dict() -> Dictionary:
	return {"today": today.duplicate(), "streak": streak}


func from_dict(data: Dictionary) -> void:
	today = (data.get("today", {}) as Dictionary).duplicate()
	streak = int(data.get("streak", 0))
	if today.is_empty():
		new_day()
	changed.emit()
