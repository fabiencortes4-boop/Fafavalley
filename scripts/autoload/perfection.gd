extends Node
## La ferme parfaite : l'objectif de toute une vie à Valfleur. Huit domaines
## (album, amitiés, histoire, musée, rénovations, compétences, grotte, bilan
## de l'année) comptent chacun pour un huitième. À 100 %, le village offre
## une statue dorée à poser à la ferme.

signal changed

const FRIEND_HEARTS := 8  # cœurs visés avec chaque habitant
const BEST_STARS := 5


## [[nom, avancement de 0 à 1, détail], ...]
func criteria() -> Array:
	var out: Array = []
	out.append(["Album des collections", _ratio(Collections.total_found(), Collections.total()), "%d/%d objets" % [Collections.total_found(), Collections.total()]])
	var hearts := 0.0
	var friends := 0
	for id: String in GameData.npcs:
		hearts += minf(Relations.hearts(id), FRIEND_HEARTS)
		if Relations.hearts(id) >= FRIEND_HEARTS:
			friends += 1
	out.append(["Amitiés (%d cœurs)" % FRIEND_HEARTS, _ratio(int(hearts), GameData.npcs.size() * FRIEND_HEARTS), "%d/%d habitants" % [friends, GameData.npcs.size()]])
	out.append(["Histoire de la vallée", _ratio(Story.chapter, Story.chapters.size()), "chapitre %d/%d" % [mini(Story.chapter, Story.chapters.size()), Story.chapters.size()]])
	out.append(["Musée", _ratio(Museum.donated.size(), Museum.PIECES.size()), "%d/%d fossiles" % [Museum.donated.size(), Museum.PIECES.size()]])
	out.append(["Rénovations", _ratio(Projects.done.size(), Projects.PROJECTS.size()), "%d/%d chantiers" % [Projects.done.size(), Projects.PROJECTS.size()]])
	var levels := 0
	for s: String in Skills.NAMES:
		levels += Skills.level(s)
	out.append(["Compétences", _ratio(levels, Skills.NAMES.size() * Skills.MAX_LEVEL), "%d/%d niveaux" % [levels, Skills.NAMES.size() * Skills.MAX_LEVEL]])
	out.append(["Grotte des lucioles", 1.0 if PlayerState.flags.has("cave_chest") else 0.0, "trésor trouvé" if PlayerState.flags.has("cave_chest") else "trésor caché"])
	var best := 0
	for h: Variant in YearReview.history:
		best = maxi(best, int((h as Array)[1]))
	out.append(["Bilan de l'année", _ratio(best, BEST_STARS), "meilleure note : %d/%d étoiles" % [best, BEST_STARS]])
	return out


func _ratio(a: int, b: int) -> float:
	return 1.0 if b <= 0 else clampf(float(a) / b, 0.0, 1.0)


## Pourcentage de perfection (0 à 100).
func percent() -> int:
	var c := criteria()
	var sum := 0.0
	for e: Array in c:
		sum += float(e[1])
	return int(floor(sum / c.size() * 100.0 + 0.0001))


func achieved() -> bool:
	return PlayerState.flags.has("perfection")


## Chaque matin : la ferme est-elle devenue parfaite ?
func check() -> bool:
	if achieved() or percent() < 100:
		return false
	PlayerState.flags["perfection"] = true
	Mail.send_custom("perfection", {
		"from": "Tout le village de Valfleur",
		"text": "Toute la vallée en parle : ta ferme est parfaite. Les champs, les bêtes, le musée, le moulin, les amitiés... Firmin serait si fier. Pour te dire merci, Gaston a fondu cette statue dorée, et Lina l'a peinte. Pose-la où tu veux à la ferme : elle sera là pour toujours.",
		"items": [["golden_statue", 1]],
	})
	changed.emit()
	return true
