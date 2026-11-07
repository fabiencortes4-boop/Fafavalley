extends Node
## Charge les données du jeu (objets, cultures) depuis data/*.json.
## Ajouter un objet ou une culture = ajouter une entrée JSON, sans code.

const ICONS_PATH := "res://assets/sprites/icons.png"
const ICON_SIZE := 16

var items: Dictionary = {}
var crops: Dictionary = {}
var npcs: Dictionary = {}
var fishes: Dictionary = {}
var monsters: Dictionary = {}
var _icon_cache: Dictionary = {}
var _icons_texture: Texture2D


func _ready() -> void:
	items = _load_json("res://data/items.json")
	crops = _load_json("res://data/crops.json")
	npcs = _load_json("res://data/npcs.json")
	fishes = _load_json("res://data/fish.json")
	monsters = _load_json("res://data/monsters.json")
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


func fish(id: String) -> Dictionary:
	return fishes.get(id, {})


## Tire au sort un poisson disponible ici et maintenant (pondéré par "weight").
func pick_fish(place: String) -> String:
	var hour := TimeManager.minutes / 60.0
	var pool: Array = []
	var total := 0
	for id: String in fishes:
		var f: Dictionary = fishes[id]
		var hours: Array = f.get("hours", [6, 26])
		var weather := str(f.get("weather", "any"))
		if not place in f.get("places", []):
			continue
		if not float(TimeManager.season) in f.get("seasons", []):
			continue
		if hour < float(hours[0]) or hour >= float(hours[1]):
			continue
		if weather == "rain" and not TimeManager.is_raining():
			continue
		if weather == "sunny" and TimeManager.is_raining():
			continue
		total += int(f.get("weight", 1))
		pool.append(id)
	if pool.is_empty():
		return "roach"
	var roll := randi() % total
	for id: String in pool:
		roll -= int(fishes[id].get("weight", 1))
		if roll < 0:
			return id
	return pool[0]


func npc(id: String) -> Dictionary:
	return npcs.get(id, {})


## Portrait d'un habitant (sprite 16x16 de assets/sprites/npcs.png).
func npc_texture(id: String) -> Texture2D:
	var key := "npc:" + id
	if _icon_cache.has(key):
		return _icon_cache[key]
	# Portrait tiré du modèle 3D (tools/render_characters.gd --portraits),
	# pour que visage et corps se ressemblent ; sinon l'ancien sprite 2D.
	var portrait := "res://assets/sprites/portraits/%s.png" % id
	if ResourceLoader.exists(portrait):
		_icon_cache[key] = load(portrait)
		return _icon_cache[key]
	return npc_sprite(id)


## Petit sprite 16x16 de l'habitant (vue 2D).
func npc_sprite(id: String) -> Texture2D:
	var key := "npc_sprite:" + id
	if _icon_cache.has(key):
		return _icon_cache[key]
	var tex := AtlasTexture.new()
	tex.atlas = load("res://assets/sprites/npcs.png")
	tex.region = Rect2(int(npc(id).get("sprite", 0)) * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	_icon_cache[key] = tex
	return tex


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
