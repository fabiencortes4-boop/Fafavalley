extends Node
## Bilan de l'année : le premier matin du printemps, Bertrand envoie une
## lettre qui note la ferme sur l'année écoulée (de 1 à 5 étoiles), avec
## un commentaire par domaine, de l'or et le Trophée de Valfleur.
## Donne un objectif à long terme : faire mieux chaque année.

## Domaines notés : [nom, statistique, paliers pour 1, 2, 3 et 4 points]
const CATEGORIES := [
	["Ventes", "earned", [3000, 15000, 40000, 90000]],
	["Récoltes expédiées", "shipped", [100, 400, 1000, 2500]],
	["Amitiés", "hearts_sum", [15, 40, 70, 100]],
	["Album des collections", "collection", [20, 45, 75, 110]],
	["Élevage", "animals", [1, 3, 6, 8]],
	["Histoire de la vallée", "chapter", [1, 2, 4, 5]],
]
const GOLD_PER_STAR := 600

## Valeur des compteurs au dernier bilan (ventes et récoltes : on ne note
## que l'année écoulée)
var _last: Dictionary = {}
## Bilans passés : [année, étoiles]
var history: Array = []


func reset() -> void:
	_last.clear()
	history.clear()


## Valeur actuelle d'un domaine (sur l'année pour les compteurs).
func value(stat: String) -> int:
	var v: int
	match stat:
		"animals":
			v = Animals.animals.size()
		"collection":
			v = Collections.total_found()
		_:
			v = Achievements.value(stat)
	if stat in ["earned", "shipped"]:
		v -= int(_last.get(stat, 0))
	return maxi(v, 0)


## Note de chaque domaine (0 à 4) et nombre d'étoiles (1 à 5).
func evaluate() -> Dictionary:
	var lines: Array = []
	var total := 0
	for c: Array in CATEGORIES:
		var v := value(str(c[1]))
		var pts := 0
		for limit: int in c[2]:
			if v >= limit:
				pts += 1
		total += pts
		lines.append([str(c[0]), v, pts])
	var stars := clampi(1 + total / 5, 1, 5)
	return {"lines": lines, "points": total, "stars": stars}


## Appelé au changement d'année : écrit la lettre et remet les compteurs.
func new_year(year_ended: int) -> void:
	var r := evaluate()
	var stars: int = r.stars
	var text := "Voici le bilan de la ferme pour l'année %d, comme le veut la tradition de Valfleur :\n\n" % year_ended
	for line: Array in r.lines:
		text += "%s : %d/4  (%d)\n" % [line[0], int(line[2]), int(line[1])]
	text += "\nNote finale : %d étoile%s sur 5\n\n%s" % [stars, "s" if stars > 1 else "", [
		"",
		"Un début modeste, mais chaque saison compte. L'an prochain sera meilleur, j'en suis sûr !",
		"La ferme reprend vie. Le village le sent : continue comme ça !",
		"Une belle année ! Valfleur te doit déjà beaucoup.",
		"Une année remarquable. On parle de ta ferme jusqu'au port !",
		"Une année légendaire. Firmin lui-même n'avait jamais fait mieux. Merci, du fond du cœur.",
	][stars]]
	text += "\n\nJe joins %d pièces d'or et le Trophée de Valfleur." % (stars * GOLD_PER_STAR)
	Mail.send_custom("year_review_%d" % year_ended, {
		"from": Soul.mayor_from(),
		"text": text,
		"items": [["gold", stars * GOLD_PER_STAR], ["valfleur_trophy", 1]],
	})
	history.append([year_ended, stars])
	if stars >= 5:
		PlayerState.flags["farm_5_stars"] = true
	for stat: String in ["earned", "shipped"]:
		_last[stat] = Achievements.value(stat)


func to_dict() -> Dictionary:
	return {"last": _last.duplicate(), "history": history.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	reset()
	var last: Dictionary = data.get("last", {})
	for k: String in last:
		_last[k] = int(last[k])
	for h: Variant in data.get("history", []):
		history.append(h)
