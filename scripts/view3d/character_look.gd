class_name CharacterLook
extends RefCounted
## Apparence du personnage joueur, choisie dans l'éditeur : sexe, peau,
## coupe et couleur de cheveux, pilosité, yeux, haut, bas. La texture du
## modèle Blocky (Kenney, 256 px) est générée à la volée :
## - la tête est peinte pixel par pixel (6 faces de 32 px : dessus, côtés,
##   visage, arrière, dessous) : peau, yeux, sourcils, bouche, cheveux, barbe ;
## - le corps vient d'une texture de base (homme : sweat, femme : tunique),
##   recolorée (haut, bas, peau des bras), ombres comprises.

const SIZE := 256
const FACE := 32
## Faces de la tête (coin haut-gauche) dans la texture
const TOP := Vector2i(32, 0)
const SIDE_R := Vector2i(0, 32)
const FRONT := Vector2i(32, 32)
const SIDE_L := Vector2i(64, 32)
const BACK := Vector2i(96, 32)
const BOTTOM := Vector2i(32, 64)

const SEXES := ["Homme", "Femme"]
const SKINS := [Color("f6d1a5"), Color("e8b88a"), Color("d39a6a"), Color("b07850"), Color("8d5641"), Color("5e3a2a")]
const HAIR_STYLES := ["Court", "Rasé", "Mèche", "Afro", "Carré", "Long", "Chignon", "Chauve"]
const HAIR_COLORS := [Color("2a2420"), Color("5a3a24"), Color("8a5a34"), Color("c48a4a"), Color("e8c86a"), Color("b0452c"), Color("d8d6d0"), Color("4a6ac8")]
const HAIR_COLOR_NAMES := ["Noir", "Brun", "Châtain", "Caramel", "Blond", "Roux", "Blanc", "Bleu"]
const BEARDS := ["Aucune", "Moustache", "Bouc", "Barbe courte", "Barbe longue", "Favoris"]
const EYES := [Color("4a3020"), Color("3a6ab0"), Color("4a8a4a"), Color("8a8a8a")]
const EYE_NAMES := ["Marron", "Bleus", "Verts", "Gris"]
const CLOTHES := [Color("cb4248"), Color("3f6fb8"), Color("4f9a5a"), Color("e0b844"), Color("8a3ab0"), Color("e08a3a"), Color("f0ece0"), Color("3a3a44")]
const CLOTHES_NAMES := ["Rouge", "Bleu", "Vert", "Jaune", "Violet", "Orange", "Blanc", "Noir"]
const PANTS := [Color("4a5a8a"), Color("3a3a44"), Color("6b5a3a"), Color("2e4a7a"), Color("8a8a7a"), Color("5a7a4a")]
const PANTS_NAMES := ["Jean", "Noir", "Velours", "Marine", "Gris", "Kaki"]

## Options : index dans chaque liste
const KEYS := ["sex", "skin", "hair", "hair_color", "beard", "eyes", "top", "pants"]

static var _cache: Dictionary = {}


static func default_look() -> Dictionary:
	return {"sex": 0, "skin": 1, "hair": 0, "hair_color": 1, "beard": 0, "eyes": 0, "top": 2, "pants": 0}


static func random_look() -> Dictionary:
	var sex := randi() % 2
	return {
		"sex": sex, "skin": randi() % SKINS.size(),
		"hair": [0, 1, 2, 3, 7][randi() % 5] if sex == 0 else [3, 4, 5, 6][randi() % 4],
		"hair_color": randi() % (HAIR_COLORS.size() - 1), "beard": randi() % BEARDS.size() if sex == 0 and randf() < 0.6 else 0,
		"eyes": randi() % EYES.size(), "top": randi() % CLOTHES.size(), "pants": randi() % PANTS.size(),
	}


## Nombre de choix et libellé de l'option `key` à l'index `i`.
static func count(key: String) -> int:
	return {"sex": 2, "skin": SKINS.size(), "hair": HAIR_STYLES.size(), "hair_color": HAIR_COLORS.size(),
		"beard": BEARDS.size(), "eyes": EYES.size(), "top": CLOTHES.size(), "pants": PANTS.size()}.get(key, 1)


