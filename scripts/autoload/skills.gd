extends Node
## Compétences : agriculture, minage, pêche, combat, cueillette.
## Chaque action rapporte de l'expérience ; chaque niveau donne un bonus.

const NAMES := {
	"farming": "Agriculture", "mining": "Minage", "fishing": "Pêche",
	"combat": "Combat", "foraging": "Cueillette",
}
const PERKS := {
	"farming": "+5 % de chance de récolte double par niveau",
	"mining": "+6 % de chance de minerai en plus par niveau",
	"fishing": "Filet 3 % plus large par niveau",
	"combat": "+5 PV max par niveau",
	"foraging": "+6 % de chance de bois ou cueillette double par niveau",
}
## XP totale nécessaire pour chaque niveau (1 à 10).
const THRESHOLDS := [100, 300, 650, 1100, 1700, 2500, 3500, 4800, 6400, 8500]
const MAX_LEVEL := 10

var xp: Dictionary = {}


func reset() -> void:
	xp.clear()


func level(skill: String) -> int:
	var total := int(xp.get(skill, 0))
	var lvl := 0
	for t: int in THRESHOLDS:
		if total >= t:
			lvl += 1
	return lvl


## Progression vers le niveau suivant (0..1).
func progress(skill: String) -> float:
	var lvl := level(skill)
	if lvl >= MAX_LEVEL:
		return 1.0
	var low: int = 0 if lvl == 0 else THRESHOLDS[lvl - 1]
	var high: int = THRESHOLDS[lvl]
	return clampf(float(int(xp.get(skill, 0)) - low) / float(high - low), 0.0, 1.0)


func add_xp(skill: String, amount: int) -> void:
	var before := level(skill)
	xp[skill] = int(xp.get(skill, 0)) + amount
	var after := level(skill)
	if after > before:
		EventBus.toast("Niveau supérieur ! %s %d" % [NAMES[skill], after])
		Sfx.play("levelup")
		if skill == "combat":
			PlayerState.heal(0, 5)


## Tirage d'un bonus : chance = niveau x pourcentage.
func roll(skill: String, percent_per_level: float) -> bool:
	return randf() < level(skill) * percent_per_level / 100.0


func to_dict() -> Dictionary:
	return {"xp": xp.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("xp", {})
	for k: String in saved:
		xp[k] = int(saved[k])
