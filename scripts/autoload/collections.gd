extends Node
## Collections : chaque objet obtenu pour la première fois (récolté, pêché,
## cueilli, cuisiné, extrait...) est inscrit dans l'album, par catégorie.
## Compléter la moitié puis la totalité d'une catégorie rapporte une
## récompense, envoyée aussitôt.

signal discovered(id: String, category: String)
## Un palier de collection est atteint (moitié ou totalité d'une catégorie)
signal milestone(category: String, full: bool, reward: int)

const MINERALS := ["coal", "copper_ore", "iron_ore", "gold_ore", "quartz", "amethyst", "emerald"]
const CATEGORIES := [
	{"id": "crops", "name": "Récoltes", "types": ["crop"], "reward": [300, 1500]},
	{"id": "forage", "name": "Cueillette", "types": ["forage"], "reward": [150, 600]},
	{"id": "fish", "name": "Poissons", "types": ["fish"], "reward": [200, 1000]},
	{"id": "animal", "name": "Élevage", "types": ["animal"], "reward": [150, 700]},
	{"id": "cooking", "name": "Cuisine", "types": ["food"], "reward": [250, 1200]},
	{"id": "mine", "name": "Mine", "types": ["loot"], "ids": MINERALS, "reward": [250, 1200]},
]

var found: Dictionary = {}  # id d'objet -> true
var rewarded: Dictionary = {}  # "crops_half" / "crops_full" -> true
var _by_category: Dictionary = {}  # catégorie -> [ids], dans l'ordre de items.json
var _category_of: Dictionary = {}  # id d'objet -> catégorie


func _ready() -> void:
	for c: Dictionary in CATEGORIES:
		_by_category[c.id] = []
	for id: String in GameData.items:
		var type := str(GameData.items[id].get("type", ""))
		for c: Dictionary in CATEGORIES:
			if type in c.types or id in c.get("ids", []):
				_by_category[c.id].append(id)
				_category_of[id] = c.id
				break


func reset() -> void:
	found.clear()
	rewarded.clear()


func category_of(id: String) -> String:
	return str(_category_of.get(id, ""))


func items_of(category: String) -> Array:
	return _by_category.get(category, [])


func count(category: String) -> int:
	var n := 0
	for id: String in items_of(category):
		if found.has(id):
			n += 1
	return n


func total() -> int:
	return _category_of.size()


func total_found() -> int:
	return found.size()


func category(category_id: String) -> Dictionary:
	for c: Dictionary in CATEGORIES:
		if c.id == category_id:
			return c
	return {}


## Inscrit un objet dans l'album. Renvoie true s'il est nouveau.
func discover(id: String) -> bool:
	var cat := category_of(id)
	if cat == "" or found.has(id):
		return false
	found[id] = true
	discovered.emit(id, cat)
	_check_milestones(cat)
	return true


func _check_milestones(cat: String) -> void:
	var c := category(cat)
	var have := count(cat)
	var size := items_of(cat).size()
	for full: bool in [false, true]:
		var key := cat + ("_full" if full else "_half")
		var needed := size if full else ceili(size / 2.0)
		if have >= needed and not rewarded.has(key):
			rewarded[key] = true
			var reward := int(c.reward[1 if full else 0])
			Inventory.add_gold(reward)
			milestone.emit(cat, full, reward)


func to_dict() -> Dictionary:
	return {"found": found.keys(), "rewarded": rewarded.keys()}


func from_dict(data: Dictionary) -> void:
	reset()
	for id: Variant in data.get("found", []):
		found[str(id)] = true
	for key: Variant in data.get("rewarded", []):
		rewarded[str(key)] = true
