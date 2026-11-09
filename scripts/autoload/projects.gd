extends Node
## Rénovations du village : on finance des chantiers (or et matériaux) qui
## rouvrent un lieu et donnent un avantage durable.

signal changed

const PROJECTS := {
	"mill": {
		"name": "Le moulin", "gold": 8000, "materials": {"wood": 150, "stone": 80, "hardwood": 10},
		"text": "Remettre en marche le vieux moulin : le blé et le maïs expédiés se vendent 50 % plus cher.",
	},
	"bandstand": {
		"name": "Le kiosque à musique", "gold": 5000, "materials": {"wood": 120, "copper_ore": 10},
		"text": "Reconstruire le kiosque de la place : la musique met tout le monde de bonne humeur, parler aux habitants rapporte 50 % d'amitié en plus.",
	},
	"bridge": {
		"name": "Le vieux pont", "gold": 6000, "materials": {"wood": 100, "stone": 60, "iron_ore": 10},
		"text": "Réparer le pont de la rivière : les marchands reviennent, et Basile vend des graines hybrides à son comptoir.",
	},
}

## Emplacement de chaque chantier au village (cases).
const SITES := {
	"mill": Rect2i(48, 2, 3, 3),
	"bandstand": Rect2i(29, 32, 4, 3),
	"bridge": Rect2i(45, 33, 11, 1),
}
const WORK_DAYS := 3  # durée des travaux, en nuits

var done: Dictionary = {}  # id -> numéro du jour
var works: Dictionary = {}  # chantier en cours : id -> jour du début


func reset() -> void:
	done.clear()
	works.clear()


## "ruin" (à l'abandon), "works" (chantier en cours) ou "done".
func state(id: String) -> String:
	if done.has(id):
		return "done"
	return "works" if works.has(id) else "ruin"


## Le chantier qui occupe une case du village ("" sinon).
func site_at(cell: Vector2i) -> String:
	for id: String in SITES:
		if (SITES[id] as Rect2i).has_point(cell):
			return id
	return ""


## Jours de travaux restants.
func days_left(id: String) -> int:
	return maxi(0, WORK_DAYS - (Marriage.day_number() - int(works.get(id, 0))))


## Chaque nuit, les ouvriers avancent ; un chantier fini est inauguré.
func new_day() -> void:
	for id: String in works.keys():
		if days_left(id) <= 0:
			works.erase(id)
			done[id] = Marriage.day_number()
			var p: Dictionary = PROJECTS[id]
			Mail.send_custom("projet_" + id, {
				"from": "Bertrand, maire de Valfleur",
				"text": "%s est terminé ! Tout le village est venu voir. %s Merci pour ta générosité : Valfleur ne serait pas ce qu'elle est sans toi." % [p.name, p.text],
			})
	changed.emit()


func missing(id: String) -> Dictionary:
	var p: Dictionary = PROJECTS[id]
	var out := {}
	if Inventory.gold < int(p.gold):
		out["or"] = int(p.gold) - Inventory.gold
	for item: String in p.materials:
		var lack := int(p.materials[item]) - Inventory.count_of(item)
		if lack > 0:
			out[item] = lack
	return out


func fund(id: String) -> bool:
	if done.has(id) or works.has(id) or not missing(id).is_empty():
		return false
	var p: Dictionary = PROJECTS[id]
	Inventory.spend_gold(int(p.gold))
	for item: String in p.materials:
		Inventory.remove_item(item, int(p.materials[item]))
	works[id] = Marriage.day_number()
	Story.bump("projects")
	changed.emit()
	return true


## Prix d'expédition (le moulin valorise les céréales).
func sell_factor(item_id: String) -> float:
	return 1.5 if done.has("mill") and GameData.base_id(item_id) in ["wheat", "corn"] else 1.0


func talk_factor() -> float:
	return 1.5 if done.has("bandstand") else 1.0


func to_dict() -> Dictionary:
	return {"done": done.duplicate(), "works": works.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	var d: Dictionary = data.get("done", {})
	for k: String in d:
		done[k] = int(d[k])
	var w: Dictionary = data.get("works", {})
	for k: String in w:
		works[k] = int(w[k])
