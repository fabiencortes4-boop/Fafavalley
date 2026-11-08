extends Node
## Astuces contextuelles (data/guide.json) : chacune s'affiche une seule
## fois, au moment où le joueur découvre la fonction. Le guide complet est
## dans Menu > Guide.

signal requested(title: String, text: String)

var tips: Dictionary = {}
var guide: Array = []
var seen: Dictionary = {}
var _queue: Array = []
## Désactivées pendant les tests automatiques (pas de fenêtres surprises)
var enabled: bool = DisplayServer.get_name() != "headless"


func _ready() -> void:
	var file := FileAccess.open("res://data/guide.json", FileAccess.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			tips = data.get("tips", {})
			guide = data.get("guide", [])
	EventBus.inventory_changed.connect(_watch_inventory)


func reset() -> void:
	seen.clear()
	_queue.clear()


## Montre l'astuce `id` si elle n'a jamais été vue.
func show(id: String) -> void:
	if not enabled or seen.has(id) or not tips.has(id) or Tutorial.active():
		return
	seen[id] = true
	var t: Array = tips[id]
	_queue.append([str(t[0]), str(t[1])])


## Prochaine astuce en attente (le HUD l'affiche quand aucun menu n'est ouvert).
func pop() -> Array:
	return [] if _queue.is_empty() else _queue.pop_front()


func _watch_inventory() -> void:
	for slot: Variant in Inventory.slots:
		if slot == null:
			continue
		var id := str(slot.id)
		if id.contains("@"):
			show("quality")
		var place := str(GameData.item(id).get("place", ""))
		if place == "cask" or place == "oak_cask":
			show("cask")
		elif Machines.is_machine(place):
			show("machine")
		if GameData.item(id).get("type") == "tree_seed":
			show("woods")
		if id == "bait":
			show("bait")
		elif id == "crab_pot":
			show("crab_pot")


func to_dict() -> Dictionary:
	return {"seen": seen.keys()}


func from_dict(data: Dictionary) -> void:
	reset()
	for id: Variant in data.get("seen", []):
		seen[str(id)] = true
