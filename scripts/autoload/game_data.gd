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
	if items.has(id):
		return items[id]
	if id.contains("@"):
		return _quality_item(id)
	return {}


# ------------------------------------------------------------ qualité
## Qualité des récoltes, poissons, cueillettes, fruits, fleurs et produits
## d'élevage : normale, argent, or, cristal. Un objet de qualité a pour
## identifiant « carotte@2 » ; il vaut plus cher et nourrit davantage.
## Inventory.count_of("carrot") compte toutes les qualités.
const QUALITY_NAMES := ["normale", "argent", "or", "cristal"]
const QUALITY_PRICE := [1.0, 1.25, 1.5, 2.0]
const QUALITY_COLORS := [Color(1, 1, 1), Color(0.82, 0.86, 0.95), Color(1.0, 0.8, 0.25), Color(0.55, 0.95, 1.0)]
const QUALITY_TYPES := ["crop", "fish", "forage", "animal"]
var _quality_cache: Dictionary = {}


static func base_id(id: String) -> String:
	return id.get_slice("@", 0)


static func quality_of(id: String) -> int:
	return clampi(int(id.get_slice("@", 1)), 0, 3) if id.contains("@") else 0


static func with_quality(id: String, quality: int) -> String:
	var base := base_id(id)
	return base if quality <= 0 else "%s@%d" % [base, mini(quality, 3)]


func has_quality(id: String) -> bool:
	return str(items.get(base_id(id), {}).get("type", "")) in QUALITY_TYPES


func _quality_item(id: String) -> Dictionary:
	if _quality_cache.has(id):
		return _quality_cache[id]
	var base: Dictionary = items.get(base_id(id), {})
	if base.is_empty():
		return {}
	var q := quality_of(id)
	var out := base.duplicate(true)
	out["quality"] = q
	out["base"] = base_id(id)
	out["name"] = "%s %s" % [base.get("name", id), ["", "★ argent", "★ or", "★ cristal"][q]]
	if base.has("sell"):
		out["sell"] = int(round(float(base.sell) * QUALITY_PRICE[q]))
	if base.has("edible"):
		var e: Array = base.edible
		out["edible"] = [int(round(float(e[0]) * (1.0 + 0.2 * q))), int(round(float(e[1]) * (1.0 + 0.2 * q)))]
	_quality_cache[id] = out
	return out


## Tire une qualité : `level` (0 à 10, compétence), `bonus` (0 à 1 : engrais,
## âge de l'arbre, bonheur de l'animal, taille du poisson...).
func roll_quality(level: int, bonus: float = 0.0, rng: RandomNumberGenerator = null) -> int:
	var r := randf() if rng == null else rng.randf()
	var crystal := 0.0
	if level >= 6 or bonus >= 0.5:
		crystal = 0.005 + 0.004 * level + 0.04 * bonus
	var gold := 0.02 + 0.012 * level + 0.12 * bonus
	var silver := 0.12 + 0.025 * level + 0.2 * bonus
	if r < crystal:
		return 3
	if r < crystal + gold:
		return 2
	if r < crystal + gold + silver:
		return 1
	return 0


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
	if id.contains("@"):
		# Objet de qualité : l'icône de base avec une étoile dans le coin
		_icon_cache[id] = _starred_icon(item_icon(base_id(id)), quality_of(id))
		return _icon_cache[id]
	var tex := AtlasTexture.new()
	tex.atlas = _icons_texture
	var index := int(item(id).get("icon", 0))
	tex.region = Rect2(index * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	_icon_cache[id] = tex
	return tex


## Petite étoile (argent, or ou cristal) en bas à gauche de l'icône.
func _starred_icon(base: Texture2D, quality: int) -> Texture2D:
	var img := base.get_image()
	if img == null:
		return base
	img = img.duplicate()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var fill: Color = QUALITY_COLORS[quality]
	var dark := Color(0.25, 0.15, 0.2)
	# Étoile 5x5 dans le coin, contour sombre puis remplissage
	var shape := ["..X..", ".XXX.", "XXXXX", ".XXX.", ".X.X."]
	var pts: Array[Vector2i] = []
	for y in shape.size():
		for x in 5:
			if shape[y][x] == "X":
				pts.append(Vector2i(x, 10 + y))
	for p: Vector2i in pts:
		for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var n := p + d
			if n.x >= 0 and n.x < 16 and n.y >= 0 and n.y < 16 and not n in pts:
				img.set_pixelv(n, dark)
	for p: Vector2i in pts:
		img.set_pixelv(p, fill)
	img.set_pixel(2, 11, fill.lightened(0.5))
	return ImageTexture.create_from_image(img)


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