static func label(key: String, i: int) -> String:
	match key:
		"sex":
			return SEXES[i]
		"skin":
			return "Teinte %d" % (i + 1)
		"hair":
			return HAIR_STYLES[i]
		"hair_color":
			return HAIR_COLOR_NAMES[i]
		"beard":
			return BEARDS[i]
		"eyes":
			return EYE_NAMES[i]
		"top":
			return CLOTHES_NAMES[i]
		"pants":
			return PANTS_NAMES[i]
	return str(i)


static func _opt(look: Dictionary, key: String) -> int:
	return clampi(int(look.get(key, default_look()[key])), 0, count(key) - 1)


## Texture du personnage pour cette apparence (mise en cache).
static func texture(look: Dictionary) -> ImageTexture:
	var key := ",".join(KEYS.map(func(k: String) -> String: return str(_opt(look, k))))
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(image(look))
	_cache[key] = tex
	return tex


static func image(look: Dictionary) -> Image:
	var female := _opt(look, "sex") == 1
	var base: Texture2D = load("res://assets/kenney3d/blocky/Textures/texture-%s.png" % ("f" if female else "b"))
	var img := base.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
	var skin: Color = SKINS[_opt(look, "skin")]
	# La mèche de la tunique de base : cheveux longs, ou cachée par le haut
	var long_hair: bool = HAIR_STYLES[_opt(look, "hair")] in ["Long", "Carré"]
	var lock: Color = HAIR_COLORS[_opt(look, "hair_color")] if long_hair else CLOTHES[_opt(look, "top")]
	_recolor_body(img, female, skin, CLOTHES[_opt(look, "top")], PANTS[_opt(look, "pants")], lock)
	_paint_head(img, look, female, skin)
	return img


# ------------------------------------------------------------ corps
## Couleurs de la texture de base : peau, haut, bas
const BODY_KEYS := {
	false: {"skin": Color("8d5641"), "top": [Color("cb4248"), Color("d24349"), Color("a8343a")], "pants": [Color("6078cc"), Color("4a5ea8")]},
	true: {"skin": Color("8d5641"), "top": [Color("58bd98"), Color("46a07e")], "pants": [Color("8494c9"), Color("6878a8")]},
}


static func _recolor_body(img: Image, female: bool, skin: Color, top: Color, pants: Color, lock: Color) -> void:
	var keys: Dictionary = BODY_KEYS[female]
	var targets: Array = [[keys.skin, skin]]
	if female:
		targets.append([Color("3c3c44"), lock])
	for c: Color in keys.top:
		targets.append([c, top])
	for c: Color in keys.pants:
		targets.append([c, pants])
	for y in range(96, SIZE):
		for x in SIZE:
			var c := img.get_pixel(x, y)
			for t: Array in targets:
				var src: Color = t[0]
				var lum := (c.r + c.g + c.b) / maxf(0.01, src.r + src.g + src.b)
				if absf(lum - 1.0) > 0.4:
					continue
				var d := Vector3(c.r - src.r * lum, c.g - src.g * lum, c.b - src.b * lum).length()
				if d < 0.09:
					var dst: Color = t[1]
					img.set_pixel(x, y, Color(clampf(dst.r * lum, 0, 1), clampf(dst.g * lum, 0, 1), clampf(dst.b * lum, 0, 1)))
					break


# ------------------------------------------------------------ tête
static func _paint_head(img: Image, look: Dictionary, female: bool, skin: Color) -> void:
	var hair: Color = HAIR_COLORS[_opt(look, "hair_color")]
	var style: String = HAIR_STYLES[_opt(look, "hair")]
	var beard: String = BEARDS[_opt(look, "beard")]
	# Fond de la zone tête, puis la peau sur les 6 faces
	img.fill_rect(Rect2i(0, 0, 128, 96), Color("1e1e23"))
	for f: Vector2i in [TOP, SIDE_R, FRONT, SIDE_L, BACK, BOTTOM]:
		img.fill_rect(Rect2i(f, Vector2i(FACE, FACE)), skin)
	img.fill_rect(Rect2i(BOTTOM, Vector2i(FACE, FACE)), skin.darkened(0.12))
	# Oreilles sur les côtés
	for f: Vector2i in [SIDE_R, SIDE_L]:
		img.fill_rect(Rect2i(f + Vector2i(12, 14), Vector2i(8, 8)), skin.darkened(0.1))
		img.fill_rect(Rect2i(f + Vector2i(14, 16), Vector2i(4, 4)), skin.darkened(0.22))
	_paint_face(img, look, female, skin, hair)
	_paint_hair(img, style, hair)
	_paint_beard(img, beard, hair)


