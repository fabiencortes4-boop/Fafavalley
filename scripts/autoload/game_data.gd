extends Node
## Charge les données du jeu (objets, cultures) depuis data/*.json.
## Ajouter un objet ou une culture = ajouter une entrée JSON, sans code.

const ICONS_PATH := "res://assets/sprites/icons.png"
const ICON_SIZE := 16

var items: Dictionary = {}
var crops: Dictionary = {}
var _icon_cache: Dictionary = {}
var _icons_texture: Texture2D


func _ready() -> void:
	items = _load_json("res://data/items.json")
	crops = _load_json("res://data/crops.json")
	_icons_texture = load(ICONS_PATH)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Impossible d'ouvrir %s" % path)
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		return data
	push_error("JSON invalide : %s" % path)
	return {}


func item(id: String) -> Dictionary:
	return items.get(id, {})


func crop(id: String) -> Dictionary:
	return crops.get(id, {})


func item_name(id: String) -> String:
	return str(item(id).get("name", id))


func item_icon(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var tex := AtlasTexture.new()
	tex.atlas = _icons_texture
	var index := int(item(id).get("icon", 0))
	tex.region = Rect2(index * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	_icon_cache[id] = tex
	return tex


## Durée totale de croissance (en jours arrosés) d'une culture.
func crop_total_days(crop_id: String) -> int:
	var total := 0
	for d: Variant in crop(crop_id).get("stage_days", []):
		total += int(d)
	return total


func crop_in_season(crop_id: String, season: int) -> bool:
	for s: Variant in crop(crop_id).get("seasons", []):
		if int(s) == season:
			return true
	return false
