extends Node
## Fabrication (Menu) et forge de Gaston (enclume du village) :
## recettes de data/recipes.json. Une recette « upgrade » remplace l'outil
## d'origine dans l'inventaire (même case).

var recipes: Dictionary = {}


func _ready() -> void:
	var file := FileAccess.open("res://data/recipes.json", FileAccess.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			recipes = data


func for_station(station: String) -> Array:
	var ids: Array = []
	for id: String in recipes:
		if recipes[id].get("station", "craft") == station:
			ids.append(id)
	return ids


## Ingrédients manquants : {objet: quantité manquante}. "or" pour l'argent,
## "outil" si l'outil à améliorer est absent.
func missing(id: String) -> Dictionary:
	var r: Dictionary = recipes.get(id, {})
	var out := {}
	var ingredients: Dictionary = r.get("ingredients", {})
	for item: String in ingredients:
		var lack := int(ingredients[item]) - Inventory.count_of(item)
		if lack > 0:
			out[item] = lack
	var gold := int(r.get("gold", 0))
	if Inventory.gold < gold:
		out["or"] = gold - Inventory.gold
	var upgrade := str(r.get("upgrade", ""))
	if upgrade != "" and Inventory.count_of(upgrade) == 0:
		out["outil"] = upgrade
	return out


## Recette débloquée par l'histoire ?
func is_unlocked(id: String) -> bool:
	return Story.is_unlocked(str(recipes.get(id, {}).get("unlock", "")))


func can_craft(id: String) -> bool:
	if not is_unlocked(id) or not missing(id).is_empty():
		return false
	var r: Dictionary = recipes.get(id, {})
	# Une amélioration prend la place de l'outil : pas besoin de place libre.
	return r.has("upgrade") or Inventory.can_add(id, int(r.get("count", 1)))


## Qualité du dernier plat cuisiné (pour l'afficher)
var last_quality: int = 0


func craft(id: String) -> bool:
	if not can_craft(id):
		return false
	var r: Dictionary = recipes[id]
	var ingredients: Dictionary = r.get("ingredients", {})
	# Cuisine : un plat prend la qualité moyenne de ses ingrédients (on
	# utilise toujours d'abord les moins bons)
	var cooking: bool = r.get("category", "") == "Cuisine"
	var quality_sum := 0
	var quality_count := 0
	for item: String in ingredients:
		if cooking and GameData.has_quality(item):
			for q in Inventory.lowest_qualities(item, int(ingredients[item])):
				quality_sum += q
				quality_count += 1
		Inventory.remove_item(item, int(ingredients[item]))
	var dish_quality := quality_sum / quality_count if quality_count > 0 else 0
	if int(r.get("gold", 0)) > 0:
		Inventory.spend_gold(int(r.gold))
	if r.has("upgrade"):
		Inventory.replace_item(str(r.upgrade), id)
	else:
		Inventory.add_item(GameData.with_quality(id, dish_quality) if cooking else id, int(r.get("count", 1)))
	last_quality = dish_quality if cooking else 0
	if r.get("category", "") == "Cuisine":
		Story.bump("cooked")
	return true