static func _paint_face(img: Image, look: Dictionary, female: bool, skin: Color, hair: Color) -> void:
	var o := FRONT
	var eye: Color = EYES[_opt(look, "eyes")]
	for ex: int in [8, 20]:
		img.fill_rect(Rect2i(o + Vector2i(ex, 16), Vector2i(4, 4)), Color(0.97, 0.97, 0.97))
		img.fill_rect(Rect2i(o + Vector2i(ex + (2 if ex < 16 else 0), 16), Vector2i(2, 4)), eye)
		img.fill_rect(Rect2i(o + Vector2i(ex + (2 if ex < 16 else 0), 16), Vector2i(1, 1)), Color(1, 1, 1))
		# Sourcils (plus fins et arqués pour une femme), cils
		if female:
			img.fill_rect(Rect2i(o + Vector2i(ex, 13), Vector2i(4, 1)), hair.darkened(0.2))
			img.fill_rect(Rect2i(o + Vector2i(ex + (0 if ex < 16 else 3), 15), Vector2i(1, 1)), Color(0.1, 0.08, 0.08))
		else:
			img.fill_rect(Rect2i(o + Vector2i(ex - 1, 13), Vector2i(6, 2)), hair.darkened(0.25))
	# Nez et bouche
	img.fill_rect(Rect2i(o + Vector2i(15, 20), Vector2i(2, 3)), skin.darkened(0.15))
	img.fill_rect(Rect2i(o + Vector2i(13, 25), Vector2i(6, 1)), Color(0.55, 0.25, 0.22) if not female else Color(0.78, 0.3, 0.35))
	img.fill_rect(Rect2i(o + Vector2i(14, 26), Vector2i(4, 1)), skin.darkened(0.08))
	# Joues roses
	if female:
		for cx: int in [6, 23]:
			img.fill_rect(Rect2i(o + Vector2i(cx, 21), Vector2i(3, 2)), skin.lerp(Color(0.95, 0.5, 0.5), 0.35))


## Cheveux : une couleur avec des mèches plus sombres (texture), face par face.
static func _hair_px(img: Image, p: Vector2i, hair: Color) -> void:
	var dark := (p.x * 3 + p.y * 5) % 7 == 0 or (p.x + p.y * 2) % 11 == 0
	img.set_pixelv(p, hair.darkened(0.18) if dark else hair)


static func _fill_hair(img: Image, face: Vector2i, rect: Rect2i, hair: Color) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x >= 0 and x < FACE and y >= 0 and y < FACE:
				_hair_px(img, face + Vector2i(x, y), hair)


