extends Node
## Le scénario : 5 chapitres (data/story.json) pour faire refleurir Valfleur.
## Chaque chapitre propose plusieurs voies (cultiver, se faire des amis,
## explorer la mine...) : une seule suffit pour avancer. Terminer un
## chapitre débloque des recettes (champ "unlock" de data/recipes.json),
## envoie une lettre avec une récompense et fait avancer l'histoire.

signal changed

## Compteurs d'actions : la progression d'un chapitre les compte depuis
## son ouverture. Les autres statistiques (habitants rencontrés, cœurs,
## profondeur de la mine, bâtiments) sont un état du monde.
const COUNTERS := ["harvest", "cleared", "earned", "gifts", "monsters", "ores", "fish", "cooked", "shipped", "products"]

var prologue: String = ""
var arrival: Array = []  # scène d'arrivée à Valfleur (nouvelle partie)
## Jouer la scène d'arrivée au début d'une nouvelle partie (désactivé
## pour les tests automatiques).
static var play_arrival: bool = true
var chapters: Array = []
var chapter: int = 0  # index du chapitre en cours (= nombre de chapitres terminés)
var stats: Dictionary = {}  # compteur -> total depuis le début de la partie
var _base: Dictionary = {}  # compteur -> valeur à l'ouverture du chapitre
var _check_timer: float = 0.0


func _ready() -> void:
	var file := FileAccess.open("res://data/story.json", FileAccess.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			prologue = str(data.get("prologue", ""))
			chapters = data.get("chapters", [])
			arrival = data.get("arrival", [])
	# Une lettre par chapitre terminé, déposée par le courrier
	for c: Dictionary in chapters:
		Mail.letters["story_" + str(c.id)] = {
			"from": c.get("from", ""), "when": {"flag": "story_" + str(c.id)},
			"text": c.get("letter", ""), "items": c.get("items", []),
		}
	reset()


func reset() -> void:
	chapter = 0
	stats.clear()
	_base.clear()


func finished() -> bool:
	return chapter >= chapters.size()


func current() -> Dictionary:
	return {} if finished() else chapters[chapter]


## Une recette est-elle débloquée ? (sans "unlock" : dès le début)
func is_unlocked(chapter_id: String) -> bool:
	if chapter_id == "":
		return true
	return PlayerState.flags.has("story_" + chapter_id)


func chapter_title(chapter_id: String) -> String:
	for i in chapters.size():
		if str(chapters[i].id) == chapter_id:
			return "Chapitre %d : %s" % [i + 1, chapters[i].title]
	return chapter_id


## Une action du joueur fait avancer un compteur.
func bump(stat: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	stats[stat] = int(stats.get(stat, 0)) + amount
	check()
	changed.emit()


## Valeur d'une statistique pour le chapitre en cours.
func value(stat: String) -> int:
	match stat:
		"met":
			return Relations.met.size()
		"hearts_max":
			var best := 0
			for id: String in GameData.npcs:
				best = maxi(best, Relations.hearts(id))
			return best
		"hearts_sum":
			var total := 0
			for id: String in GameData.npcs:
				total += Relations.hearts(id)
			return total
		"mine_depth":
			return int(PlayerState.flags.get("mine_deepest", 0))
		"buildings":
			var n := 0
			for id: String in Animals.buildings:
				if Animals.is_built(id) or Animals.under_construction(id):
					n += 1
			return n
	return int(stats.get(stat, 0)) - int(_base.get(stat, 0))


## Avancement (0 à 1) de la meilleure voie du chapitre en cours.
func progress() -> float:
	var best := 0.0
	for p: Dictionary in current().get("paths", []):
		best = maxf(best, minf(1.0, float(value(str(p.stat))) / float(p.goal)))
	return best


func check() -> void:
	if finished():
		return
	for p: Dictionary in current().get("paths", []):
		if value(str(p.stat)) >= int(p.goal):
			_complete(str(p.label))
			return


func _complete(path_label: String) -> void:
	var c: Dictionary = current()
	PlayerState.flags["story_" + str(c.id)] = true
	chapter += 1
	for stat: String in COUNTERS:
		_base[stat] = int(stats.get(stat, 0))
	Mail.check()
	Sfx.play("levelup")
	EventBus.story_advanced.emit(str(c.id), path_label)
	changed.emit()
	# Le chapitre suivant est peut-être déjà rempli (ex. mine déjà explorée)
	check.call_deferred()


func _process(delta: float) -> void:
	# Les statistiques d'état (cœurs, mine...) sont vérifiées régulièrement.
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 2.0
		if TimeManager.running:
			check()


func to_dict() -> Dictionary:
	return {"chapter": chapter, "stats": stats.duplicate(), "base": _base.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	chapter = clampi(int(data.get("chapter", 0)), 0, chapters.size())
	var s: Dictionary = data.get("stats", {})
	for k: String in s:
		stats[k] = int(s[k])
	var b: Dictionary = data.get("base", {})
	for k: String in b:
		_base[k] = int(b[k])
	changed.emit()