static func _paint_hair(img: Image, style: String, hair: Color) -> void:
	if style == "Chauve":
		img.fill_rect(Rect2i(TOP + Vector2i(10, 10), Vector2i(4, 3)), Color(1, 1, 1, 1).lerp(img.get_pixelv(TOP + Vector2i(1, 1)), 0.6))
		return
	var full := Rect2i(0, 0, FACE, FACE)
	_fill_hair(img, TOP, full, hair)
	match style:
		"Rasé":
			for f: Vector2i in [SIDE_R, SIDE_L]:
				_fill_hair(img, f, Rect2i(0, 0, FACE, 6), hair.lerp(Color(0.5, 0.5, 0.5), 0.15))
			_fill_hair(img, FRONT, Rect2i(0, 0, FACE, 4), hair.lerp(Color(0.5, 0.5, 0.5), 0.15))
			_fill_hair(img, BACK, Rect2i(0, 0, FACE, 12), hair.lerp(Color(0.5, 0.5, 0.5), 0.15))
		"Court", "Mèche":
			_fill_hair(img, FRONT, Rect2i(0, 0, FACE, 7), hair)
			_fill_hair(img, FRONT, Rect2i(0, 0, 3, 14), hair)
			_fill_hair(img, FRONT, Rect2i(29, 0, 3, 14), hair)
			for f: Vector2i in [SIDE_R, SIDE_L]:
				_fill_hair(img, f, Rect2i(0, 0, FACE, 12), hair)
				_fill_hair(img, f, Rect2i(0, 12, 10, 6), hair)
				_fill_hair(img, f, Rect2i(22, 12, 10, 6), hair)
			_fill_hair(img, BACK, Rect2i(0, 0, FACE, 20), hair)
			if style == "Mèche":
				# Une mèche qui tombe en biais sur le front
				for y in range(7, 13):
					_fill_hair(img, FRONT, Rect2i(0, y, 18 - (y - 7) * 2, 1), hair)
		"Afro":
			_fill_hair(img, FRONT, Rect2i(0, 0, FACE, 10), hair)
			_fill_hair(img, FRONT, Rect2i(0, 0, 4, 20), hair)
			_fill_hair(img, FRONT, Rect2i(28, 0, 4, 20), hair)
			for f: Vector2i in [SIDE_R, SIDE_L]:
				_fill_hair(img, f, Rect2i(0, 0, FACE, 13), hair)
				_fill_hair(img, f, Rect2i(0, 13, 11, 10), hair)
				_fill_hair(img, f, Rect2i(21, 13, 11, 10), hair)
			_fill_hair(img, BACK, full, hair)
			# Boucles : petits points clairs
			for f: Vector2i in [TOP, FRONT, SIDE_R, SIDE_L, BACK]:
				for y in range(0, FACE, 4):
					for x in range((y / 4) % 2 * 2, FACE, 4):
						if img.get_pixelv(f + Vector2i(x, y)).is_equal_approx(hair) or img.get_pixelv(f + Vector2i(x, y)).is_equal_approx(hair.darkened(0.18)):
							img.set_pixelv(f + Vector2i(x, y), hair.lightened(0.15))
		"Carré", "Long":
			var bottom := 24 if style == "Carré" else FACE
			_fill_hair(img, FRONT, Rect2i(0, 0, FACE, 8), hair)
			_fill_hair(img, FRONT, Rect2i(0, 0, 5, bottom), hair)
			_fill_hair(img, FRONT, Rect2i(27, 0, 5, bottom), hair)
			for f: Vector2i in [SIDE_R, SIDE_L]:
				_fill_hair(img, f, Rect2i(0, 0, FACE, bottom), hair)
			_fill_hair(img, BACK, Rect2i(0, 0, FACE, bottom), hair)
		"Chignon":
			_fill_hair(img, FRONT, Rect2i(0, 0, FACE, 6), hair)
			for f: Vector2i in [SIDE_R, SIDE_L]:
				_fill_hair(img, f, Rect2i(0, 0, FACE, 11), hair)
			_fill_hair(img, BACK, Rect2i(0, 0, FACE, 22), hair)
			# Le chignon, plus sombre, en haut de la nuque
			img.fill_rect(Rect2i(BACK + Vector2i(10, 4), Vector2i(12, 10)), hair.darkened(0.3))
			img.fill_rect(Rect2i(TOP + Vector2i(10, 0), Vector2i(12, 10)), hair.darkened(0.3))


static func _paint_beard(img: Image, beard: String, hair: Color) -> void:
	match beard:
		"Moustache":
			_fill_hair(img, FRONT, Rect2i(11, 23, 10, 2), hair)
		"Bouc":
			_fill_hair(img, FRONT, Rect2i(11, 23, 10, 2), hair)
			_fill_hair(img, FRONT, Rect2i(13, 27, 6, 5), hair)
			_fill_hair(img, BOTTOM, Rect2i(13, 0, 6, 6), hair)
		"Barbe courte", "Barbe longue":
			_fill_hair(img, FRONT, Rect2i(3, 22, 26, 3), hair)
			_fill_hair(img, FRONT, Rect2i(3, 25, 10, 7), hair)
			_fill_hair(img, FRONT, Rect2i(19, 25, 10, 7), hair)
			_fill_hair(img, FRONT, Rect2i(13, 27, 6, 5), hair)
			for f: Vector2i in [SIDE_R, SIDE_L]:
				_fill_hair(img, f, Rect2i(0, 22, FACE, 10), hair)
			_fill_hair(img, BOTTOM, Rect2i(0, 0, FACE, 16 if beard == "Barbe courte" else FACE), hair)
		"Favoris":
			for f: Vector2i in [SIDE_R, SIDE_L]:
				_fill_hair(img, f, Rect2i(0, 10, 8, 16), hair)
				_fill_hair(img, f, Rect2i(24, 10, 8, 16), hair)
			_fill_hair(img, FRONT, Rect2i(0, 10, 3, 14), hair)
			_fill_hair(img, FRONT, Rect2i(29, 10, 3, 14), hair)
