class_name View3D
extends Node3D
## Affichage 3D d'une carte (modèles Kenney). La logique du jeu reste celle
## des cartes 2D (grille, collisions, actions) : cette vue la « met en
## scène » en 3D et se synchronise à chaque image. Une case = une unité 3D.

const UNIT := 16.0  # pixels 2D par case
const CAMERA_PITCH := deg_to_rad(55.0)
const CHARACTER_SCALE := 0.42
const TOOL_SIZE := 0.6  # longueur des outils tenus en main (en cases)

static var current: View3D

var map: WorldMap

var camera: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _lantern: OmniLight3D
var _static: Node3D
var _cells: Dictionary = {}  # Vector2i -> Node3D (terre, culture, objet, débris)
var _proxies: Dictionary = {}  # id d'instance 2D -> Node3D
var _rocks: Dictionary = {}  # Vector2i -> Node3D (mine)
var _player3d: Node3D
var _player_anim: AnimationPlayer
var _hand: Node3D
var _tool3d: Node3D
var _tool_id: String = ""
var _cursor: MeshInstance3D
var _mail_alert: Sprite3D
var _bobber: MeshInstance3D
var _bite_alert: Sprite3D
var _weather: CPUParticles3D
var _weather_kind: String = ""
var _water_mat: StandardMaterial3D
var _cam_target: Vector3
var _is_mine: bool = false
var _is_home: bool = false
var _lanterns: Array[OmniLight3D] = []  # lanternes du village, allumées le soir
var _lantern_glows: Array[MeshInstance3D] = []

## Animaux (Cube Pets) : espèce -> [modèle, hauteur à l'écran en cases]
const PET_MODELS := {
	"chicken": ["animal-chick", 0.42], "bunny": ["animal-bunny", 0.45], "cat": ["animal-cat", 0.45],
	"dog": ["animal-dog", 0.6], "pig": ["animal-pig", 0.62], "cow": ["animal-cow", 0.95],
}
## Objet -> modèle 3D (sinon : l'icône pixel en panneau face caméra)
const ITEM_MODELS := {
	"carrot": ["food", "carrot", 0.9], "turnip": ["food", "radish", 0.9], "cabbage": ["food", "cabbage", 1.0],
	"tomato": ["food", "tomato", 1.8], "corn": ["food", "corn", 1.0], "wheat": ["nature", "crops_wheatStageB", 0.7],
	"leek": ["food", "leek", 0.8], "mushroom": ["food", "mushroom", 2.2], "berries": ["food", "cherries", 2.2],
	"winter_root": ["food", "beet", 1.6], "daffodil": ["nature", "flower_yellowA", 2.0], "poppy": ["nature", "flower_redA", 2.0],
	"wood": ["survival", "resource-wood", 2.0], "stone": ["survival", "resource-stone", 2.0],
	"roach": ["survival", "fish", 2.0], "carp": ["survival", "fish-large", 1.6], "chest": ["survival", "chest", 1.6],
	"radish": ["food", "radish", 1.4], "beet": ["food", "beet", 1.6], "onion": ["food", "onion", 1.6], "garlic": ["food", "onion", 1.2],
	"pumpkin": ["nature", "crop_pumpkin", 0.9], "melon": ["nature", "crop_melon", 0.9], "cauliflower": ["food", "cabbage", 0.9],
	"kale": ["food", "cabbage", 0.9], "potato": ["food", "onion", 1.3],
}
const TOOL_MODELS := {
	"hoe": ["survival", "tool-hoe"], "axe": ["survival", "tool-axe"], "pickaxe": ["survival", "tool-pickaxe"],
	"steel_pickaxe": ["survival", "tool-pickaxe-upgraded"], "watering_can": ["survival", "bucket"],
	"copper_can": ["survival", "bucket"], "scythe": ["survival", "tool-shovel"],
	"rusty_sword": ["dungeon", "weapon-sword"], "iron_sword": ["dungeon", "weapon-sword"], "war_axe": ["survival", "tool-axe-upgraded"],
	"steel_sword": ["dungeon", "weapon-sword"], "firmin_blade": ["dungeon", "weapon-sword"],
}
## Monstres : [modèle, teinte, échelle, hauteur de vol]
const MONSTER_LOOKS := {
	"rat": ["character-orc", Color(0.75, 0.55, 0.4), 0.6, 0.0],
	"cave_rat": ["character-orc", Color(0.6, 0.6, 0.65), 0.7, 0.0],
	"spider": ["character-orc", Color(0.35, 0.3, 0.35), 0.75, 0.0],
	"crab": ["character-orc", Color(1.0, 0.45, 0.4), 0.85, 0.0],
	"ghost": ["character-human", Color(1, 1, 1, 0.55), 0.8, 0.35],
}


# ------------------------------------------------------------ mise en place
func setup(world: WorldMap) -> void:
	map = world
	current = self
	_is_mine = map is MineLevel
	_is_home = map is HomeMap or map is InteriorMap
	_build_environment()
	_static = Node3D.new()
	add_child(_static)
	if _is_mine:
		_build_mine()
	elif _is_home:
		_build_home()
	else:
		_build_ground()
		_build_props()
	_build_player()
	_build_cursor()
	_bobber = MeshInstance3D.new()
	var bob := SphereMesh.new()
	bob.radius = 0.06
	bob.height = 0.12
	bob.material = _flat_material(Color(0.9, 0.25, 0.2))
	_bobber.mesh = bob
	add_child(_bobber)
	_bite_alert = _billboard(load("res://assets/sprites/ui_alert.png"), 0.05)
	add_child(_bite_alert)
	if map is Farm:
		_refresh_farm_all()
		map.visual_changed.connect(_refresh_farm_cell)
		map.visual_reset.connect(_refresh_farm_all)
	TimeManager.time_changed.connect(_update_light)
	TimeManager.day_started.connect(_on_day_started)
	Settings.changed.connect(_update_camera.bind(true))
	EventBus.npc_bubble.connect(_on_npc_bubble)
	EventBus.combat_hit.connect(_on_combat_hit)
	EventBus.monster_killed.connect(_on_monster_killed)
	EventBus.player_hurt.connect(_on_player_hurt)
	map.fishing.cast_started.connect(_on_cast)
	map.fishing.bitten.connect(_on_bite)
	map.fishing.caught.connect(_on_caught)
	_line = MeshInstance3D.new()
	_line.mesh = ImmediateMesh.new()
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.95, 0.95, 0.9, 0.85)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line.material_override = line_mat
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_update_light(0, 0)
	_update_weather()
	_cam_target = _to3d(map.player.position)
	_update_camera(true)


func _exit_tree() -> void:
	if current == self:
		current = null


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_sky_contribution = 0.0
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, -38, 0)
	# Pas d'ombres du soleil (coûteuses sur mobile) : ombres rondes sous les acteurs
	_sun.shadow_enabled = false
	_sun.directional_shadow_max_distance = 22.0
	_sun.shadow_bias = 0.04
	add_child(_sun)
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.far = 48.0  # au-delà, rien n'est visible : moins à dessiner
	camera.current = true
	add_child(camera)
	if _is_mine:
		_lantern = OmniLight3D.new()
		_lantern.light_color = Color(1.0, 0.82, 0.55)
		_lantern.omni_range = 5.5
		_lantern.light_energy = 1.6
		_lantern.shadow_enabled = false
		add_child(_lantern)


# ------------------------------------------------------------ outils
func _to3d(p: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(p.x / UNIT, height, p.y / UNIT)


func _cell3d(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0.0, c.y + 0.5)


func _hash(c: Vector2i) -> int:
	return absi(c.x * 73856093 ^ c.y * 19349663)


func _flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m


func _billboard(texture: Texture2D, pixel: float = 0.04) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = texture
	s.pixel_size = pixel
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	return s


static var _blob_mesh: QuadMesh


## Ombre ronde et douce posée au sol (sous joueur, habitants, monstres).
func _blob(size: float = 0.7) -> MeshInstance3D:
	if _blob_mesh == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var dist := Vector2(x - 15.5, y - 15.5).length() / 15.5
				img.set_pixel(x, y, Color(0, 0, 0, clampf(1.0 - dist, 0.0, 1.0) * 0.45))
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mesh = QuadMesh.new()
		_blob_mesh.orientation = PlaneMesh.FACE_Y
		_blob_mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = _blob_mesh
	mi.scale = Vector3.ONE * size
	mi.position.y = 0.015
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _place(batch: Models.Batch, pack: String, model: String, at: Vector3, scale: float, rot: float = 0.0) -> void:
	var t := Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * scale), at)
	batch.add(Models.path(pack, model), t)


func _model(pack: String, model: String, scale: float = 1.0) -> Node3D:
	var n := Models.instance(Models.path(pack, model))
	n.scale = Vector3.ONE * scale
	return n


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _flat_material(color)
	mi.mesh = box
	return mi


## Modèle mis à l'échelle pour que sa plus grande dimension fasse `size` cases.
func _fitted(pack: String, model: String, size: float) -> Node3D:
	var n := _model(pack, model, 1.0)
	n.scale = Vector3.ONE * size / maxf(_model_size(n), 0.05)
	return n


func _put(node: Node3D, at: Vector3, rot: float = 0.0) -> Node3D:
	node.position = at
	node.rotation.y = rot
	_static.add_child(node)
	return node


## Écran -> case visée (rayon de la caméra contre le sol).
func screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector2i(-1, -1)
	var t := -origin.y / dir.y
	var hit := origin + dir * t
	return Vector2i(floori(hit.x), floori(hit.z))


# ------------------------------------------------------------ sol
func _season_colors() -> Dictionary:
	match TimeManager.season:
		2:
			return {"grass": Color(0.80, 0.68, 0.36), "grass2": Color(0.74, 0.58, 0.30)}
		3:
			return {"grass": Color(0.93, 0.95, 0.98), "grass2": Color(0.86, 0.90, 0.96)}
	return {"grass": Color(0.49, 0.75, 0.38), "grass2": Color(0.43, 0.69, 0.34)}


func _build_ground() -> void:
	var colors := _season_colors()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var chars: Dictionary = map.get("_ground_chars")
	# Couleur de chaque case de terre ferme (carte et décor autour)
	var land := {}
	for cell: Vector2i in chars:
		var ch: String = chars[cell]
		if ch == "~":
			continue
		var col: Color
		match _base_char(cell, chars):
			"=":
				col = Color(0.86, 0.69, 0.47)
			"c":
				col = Color(0.72, 0.70, 0.66)
			":":
				col = Color(0.93, 0.85, 0.62)  # sable
			"#":
				col = Color(0.55, 0.38, 0.23) if (cell.x + cell.y) % 2 == 0 else Color(0.6, 0.42, 0.26)  # planches
			_:
				col = colors.grass if _hash(cell) % 3 != 0 else colors.grass2
		var v := (float(_hash(cell) % 100) / 100.0 - 0.5) * 0.04
		land[cell] = col.lightened(v) if v > 0 else col.darkened(-v)
	for cell: Vector2i in _outskirts():
		land[cell] = Color(0.86, 0.69, 0.47) if _outskirt_road(cell) else (colors.grass if _hash(cell) % 3 != 0 else colors.grass2)
	# Sol lisse : chaque coin prend la moyenne des cases qui le touchent
	var corner := func(x: int, y: int) -> Color:
		var sum := Color(0, 0, 0, 0)
		var n := 0
		for c: Vector2i in [Vector2i(x - 1, y - 1), Vector2i(x, y - 1), Vector2i(x - 1, y), Vector2i(x, y)]:
			if land.has(c):
				sum += land[c]
				n += 1
		return sum / float(maxi(n, 1))
	for cell: Vector2i in land:
		_quad4(st, Vector3(cell.x, 0, cell.y), Vector3(cell.x + 1, 0, cell.y + 1),
			corner.call(cell.x, cell.y), corner.call(cell.x + 1, cell.y), corner.call(cell.x + 1, cell.y + 1), corner.call(cell.x, cell.y + 1))
	for cell: Vector2i in chars:
		var ch: String = chars[cell]
		if ch != "~":
			continue
		var h := -0.28
		_quad(st, Vector3(cell.x, h, cell.y), Vector3(cell.x + 1, h, cell.y + 1), Color(0.55, 0.47, 0.33))
		# Berges de l'eau : parois verticales
		if ch == "~":
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if chars.get(cell + d, "~") != "~":
					_bank(st, cell, d, h, Color(0.52, 0.40, 0.27))
	st.generate_normals()
	var ground := MeshInstance3D.new()
	ground.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true  # nos couleurs sont en sRGB
	mat.roughness = 1.0
	ground.material_override = mat
	_static.add_child(ground)
	if map is Village or map is PortMap:
		_build_paving(chars)
	# Eau : plan transparent légèrement sous le sol
	var water := SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_water := false
	for cell: Vector2i in chars:
		if chars[cell] == "~":
			has_water = true
			_quad(water, Vector3(cell.x, -0.1, cell.y), Vector3(cell.x + 1, -0.1, cell.y + 1), Color.WHITE)
	if has_water:
		water.generate_normals()
		var wmi := MeshInstance3D.new()
		wmi.mesh = water.commit()
		_water_mat = StandardMaterial3D.new()
		_water_mat.albedo_color = Color(0.36, 0.66, 0.9, 0.82) if TimeManager.season != 3 else Color(0.78, 0.9, 0.98, 0.92)
		_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_water_mat.roughness = 0.15
		_water_mat.metallic_specular = 0.8
		# Texture d'eau : vaguelettes et reflets clairs, qui défilent doucement
		_water_mat.albedo_texture = _water_texture()
		_water_mat.uv1_triplanar = true
		_water_mat.uv1_world_triplanar = true
		_water_mat.uv1_scale = Vector3(0.18, 0.18, 0.18)
		_water_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if Settings.quality > 0:
			_water_mat.normal_enabled = true
			_water_mat.normal_texture = _water_texture(true)
			_water_mat.normal_scale = 0.6
		wmi.material_override = _water_mat
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_static.add_child(wmi)


const OUTSKIRT := 10  # cases de décor au-delà des bords de la carte
var _outskirt_cache: Array[Vector2i] = []


## Cases hors de la carte, tout autour (sol et forêt de décor).
func _outskirts() -> Array[Vector2i]:
	if _outskirt_cache.is_empty():
		var size: Vector2i = map.get("_map_size")
		for y in range(-OUTSKIRT, size.y + OUTSKIRT):
			for x in range(-OUTSKIRT, size.x + OUTSKIRT):
				if x < 0 or y < 0 or x >= size.x or y >= size.y:
					_outskirt_cache.append(Vector2i(x, y))
	return _outskirt_cache


## Sol sous un objet de décor (lampadaire, banc...) : sable, route ou herbe,
## comme la plupart de ses voisins.
const DECOR_CHARS := "nqxirapvucwgys"


func _base_char(cell: Vector2i, chars: Dictionary) -> String:
	var ch: String = chars.get(cell, ".")
	if not DECOR_CHARS.contains(ch) or ch == "":
		return ch
	var votes := {}
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n: String = chars.get(cell + d, ".")
		if n in [":", "=", "#"]:
			votes[n] = int(votes.get(n, 0)) + 1
	var best := "."
	var most := 1  # au moins deux voisins pour changer de sol
	for k: String in votes:
		if int(votes[k]) > most:
			most = int(votes[k])
			best = k
	return best


## Une route qui sort de la carte se prolonge tout droit dans le décor.
func _outskirt_road(cell: Vector2i) -> bool:
	var size: Vector2i = map.get("_map_size")
	var out_x := cell.x < 0 or cell.x >= size.x
	var out_y := cell.y < 0 or cell.y >= size.y
	if out_x == out_y:
		return false  # dans la carte, ou dans un coin
	var edge := Vector2i(clampi(cell.x, 0, size.x - 1), clampi(cell.y, 0, size.y - 1))
	return map.get("_ground_chars").get(edge, "") == "="


## Carré horizontal avec une couleur par coin (dégradés doux).
func _quad4(st: SurfaceTool, a: Vector3, b: Vector3, c00: Color, c10: Color, c11: Color, c01: Color) -> void:
	var p1 := Vector3(a.x, a.y, a.z)
	var p2 := Vector3(b.x, a.y, a.z)
	var p3 := Vector3(b.x, a.y, b.z)
	var p4 := Vector3(a.x, a.y, b.z)
	for pair: Array in [[p1, c00], [p2, c10], [p3, c11], [p1, c00], [p3, c11], [p4, c01]]:
		st.set_color(pair[1])
		st.add_vertex(pair[0])


static var _water_tex: Dictionary = {}


## Texture d'eau sans raccord : bruit doux (couleur) ou carte de relief.
func _water_texture(normal: bool = false) -> Texture2D:
	if _water_tex.has(normal):
		return _water_tex[normal]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR if not normal else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035 if not normal else 0.05
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.noise = noise
	tex.generate_mipmaps = true
	if normal:
		tex.as_normal_map = true
		tex.bump_strength = 6.0
	else:
		# Clair sur les crêtes des vaguelettes, blanc-bleu presque partout
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.82, 0.92, 1.0))
		ramp.set_color(1, Color(1, 1, 1))
		ramp.add_point(0.75, Color(0.9, 0.97, 1.0))
		tex.color_ramp = ramp
	_water_tex[normal] = tex
	return tex


static var _plank_tex: ImageTexture


## Matériau en planches de bois (bateaux) : lignes de planches, nœuds, teinte.
func _plank_material(color: Color) -> StandardMaterial3D:
	if _plank_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
		for y in 32:
			for x in 32:
				var board := y / 6
				var shade := 0.92 + 0.08 * sin(float(x) * 0.7 + board * 2.3) + (0.05 if board % 2 == 0 else 0.0)
				if y % 6 == 0:
					shade = 0.62  # joint entre deux planches
				if (x + board * 11) % 29 == 0 and y % 6 == 3:
					shade = 0.7  # nœud du bois
				img.set_pixel(x, y, Color(shade, shade, shade))
		_plank_tex = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _plank_tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(2.5, 2.5, 2.5)
	m.roughness = 0.9
	return m


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, color: Color) -> void:
	st.set_color(color)
	var p1 := Vector3(a.x, a.y, a.z)
	var p2 := Vector3(b.x, a.y, a.z)
	var p3 := Vector3(b.x, a.y, b.z)
	var p4 := Vector3(a.x, a.y, b.z)
	for p in [p1, p2, p3, p1, p3, p4]:
		st.add_vertex(p)


func _bank(st: SurfaceTool, cell: Vector2i, d: Vector2i, h: float, color: Color) -> void:
	st.set_color(color)
	var x0 := float(cell.x)
	var z0 := float(cell.y)
	var a: Vector3
	var b: Vector3
	match d:
		Vector2i.UP:
			a = Vector3(x0, 0, z0)
			b = Vector3(x0 + 1, 0, z0)
		Vector2i.DOWN:
			a = Vector3(x0 + 1, 0, z0 + 1)
			b = Vector3(x0, 0, z0 + 1)
		Vector2i.LEFT:
			a = Vector3(x0, 0, z0 + 1)
			b = Vector3(x0, 0, z0)
		_:
			a = Vector3(x0 + 1, 0, z0)
			b = Vector3(x0 + 1, 0, z0 + 1)
	var a2 := a + Vector3(0, h, 0)
	var b2 := b + Vector3(0, h, 0)
	for p in [a, b, b2, a, b2, a2]:
		st.add_vertex(p)


# ------------------------------------------------------------ décor
func _tree_model(cell: Vector2i) -> String:
	var r := _hash(cell) % 5
	match TimeManager.season:
		2:
			return ["tree_default_fall", "tree_oak_fall", "tree_detailed_fall", "tree_fat_fall", "tree_pineRoundA"][r]
		3:
			return ["tree_pineDefaultA", "tree_pineRoundC", "tree_pineTallA", "tree_pineRoundA", "tree_pineSmallA"][r]
	return ["tree_default", "tree_oak", "tree_pineRoundA", "tree_detailed", "tree_pineDefaultA"][r]


func _build_props() -> void:
	var batch := Models.Batch.new()
	var chars: Dictionary = map.get("_ground_chars")
	for cell: Vector2i in chars:
		var ch: String = chars[cell]
		var c := _cell3d(cell)
		var rot := float(_hash(cell) % 628) / 100.0
		match ch:
			"T":
				_place(batch, "nature", _tree_model(cell), c, 1.5 + float(_hash(cell) % 30) / 100.0, rot)
			"R":
				_place(batch, "nature", "tree_oak" if TimeManager.season != 2 else "tree_oak_fall", c, 1.9, rot)
			"b":
				_place(batch, "nature", "plant_bushLarge", c, 2.4, rot)
			"o":
				_place(batch, "nature", "rock_largeA", c, 0.9, rot)
			"f":
				_place(batch, "nature", "flower_yellowB", c, 3.0, rot)
			"m":
				_place(batch, "nature", "mushroom_redGroup", c, 2.2, rot)
			"h":
				_place(batch, "nature", "log_stack", c, 1.6, rot)
			"k":
				_place(batch, "survival", "barrel", c, 2.6, rot)
			",":
				for k in 3:
					var off := Vector3(float(_hash(cell + Vector2i(k, 7)) % 60) / 100.0 - 0.3, 0, float(_hash(cell + Vector2i(7, k)) % 60) / 100.0 - 0.3)
					_place(batch, "nature", ["flower_redA", "flower_yellowA", "flower_purpleA"][k], c + off, 1.6, rot)
			"'":
				_place(batch, "nature", "grass_large", c, 1.6, rot)
			"F":
				_place(batch, "nature", "fence_simple", c, 1.0, 0.0)
			"P", "Q":
				_place(batch, "nature", "sign", c, 2.2, 0.0)
			"n":
				if map is Village or map is PortMap:
					_street_lamp(cell)
				else:
					_village_lantern(cell)
			"x":
				# Arbre d'ornement dans un bac de bois
				_put(_box(Vector3(0.7, 0.4, 0.7), Color(0.5, 0.33, 0.2)), c + Vector3(0, 0.2, 0))
				_put(_box(Vector3(0.6, 0.04, 0.6), Color(0.33, 0.24, 0.16)), c + Vector3(0, 0.41, 0))
				_place(batch, "nature", "tree_default" if TimeManager.season != 2 else "tree_default_fall", c + Vector3(0, 0.4, 0), 0.9, rot)
			"i":
				# Borne d'amarrage, avec un bout de corde
				_put(_box(Vector3(0.22, 0.4, 0.22), Color(0.2, 0.2, 0.23)), c + Vector3(0, 0.2, 0))
				_put(_box(Vector3(0.3, 0.06, 0.3), Color(0.2, 0.2, 0.23)), c + Vector3(0, 0.42, 0))
				_put(_box(Vector3(0.26, 0.05, 0.26), Color(0.78, 0.68, 0.45)), c + Vector3(0, 0.3, 0))
			"r":
				# Filets qui sèchent sur des perches, caisses de poissons
				for k in 2:
					_put(_box(Vector3(0.05, 0.9, 0.05), Color(0.45, 0.32, 0.2)), c + Vector3(-0.38 + k * 0.76, 0.45, -0.2))
				var net := _box(Vector3(0.76, 0.6, 0.02), Color(0.35, 0.45, 0.42, 0.85))
				_put(net, c + Vector3(0, 0.55, -0.2))
				_put(_fitted("survival", "box", 0.38), c + Vector3(-0.2, 0, 0.2))
				_put(_fitted("survival", "fish", 0.3), c + Vector3(-0.2, 0.32, 0.2), 0.4)
				_put(_fitted("survival", "box", 0.34), c + Vector3(0.22, 0, 0.18), 0.3)
			"a":
				# Vieille ancre posée sur le quai
				var iron := Color(0.24, 0.24, 0.27)
				_put(_box(Vector3(0.08, 0.8, 0.08), iron), c + Vector3(0, 0.45, 0), 0.3)
				_put(_box(Vector3(0.36, 0.06, 0.06), iron), c + Vector3(0, 0.75, 0), 0.3)
				_put(_box(Vector3(0.6, 0.08, 0.08), iron), c + Vector3(0, 0.08, 0), 0.3)
				_put(_box(Vector3(0.08, 0.2, 0.08), iron), c + Vector3(0.26, 0.15, 0.08), 0.3)
				_put(_box(Vector3(0.08, 0.2, 0.08), iron), c + Vector3(-0.26, 0.15, -0.08), 0.3)
			"p":
				# Étal du poissonnier : tréteaux, glace, poissons, auvent rayé
				_put(_box(Vector3(0.95, 0.08, 0.6), Color(0.55, 0.38, 0.24)), c + Vector3(0, 0.55, 0))
				_put(_box(Vector3(0.88, 0.05, 0.52), Color(0.86, 0.93, 0.97)), c + Vector3(0, 0.61, 0))
				for k in 4:
					_put(_box(Vector3(0.06, 0.55, 0.06), Color(0.45, 0.3, 0.18)), c + Vector3(-0.4 + (k % 2) * 0.8, 0.27, -0.25 + (k / 2) * 0.5))
				for k in 3:
					_put(_fitted("survival", "fish", 0.28), c + Vector3(-0.28 + k * 0.28, 0.65, 0.02), 0.2 * k)
				for k in 2:
					_put(_box(Vector3(0.05, 1.3, 0.05), Color(0.45, 0.3, 0.18)), c + Vector3(-0.45 + k * 0.9, 0.65, -0.3))
				var awning := _box(Vector3(1.0, 0.04, 0.55), Color(0.2, 0.45, 0.75))
				_put(awning, c + Vector3(0, 1.3, -0.08))
				_put(_box(Vector3(1.0, 0.045, 0.18), Color(0.95, 0.95, 0.92)), c + Vector3(0, 1.31, -0.08))
			"v":
				# Jardinière fleurie
				_put(_box(Vector3(0.85, 0.32, 0.6), Color(0.55, 0.36, 0.22)), c + Vector3(0, 0.16, 0))
				for k in 3:
					_put(_fitted("nature", ["flower_redA", "flower_yellowA", "flower_purpleA"][(k + cell.x) % 3], 0.4), c + Vector3(-0.27 + k * 0.27, 0.3, 0))
			"c":
				# Grand bac à fleurs de la place
				_put(_fitted("nature", "pot_large", 0.8), c)
				_put(_fitted("nature", "flower_redA", 0.45), c + Vector3(-0.12, 0.45, 0))
				_put(_fitted("nature", "flower_yellowB", 0.45), c + Vector3(0.12, 0.45, 0.05))
			"q":
				# Le banc regarde dans le sens où l'on s'y assoit
				var look: Vector2i = map.seats.get(cell, Vector2i.DOWN)
				_bench(c, atan2(float(look.x), float(look.y)))
			"g":
				_put(_fitted("town", "hedge", 1.0), c)
			"u":
				_put(_fitted("survival", "barrel", 0.55), c + Vector3(-0.18, 0, 0.1))
				_put(_fitted("survival", "box", 0.45), c + Vector3(0.22, 0, -0.15))
			"y":
				_put(_box(Vector3(0.9, 0.55, 0.9), Color(0.92, 0.8, 0.42)), c + Vector3(0, 0.27, 0))
				_put(_box(Vector3(0.6, 0.3, 0.6), Color(0.95, 0.85, 0.5)), c + Vector3(0, 0.68, 0))
			"w":
				_well(c)
			"W":
				# Bateau amarré : sur la première case, orienté vers la seconde
				if chars.get(cell + Vector2i.LEFT, "") != "W" and chars.get(cell + Vector2i.UP, "") != "W":
					var along_x: bool = chars.get(cell + Vector2i.RIGHT, "") == "W"
					_boat(c + (Vector3(0.5, 0, 0) if along_x else Vector3(0, 0, 0.5)), 0.0 if along_x else PI / 2.0, _hash(cell))
			"#":
				# Pontons : poteaux aux bords qui donnent sur l'eau
				for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if chars.get(cell + d, "") == "~" and _hash(cell + d) % 2 == 0:
						_put(_box(Vector3(0.1, 0.6, 0.1), Color(0.4, 0.27, 0.16)), c + Vector3(d.x, 0, d.y) * 0.45 + Vector3(0, 0.05, 0))
			"L":
				# Tronc qui barre le chemin de la forêt (tant qu'il n'est pas dégagé)
				if not PlayerState.flags.has("story_ch1") and chars.get(cell + Vector2i.LEFT, "") != "L":
					var trunk := MeshInstance3D.new()
					var cyl := CylinderMesh.new()
					cyl.top_radius = 0.38
					cyl.bottom_radius = 0.42
					cyl.height = 2.6
					cyl.material = _flat_material(Color(0.42, 0.28, 0.18))
					trunk.mesh = cyl
					trunk.rotation.z = PI / 2.0
					_put(trunk, c + Vector3(0.5, 0.38, 0), 0.15)
					_put(_fitted("nature", "plant_bushLarge", 0.8), c + Vector3(1.6, 0.3, -0.1))
			"X":
				# Mur de ronces (coupé au chapitre 4 : il reste des souches)
				if ForestMap.brambles_cut():
					if _hash(cell) % 3 == 0:
						_place(batch, "nature", "stump_old", c, 1.2, rot)
				else:
					_place(batch, "nature", "plant_bushLarge", c, 2.6, rot)
					_place(batch, "nature", "plant_bushLarge", c + Vector3(0.2, 0.3, 0.1), 1.8, rot + 1.0)
			"S":
				if map is ForestMap and chars.get(cell + Vector2i.LEFT, "") != "S" and chars.get(cell + Vector2i.UP, "") != "S":
					_spring(Vector3(cell.x + 1.0, 0, cell.y + 1.0))
			"j":
				_place(batch, "nature", "campfire_stones", c, 1.4, 0.0)
			"z":
				# Tente de toile usée
				var tent := MeshInstance3D.new()
				var prism := PrismMesh.new()
				prism.size = Vector3(1.1, 0.85, 1.3)
				prism.material = _flat_material(Color(0.78, 0.7, 0.52))
				tent.mesh = prism
				_put(tent, c + Vector3(0, 0.42, 0), PI / 2.0)
				_put(_box(Vector3(0.3, 0.5, 0.02), Color(0.2, 0.15, 0.1)), c + Vector3(0.66, 0.25, 0), PI / 2.0)
				_put(_fitted("survival", "bedroll", 0.8), c + Vector3(0.6, 0, 0.6), 0.4)
			"s":
				if chars.get(cell + Vector2i.LEFT, "") != "s":
					var stall := _fitted("town", "stall-green" if _hash(cell) % 2 == 0 else "stall-red", 1.5)
					_put(stall, c + Vector3(0.5 if chars.get(cell + Vector2i.RIGHT, "") == "s" else 0.0, 0, 0))
					for k in 3:
						var food := _fitted("food", ["tomato", "carrot", "cabbage", "corn", "leek"][(_hash(cell) + k) % 5], 0.22)
						_put(food, c + Vector3(0.1 + k * 0.32, 0.42, 0.12))
			".":
				if TimeManager.season != 3 and _hash(cell) % 9 == 0:
					_place(batch, "nature", "grass", c, 1.4, rot)
	# Forêt dense autour de la carte, en laissant la route dégagée
	for cell: Vector2i in _outskirts():
		if _outskirt_road(cell):
			continue
		var near_road := false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			if _outskirt_road(cell + d):
				near_road = true
		var r := _hash(cell) % 10
		var c := _cell3d(cell)
		if near_road:
			if r < 2:
				_place(batch, "nature", "plant_bushLarge", c, 2.0, float(r))
			continue
		# Dense près du bord, clairsemé plus loin (moins de triangles)
		var size: Vector2i = map.get("_map_size")
		var dist := maxi(maxi(-cell.x, cell.x - size.x + 1), maxi(-cell.y, cell.y - size.y + 1))
		var dense := 7 if dist <= 3 else (3 if Settings.quality >= 2 else 2)
		if r < dense:
			var jitter := Vector3(float(_hash(cell + Vector2i(3, 1)) % 40) / 100.0 - 0.2, 0, float(_hash(cell + Vector2i(1, 3)) % 40) / 100.0 - 0.2)
			_place(batch, "nature", _tree_model(cell), c + jitter, 1.6 + float(_hash(cell) % 40) / 100.0, float(_hash(cell) % 628) / 100.0)
		elif r == 7:
			_place(batch, "nature", "plant_bushLarge", c, 2.2, 0.0)
	batch.build(_static)
	_finish_lamps()
	_wall_batch = Models.Batch.new()
	_build_buildings(chars)
	_wall_batch.build(_static)
	_wall_batch = null
	if map is Village:
		_build_event_decor()
		_build_gardens()


func _build_buildings(chars: Dictionary) -> void:
	for cell: Vector2i in chars:
		var ch: String = chars[cell]
		if map is Farm:
			match ch:
				"H":
					_house(cell, Vector2i(3, 3), 1, "wall", Color(0.78, 0.3, 0.25))
				"G":
					_house(cell, Vector2i(3, 6), 1, "wall-wood", Color(0.4, 0.6, 0.35))
				"B":
					var bin := _model("survival", "box-large", 2.2)
					bin.position = _cell3d(cell)
					bin.rotation.y = PI / 2.0
					_static.add_child(bin)
				"X":
					var box := _billboard(load("res://assets/sprites/mailbox.png"), 0.045)
					box.position = _cell3d(cell) + Vector3(0, 0.36, 0)
					_static.add_child(box)
					_mail_alert = _billboard(load("res://assets/sprites/ui_alert.png"), 0.04)
					_mail_alert.position = box.position + Vector3(0, 0.6, 0)
					_static.add_child(_mail_alert)
		elif map is PortMap and PortMap.BUILDINGS.has(ch):
			var pb: Array = PortMap.BUILDINGS[ch]
			var psize: Vector2i = pb[1]
			var pfront := _cell3d(cell + Vector2i(0, psize.y))
			match str(pb[0]):
				"taverne":
					_house(cell, psize, pb[3], "wall-wood", Color(0.6, 0.22, 0.18))
					_put(_fitted("survival", "barrel", 0.5), pfront + Vector3(-0.4, 0, -0.35))
					_put(_fitted("survival", "barrel", 0.5), pfront + Vector3(psize.x - 0.6, 0, -0.35))
					_put(_box(Vector3(1.4, 0.36, 0.06), Color(0.45, 0.3, 0.18)), pfront + Vector3(pb[3], 1.5, -0.42))
					var sign := Label3D.new()
					sign.text = "TAVERNE"
					sign.font = UiTheme.title_font()
					sign.font_size = 56
					sign.pixel_size = 0.0045
					sign.modulate = Color(1, 0.85, 0.45)
					_put(sign, pfront + Vector3(pb[3], 1.5, -0.38))
				"comptoir":
					_house(cell, psize, pb[3], "wall", Color(0.25, 0.55, 0.6))
					_put(_fitted("survival", "box", 0.45), pfront + Vector3(psize.x - 0.4, 0, -0.35))
					_put(_fitted("survival", "box-open", 0.4), pfront + Vector3(-0.4, 0, -0.35))
				"celeste":
					_house(cell, psize, pb[3], "wall-wood", Color(0.55, 0.35, 0.65))
				"phare":
					_lighthouse(Vector3(cell.x + 1.0, 0, cell.y + 1.0))
		elif map is Village and Village.BUILDINGS.has(ch):
			var b: Array = Village.BUILDINGS[ch]
			var size: Vector2i = b[1]
			var front := _cell3d(cell + Vector2i(0, size.y))  # première case devant la façade
			match str(b[0]):
				"store":
					_house(cell, size, b[3], "wall", Color(0.85, 0.35, 0.3))
					_put(_fitted("town", "banner-red", 0.9), front + Vector3(-0.35, 0, -0.45))
					_put(_fitted("survival", "barrel", 0.45), front + Vector3(3.4, 0, -0.4))
				"mairie":
					_house(cell, size, b[3], "wall", Color(0.32, 0.42, 0.62))
					_put(_fitted("town", "banner-green", 0.9), front + Vector3(-0.35, 0, -0.45))
					_put(_fitted("town", "banner-green", 0.9), front + Vector3(size.x - 0.65, 0, -0.45))
				"gaston":
					_house(cell, size, b[3], "wall", Color(0.3, 0.3, 0.34))
					_put(_fitted("survival", "campfire-pit", 0.6), front + Vector3(size.x - 0.6, 0, -0.4))
				"menuiserie":
					_house(cell, size, b[3], "wall-wood", Color(0.55, 0.36, 0.22))
					_put(_fitted("survival", "workbench", 0.8), front + Vector3(size.x - 0.5, 0, -0.35), PI)
					_put(_fitted("nature", "log_stack", 0.8), front + Vector3(-0.5, 0, -0.9))
				"cooperative":
					_house(cell, size, b[3], "wall", Color(0.36, 0.6, 0.32))
					_put(_fitted("town", "stall-green", 1.2), front + Vector3(size.x + 0.2, 0, -0.9), -PI / 2.0)
					_put(_fitted("survival", "box-large", 0.5), front + Vector3(-0.5, 0, -0.6))
					_put(_fitted("survival", "barrel", 0.45), front + Vector3(-0.5, 0, -1.3))
				"ranch":
					_house(cell, size, b[3], "wall-wood", Color(0.75, 0.25, 0.2))
					_put(_fitted("town", "cart", 1.1), front + Vector3(size.x + 0.4, 0, -1.0), 0.4)
				"odette":
					_house(cell, size, b[3], "wall-wood", Color(0.78, 0.3, 0.25))
					_put(_fitted("nature", "pot_large", 0.4), front + Vector3(-0.3, 0, -0.45))
				"lina":
					_house(cell, size, b[3], "wall-wood", Color(0.35, 0.55, 0.75))
					_put(_fitted("nature", "pot_small", 0.35), front + Vector3(size.x - 0.3, 0, -0.45))
				"jules":
					_house(cell, size, b[3], "wall-wood", Color(0.3, 0.55, 0.5))
					_put(_fitted("survival", "barrel", 0.5), front + Vector3(size.x + 0.3, 0, -0.9))
					_put(_fitted("survival", "fish-large", 0.45), front + Vector3(size.x + 0.3, 0.5, -0.9))
				"fountain":
					var f := _fitted("town", "fountain-round-detail", 2.2)
					_put(f, Vector3(cell.x + 1.0, 0, cell.y + 1.0))
					if PlayerState.flags.has("story_ch5"):
						_festival(Vector3(cell.x + 1.0, 0, cell.y + 1.0))
				"mine":
					_mine_entrance(cell, b[3])
		if map is Farm and ch in ["K", "J", "S"]:
			_farm_plot({"K": "coop", "J": "barn", "S": "greenhouse"}[ch])
		if ch == "N":
			var anvil := _model("survival", "workbench-anvil", 2.2)
			anvil.position = _cell3d(cell)
			_static.add_child(anvil)


## Maison de plain-pied, à la taille du personnage : soubassement en pierre,
## murs Kenney (porte, fenêtres à volets), toit de tuiles avec faîtage et
## avant-toit, jardinières sous les fenêtres, marche, paillasson, lanterne.
## Toits et détails sont regroupés en un seul objet par maison (léger).
func _house(cell: Vector2i, size: Vector2i, door_col: int, wall: String, roof_color: Color) -> void:
	var root := Node3D.new()
	_static.add_child(root)
	var x0 := float(cell.x)
	var z0 := float(cell.y)
	var w := size.x
	var d := size.y
	var base := 0.1  # hauteur du soubassement
	var front_z := z0 + d - 0.5
	for i in w:
		var front: String = wall + ("-door" if i == door_col else "-window-shutters")
		_wall(root, front, Vector3(x0 + i + 0.5, base, front_z), -PI / 2.0)
		_wall(root, wall, Vector3(x0 + i + 0.5, base, z0 + 0.5), PI / 2.0)
	for j in d:
		var side: String = wall + ("-window-shutters" if j == d / 2 else "")
		_wall(root, side, Vector3(x0 + 0.5, base, z0 + j + 0.5), PI)
		_wall(root, side, Vector3(x0 + w - 0.5, base, z0 + j + 0.5), 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Soubassement en pierre
	_st_box(st, Vector3(x0 + w / 2.0, base / 2.0, z0 + d / 2.0), Vector3(w + 0.08, base, d + 0.08), Color(0.58, 0.56, 0.54))
	# Toit de tuiles
	_roof_into(st, Vector3(x0, base + 1.0, z0), float(w), float(d), roof_color)
	# Jardinières fleuries sous les fenêtres, marche et paillasson devant la porte
	var flowers := [Color(0.92, 0.3, 0.3), Color(0.98, 0.82, 0.3), Color(0.85, 0.5, 0.9), Color(1, 1, 1)]
	for i in w:
		var cx := x0 + i + 0.5
		var fz := z0 + d + 0.02
		if i == door_col:
			_st_box(st, Vector3(cx, 0.04, fz + 0.18), Vector3(0.62, 0.08, 0.34), Color(0.62, 0.6, 0.58))
			_st_box(st, Vector3(cx, 0.085, fz + 0.16), Vector3(0.42, 0.01, 0.22), Color(0.7, 0.28, 0.24))
			continue
		_st_box(st, Vector3(cx, base + 0.36, fz + 0.06), Vector3(0.5, 0.1, 0.14), Color(0.48, 0.32, 0.2))
		for k in 3:
			var col: Color = flowers[(k + cell.x + i) % flowers.size()]
			_st_box(st, Vector3(cx - 0.15 + k * 0.15, base + 0.45, fz + 0.06), Vector3(0.09, 0.09, 0.09), col)
			_st_box(st, Vector3(cx - 0.15 + k * 0.15, base + 0.41, fz + 0.06), Vector3(0.05, 0.05, 0.05), Color(0.3, 0.6, 0.3))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	root.add_child(mi)
	# Lanterne près de la porte
	var lamp := MeshInstance3D.new()
	var bulb := BoxMesh.new()
	bulb.size = Vector3(0.1, 0.14, 0.1)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1, 0.85, 0.5)
	lm.emission_enabled = true
	lm.emission = Color(1, 0.75, 0.35)
	lm.emission_energy_multiplier = 1.5
	bulb.material = lm
	lamp.mesh = bulb
	lamp.position = Vector3(x0 + door_col + 0.92, base + 0.72, z0 + d + 0.05)
	root.add_child(lamp)
	var chimney := _model("town", "chimney", 0.7)
	chimney.position = Vector3(x0 + w - 0.7, base + 1.3, z0 + 0.75)
	root.add_child(chimney)
	if Settings.quality > 0:
		root.add_child(_smoke(chimney.position + Vector3(0, 0.65, 0)))


## Boîte colorée ajoutée à un maillage (détails regroupés en un seul objet).
func _st_box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h := size / 2.0
	var p := [
		center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z), center + Vector3(h.x, h.y, -h.z), center + Vector3(-h.x, h.y, -h.z),
		center + Vector3(-h.x, -h.y, h.z), center + Vector3(h.x, -h.y, h.z), center + Vector3(h.x, h.y, h.z), center + Vector3(-h.x, h.y, h.z),
	]
	var faces := [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]
	for k in faces.size():
		var f: Array = faces[k]
		# Faces du dessus plus claires, du dessous plus sombres : relief sans lumière
		st.set_color(color.lightened(0.06) if k == 4 else (color.darkened(0.2) if k == 5 else color))
		for idx: int in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.add_vertex(p[idx])


## Fumée de cheminée : quelques bouffées grises qui montent et s'effacent.
func _smoke(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	puff.radial_segments = 8
	puff.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.88, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	puff.material = mat
	p.mesh = puff
	p.amount = 7
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.direction = Vector3(0.3, 1, 0)
	p.spread = 12.0
	p.gravity = Vector3(0.15, 0.25, 0)
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.4
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 2.0))
	p.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.8))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	p.position = at
	return p


## Fête des fleurs (fin de l'histoire) : fleurs et bannières autour de la fontaine.
func _festival(center: Vector3) -> void:
	var flowers := ["flower_redA", "flower_yellowA", "flower_purpleA", "flower_yellowB"]
	for k in 16:
		var a := k * TAU / 16.0
		_put(_fitted("nature", flowers[k % flowers.size()], 0.6), center + Vector3(cos(a), 0, sin(a)) * 1.7, a)
	for k in 4:
		var a := PI / 4.0 + k * PI / 2.0
		_put(_fitted("town", "banner-red" if k % 2 == 0 else "banner-green", 1.0), center + Vector3(cos(a), 0, sin(a)) * 2.6, -a)
	# Eau qui jaillit de nouveau
	var jet := CPUParticles3D.new()
	var drop := SphereMesh.new()
	drop.radius = 0.04
	drop.height = 0.08
	var mat := _flat_material(Color(0.6, 0.85, 1.0, 0.8))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = mat
	jet.mesh = drop
	jet.amount = 40
	jet.lifetime = 1.0
	jet.direction = Vector3.UP
	jet.spread = 18.0
	jet.initial_velocity_min = 2.0
	jet.initial_velocity_max = 2.6
	jet.gravity = Vector3(0, -6, 0)
	_put(jet, center + Vector3(0, 1.0, 0))


# ------------------------------------------------------------ pavés et lampadaires
## Routes pavées (village et port), dallage en rosace sur la place de
## Valfleur et bordures de pierre (textures : tools/build_paving.py).
func _build_paving(chars: Dictionary) -> void:
	var plaza := Village.PLAZA if map is Village else Rect2i()
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var square := SurfaceTool.new()
	square.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curbs := SurfaceTool.new()
	curbs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paved := {}
	for cell: Vector2i in chars:
		if plaza.has_point(cell) or chars[cell] == "=" or _base_char(cell, chars) == "=":
			paved[cell] = true
	for cell: Vector2i in _outskirts():
		if _outskirt_road(cell):
			paved[cell] = true
	var y := 0.012
	for cell: Vector2i in paved:
		var a := Vector3(cell.x, y, cell.y)
		if plaza.has_point(cell):
			var u0 := Vector2(cell - plaza.position) / Vector2(plaza.size)
			var u1 := Vector2(cell - plaza.position + Vector2i.ONE) / Vector2(plaza.size)
			_uv_quad(square, a, u0, u1, false)
		else:
			# Une des 4 variantes ; rangées de pavés dans le sens de la route
			var v := _hash(cell) % 4
			var vertical := paved.has(cell + Vector2i.UP) and paved.has(cell + Vector2i.DOWN) and not (paved.has(cell + Vector2i.LEFT) and paved.has(cell + Vector2i.RIGHT))
			_uv_quad(road, a, Vector2(v * 0.25, 0), Vector2(v * 0.25 + 0.25, 1), vertical)
		# Bordures : une pierre basse le long des côtés qui donnent sur l'herbe
		if plaza.has_point(cell) and not (cell.x == plaza.position.x or cell.y == plaza.position.y or cell.x == plaza.end.x - 1 or cell.y == plaza.end.y - 1):
			continue
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n := cell + d
			if paved.has(n) or not chars.has(n) or chars[n] == "~" or chars[n] == "#":
				continue
			var center := Vector3(cell.x + 0.5 + d.x * 0.47, 0.03, cell.y + 0.5 + d.y * 0.47)
			var size := Vector3(1.0 if d.x == 0 else 0.07, 0.06, 0.07 if d.x == 0 else 1.0)
			_st_box(curbs, center, size, Color(0.66, 0.63, 0.58))
	for pair: Array in [[road, "res://assets/sprites/paving_road.png"], [square, "res://assets/sprites/paving_plaza.png"]]:
		var st: SurfaceTool = pair[0]
		st.generate_normals()
		var mesh := st.commit()
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(pair[1])
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		mat.roughness = 1.0
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_static.add_child(mi)
	curbs.generate_normals()
	var curb_mesh := curbs.commit()
	if curb_mesh.get_surface_count() > 0:
		var cm := MeshInstance3D.new()
		cm.mesh = curb_mesh
		var cmat := StandardMaterial3D.new()
		cmat.vertex_color_use_as_albedo = true
		cmat.vertex_color_is_srgb = true
		cmat.roughness = 1.0
		cm.material_override = cmat
		_static.add_child(cm)


## Carré horizontal texturé (UV de u0 à u1, éventuellement tourné d'un quart).
func _uv_quad(st: SurfaceTool, a: Vector3, u0: Vector2, u1: Vector2, turned: bool) -> void:
	var p := [a, a + Vector3(1, 0, 0), a + Vector3(1, 0, 1), a + Vector3(0, 0, 1)]
	var uv := [u0, Vector2(u1.x, u0.y), u1, Vector2(u0.x, u1.y)]
	if turned:
		uv = [uv[1], uv[2], uv[3], uv[0]]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[i])
		st.set_normal(Vector3.UP)
		st.add_vertex(p[i])


## Lampadaire : socle, fût de fonte, crosse et lanterne vitrée qui s'allume
## le soir. Les parties fixes de tous les lampadaires forment un seul maillage.
var _lamp_st: SurfaceTool
var _lamp_glow_st: SurfaceTool
var _lamp_count: int = 0


func _street_lamp(cell: Vector2i) -> void:
	if _lamp_st == null:
		_lamp_st = SurfaceTool.new()
		_lamp_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_lamp_glow_st = SurfaceTool.new()
		_lamp_glow_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := _cell3d(cell)
	var iron := Color(0.16, 0.17, 0.2)
	_st_box(_lamp_st, c + Vector3(0, 0.1, 0), Vector3(0.26, 0.2, 0.26), iron)
	_st_box(_lamp_st, c + Vector3(0, 0.24, 0), Vector3(0.16, 0.08, 0.16), iron)
	_st_box(_lamp_st, c + Vector3(0, 1.1, 0), Vector3(0.07, 1.7, 0.07), iron)
	_st_box(_lamp_st, c + Vector3(0, 1.98, 0), Vector3(0.12, 0.06, 0.12), iron)
	# Lanterne : cage, toit, vitres lumineuses
	var top := c + Vector3(0, 2.18, 0)
	_st_box(_lamp_st, top + Vector3(0, -0.15, 0), Vector3(0.26, 0.04, 0.26), iron)
	_st_box(_lamp_st, top + Vector3(0, 0.16, 0), Vector3(0.3, 0.05, 0.3), iron)
	_st_box(_lamp_st, top + Vector3(0, 0.22, 0), Vector3(0.16, 0.07, 0.16), iron)
	for k in 4:
		var corner := Vector3(0.11 if k % 2 == 0 else -0.11, 0, 0.11 if k < 2 else -0.11)
		_st_box(_lamp_st, top + corner, Vector3(0.03, 0.3, 0.03), iron)
	_st_box(_lamp_glow_st, top, Vector3(0.2, 0.26, 0.2), Color(1.0, 0.86, 0.5))
	_lamp_count += 1
	# Lumière : toutes en qualité élevée, une sur deux en normale, aucune en économie
	if Settings.quality == 0 or (Settings.quality == 1 and _lamp_count % 2 == 0):
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.5)
	light.omni_range = 4.0
	light.light_energy = 1.4
	light.position = top + Vector3(0, -0.1, 0)
	light.visible = false
	_static.add_child(light)
	_lanterns.append(light)


func _finish_lamps() -> void:
	if _lamp_st == null:
		return
	_lamp_st.generate_normals()
	var posts := MeshInstance3D.new()
	posts.mesh = _lamp_st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.6
	posts.material_override = mat
	_static.add_child(posts)
	var glow := MeshInstance3D.new()
	glow.mesh = _lamp_glow_st.commit()
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1.0, 0.88, 0.55)
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.75, 0.35)
	gmat.emission_energy_multiplier = 2.2
	glow.material_override = gmat
	_static.add_child(glow)
	# Le jour, les vitres restent jaune pâle (éteintes) ; le soir elles brillent
	var off := MeshInstance3D.new()
	off.mesh = glow.mesh
	off.material_override = _flat_material(Color(0.86, 0.84, 0.7))
	_static.add_child(off)
	_lantern_glows.append(glow)
	_lamp_off = off
	_lamp_st = null
	_lamp_glow_st = null
	_lamp_count = 0


var _lamp_off: MeshInstance3D


## Banc de parc en bois (assise, dossier, pieds en fer).
func _bench(c: Vector3, rot: float) -> void:
	var bench := Node3D.new()
	var wood := Color(0.62, 0.4, 0.24)
	var iron := Color(0.25, 0.25, 0.28)
	for part: Array in [
		[Vector3(0.9, 0.06, 0.32), Vector3(0, 0.3, 0), wood],
		[Vector3(0.9, 0.22, 0.05), Vector3(0, 0.5, -0.15), wood],
		[Vector3(0.06, 0.3, 0.3), Vector3(-0.38, 0.15, 0), iron],
		[Vector3(0.06, 0.3, 0.3), Vector3(0.38, 0.15, 0), iron],
	]:
		var b := _box(part[0], part[2])
		b.position = part[1]
		bench.add_child(b)
	_put(bench, c, rot)


## Entrée de la mine : colline rocheuse, galerie, charpente, rails, wagonnet.
func _mine_entrance(cell: Vector2i, door_col: int) -> void:
	var door_x := float(cell.x + door_col) + 0.5
	var face_z := float(cell.y) + 1.75  # façade rocheuse
	# Colline : blocs de falaise en gradins derrière l'entrée
	for row in 3:
		for dx in range(-3 - row, 4 + row):
			var x := door_x + dx
			var z := face_z - 0.6 - row * 0.9
			var h := 1.9 + row * 0.7 + float(_hash(Vector2i(dx, row)) % 5) * 0.12
			var rock := _box(Vector3(1.02, h, 1.0), Color(0.52, 0.5, 0.48).darkened(0.05 * row + 0.03 * float(_hash(Vector2i(row, dx)) % 3)))
			_put(rock, Vector3(x, h / 2.0, z))
	for side: float in [-2.6, 2.6]:
		_put(_fitted("nature", "rock_largeA", 1.4), Vector3(door_x + side, 0, face_z - 0.2), side)
		_put(_fitted("nature", "rock_smallA", 0.6), Vector3(door_x + side * 0.75, 0, face_z + 0.4), side * 2.0)
	# Galerie sombre
	_put(_box(Vector3(1.5, 1.55, 0.3), Color(0.03, 0.025, 0.02)), Vector3(door_x, 0.78, face_z + 0.02))
	if not Village.mine_open():
		# Éboulement : des rochers bouchent la galerie
		for k in 7:
			var rock := _fitted("nature", "rock_largeA" if k < 3 else "rock_smallA", 0.75 if k < 3 else 0.45)
			_put(rock, Vector3(door_x - 0.5 + float(k % 3) * 0.5, float(k / 3) * 0.35, face_z + 0.35 + float(k % 2) * 0.15), float(k))
	# Charpente en bois : montants, linteau, contrefiches
	var wood := Color(0.48, 0.31, 0.18)
	for side: float in [-0.82, 0.82]:
		_put(_box(Vector3(0.16, 1.85, 0.16), wood), Vector3(door_x + side, 0.92, face_z + 0.22))
		var brace := _box(Vector3(0.1, 0.5, 0.1), wood)
		_put(brace, Vector3(door_x + side * 0.72, 1.62, face_z + 0.22))
		brace.rotation.z = 0.7 if side < 0 else -0.7
	_put(_box(Vector3(2.0, 0.2, 0.22), wood.darkened(0.1)), Vector3(door_x, 1.9, face_z + 0.22))
	# Panneau « MINE »
	_put(_box(Vector3(1.1, 0.34, 0.06), Color(0.62, 0.44, 0.26)), Vector3(door_x, 2.2, face_z + 0.3))
	var label := Label3D.new()
	label.text = "MINE"
	label.font = UiTheme.title_font()
	label.font_size = 64
	label.pixel_size = 0.005
	label.modulate = Color(0.22, 0.13, 0.08)
	label.outline_size = 0
	_put(label, Vector3(door_x, 2.2, face_z + 0.34))
	# Lanternes de part et d'autre
	for side: float in [-1.0, 1.0]:
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 0.8, 0.45)
		m.emission_enabled = true
		m.emission = Color(1, 0.7, 0.3)
		m.emission_energy_multiplier = 2.5
		sphere.material = m
		bulb.mesh = sphere
		_put(bulb, Vector3(door_x + side, 1.45, face_z + 0.35))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.75, 0.4)
		light.omni_range = 2.6
		light.light_energy = 1.0
		_put(light, Vector3(door_x + side, 1.5, face_z + 0.6))
	# Rails qui sortent de la galerie
	var iron := Color(0.35, 0.33, 0.33)
	for rail: float in [-0.22, 0.22]:
		_put(_box(Vector3(0.05, 0.05, 2.4), iron), Vector3(door_x + rail, 0.04, face_z + 1.15))
	for k in 7:
		_put(_box(Vector3(0.65, 0.04, 0.1), wood), Vector3(door_x, 0.02, face_z + 0.15 + k * 0.33))
	# Wagonnet chargé de minerai, à côté de l'entrée
	var cart := Vector3(door_x + 1.75, 0, face_z + 0.75)
	_put(_box(Vector3(0.6, 0.4, 0.45), Color(0.4, 0.3, 0.22)), cart + Vector3(0, 0.32, 0))
	for wx: float in [-0.2, 0.2]:
		for wz: float in [-0.24, 0.24]:
			var wheel := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.1
			cyl.bottom_radius = 0.1
			cyl.height = 0.05
			cyl.material = _flat_material(iron)
			wheel.mesh = cyl
			wheel.rotation.x = PI / 2.0
			_put(wheel, cart + Vector3(wx, 0.1, wz))
	for k in 4:
		var ore := _fitted("nature", "rock_smallA", 0.22)
		Models.tint(ore, [Color(1, 0.65, 0.45), Color(0.4, 0.38, 0.42), Color(0.7, 0.78, 0.95), Color(1, 0.88, 0.45)][k])
		_put(ore, cart + Vector3(-0.15 + (k % 2) * 0.3, 0.55, -0.1 + (k / 2) * 0.2))
	_put(_fitted("survival", "tool-pickaxe", 0.5), Vector3(door_x - 1.5, 0.05, face_z + 0.6), 0.6).rotation.z = PI / 2.0


## Bassin de la source, dans la forêt : sec, puis jaillissant à la fin.
func _spring(center: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.95
	cyl.bottom_radius = 1.0
	cyl.height = 0.35
	cyl.material = _flat_material(Color(0.6, 0.6, 0.6))
	ring.mesh = cyl
	_put(ring, center + Vector3(0, 0.17, 0))
	var inner := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.8
	disc.bottom_radius = 0.8
	disc.height = 0.02
	var flows := ForestMap.spring_flows()
	disc.material = _flat_material(Color(0.35, 0.65, 0.95) if flows else Color(0.45, 0.4, 0.35))
	inner.mesh = disc
	_put(inner, center + Vector3(0, 0.36, 0))
	for k in 6:
		var a := k * TAU / 6.0
		_put(_fitted("nature", "rock_smallA", 0.35), center + Vector3(cos(a), 0, sin(a)) * 1.15, a)
	if not flows:
		return
	var jet := CPUParticles3D.new()
	var drop := SphereMesh.new()
	drop.radius = 0.05
	drop.height = 0.1
	var mat := _flat_material(Color(0.65, 0.88, 1.0, 0.85))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = mat
	jet.mesh = drop
	jet.amount = 50
	jet.lifetime = 1.1
	jet.direction = Vector3.UP
	jet.spread = 15.0
	jet.initial_velocity_min = 2.4
	jet.initial_velocity_max = 3.0
	jet.gravity = Vector3(0, -6, 0)
	_put(jet, center + Vector3(0, 0.4, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.9, 1.0)
	light.omni_range = 3.0
	light.light_energy = 0.8
	_put(light, center + Vector3(0, 1.2, 0))


## Jardins des villageois : massifs fleuris bordés de petites clôtures,
## potager d'Odette, et un objet propre au métier de chacun.
func _build_gardens() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var batch := Models.Batch.new()
	var soil := Color(0.45, 0.31, 0.2)
	var picket := Color(0.93, 0.9, 0.84)
	var petals := [Color(0.95, 0.35, 0.4), Color(0.98, 0.82, 0.3), Color(0.75, 0.5, 0.95), Color(1, 0.6, 0.25), Color(1, 1, 1)]
	for g: Array in Village.gardens():
		var cell: Vector2i = g[0]
		var c := _cell3d(cell)
		var hsh := _hash(cell)
		match str(g[1]):
			"flowers", "veggies":
				_st_box(st, c + Vector3(0, 0.04, 0), Vector3(0.86, 0.08, 0.86), soil)
				# Petite clôture blanche sur le devant
				for k in 4:
					_st_box(st, c + Vector3(-0.39 + k * 0.26, 0.15, 0.45), Vector3(0.05, 0.3, 0.05), picket)
				_st_box(st, c + Vector3(0, 0.22, 0.45), Vector3(0.86, 0.04, 0.03), picket)
				if g[1] == "flowers":
					for k in 6:
						var px := -0.28 + float(k % 3) * 0.28
						var pz := -0.18 + float(k / 3) * 0.3
						var col: Color = petals[(hsh + k) % petals.size()]
						_st_box(st, c + Vector3(px, 0.14, pz), Vector3(0.04, 0.14, 0.04), Color(0.3, 0.6, 0.28))
						_st_box(st, c + Vector3(px, 0.24, pz), Vector3(0.13, 0.08, 0.13), col)
				else:
					var crops := ["carrot", "cabbage", "tomato", "leek"]
					for k in 4:
						_place(batch, "food", crops[(hsh + k) % crops.size()], c + Vector3(-0.2 + float(k % 2) * 0.4, 0.08, -0.18 + float(k / 2) * 0.32), 1.0, float(k))
			"planter":
				_st_box(st, c + Vector3(0, 0.18, 0), Vector3(0.8, 0.36, 0.5), Color(0.5, 0.34, 0.22))
				_st_box(st, c + Vector3(0, 0.38, 0), Vector3(0.72, 0.04, 0.42), soil)
				_place(batch, "nature", "plant_bushSmall", c + Vector3(-0.18, 0.38, 0), 1.0, float(hsh % 6))
				_place(batch, "nature", "flower_redA", c + Vector3(0.2, 0.38, 0.05), 0.9, 0.0)
			"bush":
				_place(batch, "nature", "plant_bushLarge", c, 1.4, float(hsh % 6))
				_place(batch, "nature", "flower_yellowA", c + Vector3(0.3, 0, 0.3), 0.8, 0.0)
			"crates":
				_place(batch, "survival", "box", c + Vector3(-0.15, 0, 0), 1.3, 0.2)
				_place(batch, "survival", "box-open", c + Vector3(0.2, 0, 0.15), 1.1, -0.3)
				_place(batch, "food", "pumpkin", c + Vector3(0.2, 0.3, 0.15), 0.8, 0.0)
			"barrels":
				_place(batch, "survival", "barrel", c + Vector3(-0.15, 0, -0.1), 1.8, 0.0)
				_place(batch, "survival", "barrel", c + Vector3(0.2, 0, 0.2), 1.6, 1.0)
			"logs":
				_place(batch, "nature", "log_stack", c, 1.2, float(hsh % 4))
			"hay":
				_st_box(st, c + Vector3(0, 0.25, 0), Vector3(0.8, 0.5, 0.6), Color(0.9, 0.78, 0.4))
				_st_box(st, c + Vector3(0, 0.25, 0.31), Vector3(0.82, 0.04, 0.02), Color(0.6, 0.45, 0.25))
			"flagpole":
				_st_box(st, c + Vector3(0, 0.9, 0), Vector3(0.06, 1.8, 0.06), Color(0.7, 0.7, 0.72))
				_st_box(st, c + Vector3(0.22, 1.6, 0), Vector3(0.4, 0.26, 0.02), Color(0.3, 0.5, 0.85))
				_st_box(st, c + Vector3(0, 0.08, 0), Vector3(0.4, 0.16, 0.4), Color(0.6, 0.58, 0.56))
			"easel":
				for leg: Vector3 in [Vector3(-0.15, 0.35, 0.1), Vector3(0.15, 0.35, 0.1), Vector3(0, 0.35, -0.12)]:
					_st_box(st, c + leg, Vector3(0.04, 0.7, 0.04), Color(0.55, 0.38, 0.22))
				_st_box(st, c + Vector3(0, 0.62, 0.14), Vector3(0.5, 0.4, 0.03), Color(0.97, 0.95, 0.9))
				_st_box(st, c + Vector3(-0.08, 0.66, 0.16), Vector3(0.18, 0.12, 0.01), Color(0.4, 0.65, 0.9))
				_st_box(st, c + Vector3(0.1, 0.56, 0.16), Vector3(0.14, 0.1, 0.01), Color(0.95, 0.75, 0.3))
			"fish":
				_place(batch, "survival", "barrel", c + Vector3(-0.15, 0, 0), 1.6, 0.0)
				_place(batch, "survival", "fish", c + Vector3(-0.15, 0.48, 0), 1.4, 0.5)
				# Filet de pêche tendu sur deux piquets
				for px: float in [0.1, 0.42]:
					_st_box(st, c + Vector3(px, 0.35, 0.1), Vector3(0.04, 0.7, 0.04), Color(0.5, 0.35, 0.22))
				_st_box(st, c + Vector3(0.26, 0.45, 0.1), Vector3(0.32, 0.4, 0.01), Color(0.75, 0.72, 0.6, 1))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mi.material_override = mat
	_static.add_child(mi)
	batch.build(_static)


## Bateau de pêche : coque en bois, banc, mât et voile roulée.
func _boat(c: Vector3, rot: float, h: int) -> void:
	var boat := Node3D.new()
	var hull_color: Color = [Color(0.75, 0.3, 0.25), Color(0.3, 0.5, 0.7), Color(0.95, 0.92, 0.85)][h % 3]
	# Coque peinte en planches, pont en bois, voile de toile
	var hull_mat := _plank_material(hull_color)
	var deck_mat := _plank_material(Color(0.62, 0.43, 0.27))
	var sail_mat := _flat_material(Color(0.95, 0.93, 0.85))
	for part: Array in [
		[Vector3(1.7, 0.22, 0.6), Vector3(0, -0.02, 0), hull_mat],
		[Vector3(1.5, 0.06, 0.48), Vector3(0, 0.1, 0), deck_mat],
		[Vector3(0.12, 0.26, 0.5), Vector3(0.8, 0.06, 0), hull_mat],
		[Vector3(0.12, 0.2, 0.44), Vector3(-0.8, 0.05, 0), hull_mat],
		[Vector3(0.3, 0.06, 0.5), Vector3(0.1, 0.16, 0), deck_mat],
		[Vector3(0.06, 1.1, 0.06), Vector3(-0.2, 0.65, 0), _flat_material(Color(0.45, 0.3, 0.18))],
		[Vector3(0.7, 0.1, 0.1), Vector3(0.1, 0.4, 0), sail_mat],
		[Vector3(1.72, 0.04, 0.62), Vector3(0, 0.07, 0), _flat_material(Color(0.95, 0.93, 0.88))],  # liseré
	]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		bm.material = part[2]
		b.mesh = bm
		b.position = part[1]
		boat.add_child(b)
	# Voile hissée : un triangle de toile
	var sail := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 0.8, 0.02)
	prism.left_to_right = 0.0
	prism.material = sail_mat
	sail.mesh = prism
	sail.position = Vector3(0.15, 0.85, 0)
	boat.add_child(sail)
	_put(boat, c + Vector3(0, -0.12, 0), rot)
	# Il tangue doucement
	var tw := boat.create_tween().set_loops()
	tw.tween_property(boat, "rotation:z", 0.05, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(boat, "rotation:z", -0.05, 1.6).set_trans(Tween.TRANS_SINE)


## Phare rayé rouge et blanc, sur son rocher ; allumé la nuit une fois réparé.
func _lighthouse(c: Vector3) -> void:
	_put(_box(Vector3(2.0, 0.3, 2.0), Color(0.55, 0.53, 0.5)), c + Vector3(0, 0.15, 0))
	for k in 6:
		var ring := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.72 - k * 0.04
		cyl.bottom_radius = 0.76 - k * 0.04
		cyl.height = 0.6
		cyl.material = _flat_material(Color(0.85, 0.2, 0.18) if k % 2 == 0 else Color(0.96, 0.95, 0.92))
		ring.mesh = cyl
		_put(ring, c + Vector3(0, 0.6 + k * 0.6, 0))
	var door := _box(Vector3(0.36, 0.55, 0.05), Color(0.35, 0.22, 0.14))
	_put(door, c + Vector3(-0.3, 0.55, 0.72))
	# Salle de la lanterne : vitrée, toit conique
	var top := 0.3 + 6 * 0.6
	_put(_box(Vector3(1.0, 0.08, 1.0), Color(0.3, 0.3, 0.32)), c + Vector3(0, top, 0))
	var glass := MeshInstance3D.new()
	var gc := CylinderMesh.new()
	gc.top_radius = 0.42
	gc.bottom_radius = 0.42
	gc.height = 0.6
	var lit := PortStory.lighthouse_lit()
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1, 0.95, 0.7, 0.9) if lit else Color(0.6, 0.75, 0.85, 0.5)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if lit:
		gm.emission_enabled = true
		gm.emission = Color(1, 0.85, 0.4)
		gm.emission_energy_multiplier = 2.0
	gc.material = gm
	glass.mesh = gc
	_put(glass, c + Vector3(0, top + 0.34, 0))
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.55
	cone.height = 0.45
	cone.material = _flat_material(Color(0.25, 0.25, 0.28))
	roof.mesh = cone
	_put(roof, c + Vector3(0, top + 0.86, 0))
	if not lit:
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.9, 0.6)
	light.omni_range = 6.0
	light.light_energy = 1.5
	_put(light, c + Vector3(0, top + 0.4, 0))
	# Faisceau qui tourne au-dessus de la mer
	var beam := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.05
	bc.bottom_radius = 0.9
	bc.height = 7.0
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1, 0.95, 0.7, 0.18)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bc.material = bm
	beam.mesh = bc
	var pivot := Node3D.new()
	_put(pivot, c + Vector3(0, top + 0.34, 0))
	beam.rotation.z = PI / 2.0
	beam.position = Vector3(3.5, 0, 0)
	pivot.add_child(beam)
	_lighthouse_beam = pivot


var _lighthouse_beam: Node3D


## Puits en pierre avec son petit toit.
func _well(c: Vector3) -> void:
	var stone := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.45
	cyl.height = 0.5
	cyl.material = _flat_material(Color(0.6, 0.58, 0.56))
	stone.mesh = cyl
	_put(stone, c + Vector3(0, 0.25, 0))
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.34
	disc.bottom_radius = 0.34
	disc.height = 0.02
	disc.material = _flat_material(Color(0.3, 0.55, 0.85))
	water.mesh = disc
	_put(water, c + Vector3(0, 0.45, 0))
	for side: float in [-0.38, 0.38]:
		_put(_box(Vector3(0.08, 0.9, 0.08), Color(0.45, 0.3, 0.18)), c + Vector3(side, 0.7, 0))
	_put(_box(Vector3(1.0, 0.08, 0.7), Color(0.7, 0.3, 0.25)), c + Vector3(0, 1.18, 0))


## Décor des événements : stand, guirlandes de fanions, lanternes volantes.
func _build_event_decor() -> void:
	var activity := Events.booth_activity()
	if activity == "":
		return
	var booth := _cell3d(Events.BOOTH)
	_put(_fitted("town", "stall-red" if activity == "contest" else "stall-green", 1.3), booth)
	var fest := Events.festival_today()
	if activity == "market":
		for k in 3:
			_put(_fitted("survival", "box", 0.4), booth + Vector3(-0.6 + k * 0.6, 0, 0.7))
		_put(_fitted("food", "pumpkin", 0.35), booth + Vector3(0.3, 0.6, 0.1))
	if fest.is_empty():
		return
	# Guirlandes de fanions colorés au-dessus de la place
	var corners := [Vector3(24.5, 0, 22.5), Vector3(37.5, 0, 22.5), Vector3(37.5, 0, 31.5), Vector3(24.5, 0, 31.5)]
	var colors := [Color(0.9, 0.25, 0.25), Color(0.95, 0.8, 0.2), Color(0.3, 0.6, 0.9), Color(0.4, 0.75, 0.35), Color(0.85, 0.45, 0.8)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		_put(_box(Vector3(0.08, 2.2, 0.08), Color(0.5, 0.35, 0.2)), a + Vector3(0, 1.1, 0))
		var n := int(a.distance_to(b) / 0.5)
		for k in n:
			var t := float(k) / n
			var p := a.lerp(b, t) + Vector3(0, 2.1 - sin(t * PI) * 0.4, 0)
			var flag := _box(Vector3(0.22, 0.22, 0.02), colors[k % colors.size()])
			_put(flag, p, atan2(b.x - a.x, b.z - a.z) + PI / 2.0)
			flag.rotation.z = PI / 4.0
	if str(fest.id) == "lantern_night":
		for k in 18:
			var glow := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.12
			sphere.height = 0.3
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1.0, 0.7, 0.35)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.6, 0.25)
			m.emission_energy_multiplier = 3.0
			sphere.material = m
			glow.mesh = sphere
			_put(glow, Vector3(25.0 + float(_hash(Vector2i(k, 1)) % 12), 2.4 + float(k % 4) * 0.4, 23.0 + float(_hash(Vector2i(1, k)) % 9)))
	else:
		# Pots de fleurs autour de la fontaine
		for k in 8:
			var a := k * TAU / 8.0
			_put(_fitted("nature", "pot_small", 0.4), Vector3(31.0, 0, 27.0) + Vector3(cos(a), 0, sin(a)) * 2.2)


## Serre vitrée : soubassement en bois, montants, vitres claires, toit de verre.
func _greenhouse(cell: Vector2i, size: Vector2i, door_col: int) -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.75, 0.92, 1.0, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wood := Color(0.55, 0.38, 0.24)
	var white := Color(0.92, 0.92, 0.9)
	var x0 := float(cell.x)
	var z0 := float(cell.y)
	var w := float(size.x)
	var d := float(size.y)
	var h := 1.6
	# Murs : soubassement + vitre, sur le pourtour (porte ouverte)
	for dx in size.x:
		for dy in size.y:
			var border := dx == 0 or dy == 0 or dx == size.x - 1 or dy == size.y - 1
			if not border or (dy == size.y - 1 and dx == door_col):
				continue
			var c := Vector3(x0 + dx + 0.5, 0, z0 + dy + 0.5)
			_put(_box(Vector3(1.0, 0.35, 1.0) * Vector3(1 if dy == 0 or dy == size.y - 1 else 0.25, 1, 1 if dx == 0 or dx == size.x - 1 else 0.25), wood), c + Vector3(0, 0.17, 0))
	for side: Array in [[Vector3(x0 + w / 2.0, 0, z0 + 0.5), Vector3(w, h, 0.04)], [Vector3(x0 + 0.5, 0, z0 + d / 2.0), Vector3(0.04, h, d)],
			[Vector3(x0 + w - 0.5, 0, z0 + d / 2.0), Vector3(0.04, h, d)]]:
		var pane := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = side[1]
		box.material = glass
		pane.mesh = box
		_put(pane, side[0] + Vector3(0, 0.35 + h / 2.0, 0))
	# Façade vitrée de part et d'autre de la porte
	for part: Array in [[x0 + 0.5, x0 + door_col], [x0 + door_col + 1, x0 + w - 0.5]]:
		var width := float(part[1]) - float(part[0])
		if width <= 0.05:
			continue
		var front := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(width, h, 0.04)
		fb.material = glass
		front.mesh = fb
		_put(front, Vector3((float(part[0]) + float(part[1])) / 2.0, 0.35 + h / 2.0, z0 + d - 0.5))
	# Montants blancs
	for dx in range(0, size.x, 2):
		for z: float in [z0 + 0.5, z0 + d - 0.5]:
			_put(_box(Vector3(0.07, h + 0.35, 0.07), white), Vector3(x0 + dx + 0.5, (h + 0.35) / 2.0, z))
	# Toit de verre à deux pans
	for k in 2:
		var roof := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(w - 0.8, 0.04, d / 2.0 + 0.1)
		rb.material = glass
		roof.mesh = rb
		roof.rotation.x = -0.45 if k == 0 else 0.45
		_put(roof, Vector3(x0 + w / 2.0, 0.35 + h + 0.38, z0 + 0.5 + (d - 1.0) * (0.25 if k == 0 else 0.75)))
	_put(_box(Vector3(w - 0.8, 0.08, 0.08), white), Vector3(x0 + w / 2.0, 0.35 + h + 0.82, z0 + d / 2.0))


## Lanterne du village (et sa lumière, allumée le soir).
func _village_lantern(cell: Vector2i) -> void:
	var c := _cell3d(cell)
	var lantern := _fitted("town", "lantern", 1.3)
	_put(lantern, c)
	var glow := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.09
	bulb.height = 0.18
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.35)
	mat.emission_energy_multiplier = 2.0
	bulb.material = mat
	glow.mesh = bulb
	glow.position = c + Vector3(0, 1.05, 0)
	glow.visible = false
	_static.add_child(glow)
	_lantern_glows.append(glow)
	if Settings.quality == 0:
		return  # économie : la lanterne brille, sans éclairer autour
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.45)
	light.omni_range = 3.2
	light.light_energy = 1.3
	light.position = c + Vector3(0, 1.1, 0.2)
	light.visible = false
	_static.add_child(light)
	_lanterns.append(light)


## Emplacement de bâtiment d'élevage à la ferme : terrain balisé, chantier
## (échafaudage) ou bâtiment terminé.
func _farm_plot(id: String) -> void:
	var plots: Dictionary = map.get("plots")
	if not plots.has(id):
		return
	var plot: Dictionary = plots[id]
	var cell: Vector2i = plot.cell
	var size: Vector2i = plot.size
	var door := int(Animals.building_info(id).get("door", 1))
	if Animals.is_built(id) and id == "greenhouse":
		_greenhouse(cell, size, door)
		return
	if Animals.is_built(id):
		if id == "coop":
			_house(cell, size, door, "wall-wood", Color(0.85, 0.7, 0.35))
		else:
			_house(cell, size, door, "wall-wood", Color(0.72, 0.22, 0.18))
		var hay := _fitted("nature", "log_stack" if id == "barn" else "pot_small", 0.5)
		_put(hay, _cell3d(cell + Vector2i(size.x - 1, size.y)) + Vector3(0.3, 0, -0.35))
		return
	var center := Vector3(cell.x + size.x / 2.0, 0, cell.y + size.y / 2.0)
	if Animals.under_construction(id):
		_put(_fitted("survival", "structure-floor", float(maxi(size.x, size.y))), center)
		_put(_fitted("survival", "structure", float(size.x) * 0.9), center + Vector3(0, 0, -0.2))
		_put(_fitted("survival", "resource-wood", 0.6), center + Vector3(size.x / 2.0 + 0.3, 0, size.y / 2.0 - 0.3))
		_put(_fitted("survival", "resource-stone", 0.5), center + Vector3(-size.x / 2.0 - 0.2, 0, size.y / 2.0 - 0.3))
		return
	# Terrain libre : piquets aux coins et panneau
	for corner: Vector2 in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.35, 0.08)
		box.material = _flat_material(Color(0.6, 0.42, 0.25))
		post.mesh = box
		_put(post, Vector3(cell.x + corner.x, 0.17, cell.y + corner.y))
	var rope := MeshInstance3D.new()
	var outline := BoxMesh.new()
	outline.size = Vector3(size.x, 0.02, size.y)
	var rmat := _flat_material(Color(0.62, 0.5, 0.32, 0.45))
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outline.material = rmat
	rope.mesh = outline
	_put(rope, center + Vector3(0, 0.01, 0))
	_put(_fitted("nature", "sign", 0.6), _cell3d(cell + Vector2i(door, size.y - 1)))


var _wall_batch: Models.Batch  # murs des maisons, dessinés en lot


func _wall(parent: Node3D, model: String, at: Vector3, rot: float) -> void:
	if _wall_batch != null:
		_wall_batch.add(Models.path("town", model), Transform3D(Basis(Vector3.UP, rot), at))
		return
	var n := _model("town", model, 1.0)
	n.position = at
	n.rotation.y = rot
	parent.add_child(n)


## Toit à deux pans, en rangées de tuiles, avec avant-toit et faîtage.
func _roof_into(st: SurfaceTool, origin: Vector3, w: float, d: float, color: Color) -> void:
	var o := 0.22  # débord
	var h := 1.05
	var rows := 5
	var x0 := origin.x - o
	var x1 := origin.x + w + o
	var zm := origin.z + d / 2.0
	for side in 2:
		var z_edge := origin.z + d + o if side == 0 else origin.z - o
		for r in rows:
			var t0 := float(r) / rows
			var t1 := float(r + 1) / rows
			var za := lerpf(z_edge, zm, t0)
			var zb := lerpf(z_edge, zm, t1)
			var ya := origin.y + h * t0
			var yb := origin.y + h * t1
			var shade := color.darkened(0.12 if side == 1 else 0.0)
			# Rangées de tuiles bien marquées : claire en haut, ombrée en bas
			var lip := 0.05
			st.set_color(shade.darkened(0.16) if r % 2 == 0 else shade.lightened(0.04))
			for p: Vector3 in [Vector3(x0, ya - lip, za), Vector3(x1, ya - lip, za), Vector3(x1, yb, zb), Vector3(x0, ya - lip, za), Vector3(x1, yb, zb), Vector3(x0, yb, zb)]:
				st.add_vertex(p)
		# Avant-toit (planche de rive)
		_st_box(st, Vector3((x0 + x1) / 2.0, origin.y - 0.03, z_edge), Vector3(x1 - x0, 0.06, 0.06), Color(0.45, 0.3, 0.2))
	# Pignons (couleur claire) et faîtage
	var gable := Color(0.93, 0.86, 0.72)
	st.set_color(gable)
	for gx: float in [origin.x + 0.02, origin.x + w - 0.02]:
		for p: Vector3 in [Vector3(gx, origin.y, origin.z + d), Vector3(gx, origin.y, origin.z), Vector3(gx, origin.y + h - 0.04, zm)]:
			st.add_vertex(p)
	_st_box(st, Vector3((x0 + x1) / 2.0, origin.y + h + 0.02, zm), Vector3(x1 - x0, 0.08, 0.12), color.darkened(0.3))


## Toit à deux pans (objet séparé) : bâtiments de la ferme.
func _roof(origin: Vector3, w: float, d: float, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_roof_into(st, Vector3.ZERO, w, d, color)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = origin
	return mi


# ------------------------------------------------------------ maison
## Intérieur chaleureux : plancher, murs en bois, lit, cuisine, cheminée.
func _build_home() -> void:
	_env.background_color = Color(0.08, 0.05, 0.04)
	var chars: Dictionary = map.get("_ground_chars")
	# Chaque intérieur a son style (sol, murs, tapis)
	var floor_style := "light"
	var wall_style := "wood"
	if map is InteriorMap:
		floor_style = (map as InteriorMap).floor_style
		wall_style = (map as InteriorMap).wall_style
	var floor_base: Color = {"light": Color(0.80, 0.62, 0.42), "dark": Color(0.55, 0.38, 0.25), "stone": Color(0.62, 0.6, 0.58)}.get(floor_style, Color(0.8, 0.62, 0.42))
	var rug: Color = [Color(0.32, 0.45, 0.72), Color(0.7, 0.25, 0.25), Color(0.35, 0.6, 0.38), Color(0.6, 0.4, 0.7)][absi(map.map_id.hash()) % 4]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in chars:
		var ch: String = chars[cell]
		if ch == "#":
			continue
		# Lames de parquet (ou dalles), une teinte par rangée
		var plank := floor_base.darkened(float((cell.y * 7 + (cell.x + cell.y) / 4) % 3) * 0.04)
		if floor_style == "stone":
			plank = floor_base.darkened(0.08 if (cell.x + cell.y) % 2 == 0 else 0.0)
		if ch == "r":
			# Tapis à bordure crème
			var edge: bool = chars.get(cell + Vector2i.LEFT, "") != "r" or chars.get(cell + Vector2i.RIGHT, "") != "r"
			plank = Color(0.93, 0.86, 0.7) if edge else rug
		elif ch == "D":
			plank = Color(0.4, 0.27, 0.17)
		_quad(st, Vector3(cell.x, 0, cell.y), Vector3(cell.x + 1, 0, cell.y + 1), plank)
	st.generate_normals()
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = st.commit()
	var fmat := StandardMaterial3D.new()
	fmat.vertex_color_use_as_albedo = true
	fmat.vertex_color_is_srgb = true
	fmat.roughness = 1.0
	floor_mi.material_override = fmat
	_static.add_child(floor_mi)
	var size: Vector2i = map.get("_map_size")
	var wall_color: Color = {"wood": Color(0.52, 0.35, 0.22), "cream": Color(0.86, 0.78, 0.62), "blue": Color(0.5, 0.6, 0.76),
		"green": Color(0.52, 0.68, 0.48), "stone": Color(0.5, 0.49, 0.5)}.get(wall_style, Color(0.52, 0.35, 0.22))
	var wall_mat := _flat_material(wall_color)
	var beam_mat := _flat_material(Color(0.36, 0.23, 0.14))
	for cell: Vector2i in chars:
		if chars[cell] != "#":
			continue
		# Mur du bas très bas, pour voir l'intérieur depuis la caméra
		var front := cell.y == size.y - 1
		var h := 0.35 if front else 1.6
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1, h, 1)
		box.material = beam_mat if (cell.x == 0 or cell.x == size.x - 1 or front) and (cell.x % 3 == 0) else wall_mat
		wall.mesh = box
		_put(wall, _cell3d(cell) + Vector3(0, h / 2.0, 0))
	# Fenêtres lumineuses sur le mur du fond
	for x in range(3, size.x - 2, 3):
		if chars.get(Vector2i(x, 0), "") != "#":
			continue
		var win := MeshInstance3D.new()
		var pane := QuadMesh.new()
		pane.size = Vector2(0.7, 0.55)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.75, 0.88, 1.0)
		wmat.emission_enabled = true
		wmat.emission = Color(0.55, 0.7, 0.9)
		wmat.emission_energy_multiplier = 0.6
		pane.material = wmat
		win.mesh = pane
		_put(win, Vector3(x + 0.5, 1.0, 1.005))
	for cell: Vector2i in chars:
		var c := _cell3d(cell)
		match chars[cell]:
			"Z", "B":
				_put(_fitted("nature", "bed", 1.4), c + Vector3(0.0, 0, 0.2), PI / 2.0)
				# Table de chevet et sa bougie
				_put(_box(Vector3(0.35, 0.4, 0.35), Color(0.45, 0.3, 0.2)), c + Vector3(0.75, 0.2, -0.25))
				_put(_fitted("dungeon", "potion", 0.25), c + Vector3(0.75, 0.4, -0.25))
			"k":
				# Cuisine : plan de travail clair, marmite, étagère colorée
				_put(_fitted("survival", "workbench", 0.9), c, PI)
				_put(_fitted("nature", "pot_large", 0.35), c + Vector3(0.15, 0.55, 0))
				var shelf := _box(Vector3(1.6, 0.08, 0.3), Color(0.55, 0.36, 0.22))
				_put(shelf, c + Vector3(1.0, 1.0, -0.35))
				for k in 4:
					var jar := _fitted("dungeon", "potion", 0.22)
					Models.tint(jar, [Color(1, 0.5, 0.5), Color(0.6, 1, 0.6), Color(0.6, 0.8, 1.2), Color(1.2, 1, 0.5)][k])
					_put(jar, c + Vector3(0.4 + k * 0.38, 1.04, -0.35))
			"t":
				_put(_fitted("dungeon", "table", 0.95), c)
				# Nappe à carreaux rouges et blancs
				var cloth := MeshInstance3D.new()
				var cq := BoxMesh.new()
				cq.size = Vector3(0.9, 0.02, 0.75)
				var cimg := Image.create(8, 8, false, Image.FORMAT_RGBA8)
				for yy in 8:
					for xx in 8:
						cimg.set_pixel(xx, yy, Color(0.85, 0.2, 0.18) if (xx / 2 + yy / 2) % 2 == 0 else Color(0.97, 0.95, 0.9))
				var cmat := StandardMaterial3D.new()
				cmat.albedo_texture = ImageTexture.create_from_image(cimg)
				cmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				cq.material = cmat
				cloth.mesh = cq
				_put(cloth, c + Vector3(0, 0.6, 0))
				_put(_fitted("food", "tomato", 0.15), c + Vector3(0.15, 0.66, 0))
				_put(_fitted("nature", "flower_yellowA", 0.3), c + Vector3(-0.2, 0.62, 0.05))
			"c":
				var chair := _fitted("dungeon", "chair", 0.7)
				Models.tint(chair, Color(0.95, 1.35, 1.0))  # chaises peintes en vert
				# Tournée vers la table, comme la personne qui s'y assoit
				var look: Vector2i = map.seats.get(cell, Vector2i.DOWN)
				_put(chair, c, atan2(float(look.x), float(look.y)) + PI)
			"x":
				var chest := _fitted("survival", "chest", 0.65)
				Models.tint(chest, Color(0.75, 0.85, 1.15))
				_put(chest, c, PI)
			"p":
				_put(_fitted("nature", "campfire_stones", 0.9), c)
				var flame := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.16
				cone.height = 0.4
				var fmat2 := StandardMaterial3D.new()
				fmat2.albedo_color = Color(1.0, 0.6, 0.2)
				fmat2.emission_enabled = true
				fmat2.emission = Color(1.0, 0.5, 0.15)
				fmat2.emission_energy_multiplier = 2.5
				cone.material = fmat2
				flame.mesh = cone
				_put(flame, c + Vector3(0, 0.22, 0))
				var fire := OmniLight3D.new()
				fire.light_color = Color(1.0, 0.6, 0.3)
				fire.omni_range = 3.5
				fire.light_energy = 1.0
				_put(fire, c + Vector3(0.5, 0.7, 0))
			"C":
				# Comptoir : caisson en bois, plateau clair
				_put(_box(Vector3(1.0, 0.55, 0.7), Color(0.5, 0.33, 0.2)), c + Vector3(0, 0.27, 0))
				_put(_box(Vector3(1.04, 0.06, 0.76), Color(0.85, 0.7, 0.5)), c + Vector3(0, 0.58, 0))
				if (cell.x + cell.y) % 3 == 0:
					_put(_fitted("dungeon", "coin", 0.18), c + Vector3(0.1, 0.62, 0))
			"S":
				# Étagère garnie de produits
				_put(_box(Vector3(0.95, 1.3, 0.45), Color(0.45, 0.3, 0.18)), c + Vector3(0, 0.65, -0.2))
				var goods := ["carrot", "tomato", "cabbage", "corn", "leek", "radish", "beet"]
				for level in 2:
					for k in 2:
						var g := _fitted("food", goods[(cell.x * 2 + level + k) % goods.size()], 0.24)
						_put(g, c + Vector3(-0.22 + k * 0.44, 0.45 + level * 0.5, 0.05))
			"K":
				# Bibliothèque aux livres colorés
				_put(_box(Vector3(0.95, 1.5, 0.45), Color(0.4, 0.26, 0.16)), c + Vector3(0, 0.75, -0.2))
				for level in 3:
					for k in 5:
						var book_col: Color = [Color(0.75, 0.2, 0.2), Color(0.2, 0.45, 0.75), Color(0.3, 0.6, 0.3), Color(0.85, 0.7, 0.2), Color(0.55, 0.3, 0.6)][(k + level + cell.x) % 5]
						_put(_box(Vector3(0.12, 0.32, 0.3), book_col), c + Vector3(-0.32 + k * 0.16, 0.3 + level * 0.45, 0.02))
			"M":
				_put(_box(Vector3(0.95, 0.8, 0.08), Color(0.55, 0.38, 0.22)), c + Vector3(0, 1.0, -0.4))
				for k in 4:
					_put(_box(Vector3(0.2, 0.25, 0.02), Color(0.95, 0.92, 0.85)), c + Vector3(-0.3 + k * 0.2, 1.0 + (k % 2) * 0.15, -0.35))
			"b":
				_put(_fitted("survival", "barrel", 0.6), c)
			"P":
				_put(_fitted("nature", "pot_large", 0.55), c)
				_put(_fitted("nature", "plant_bushLarge", 0.5), c + Vector3(0, 0.3, 0))
			"N":
				_put(_fitted("survival", "workbench-anvil", 0.8), c)
			"W":
				_put(_fitted("survival", "workbench", 0.9), c, PI)
			"L":
				_put(_fitted("nature", "log_stack", 0.9), c)
			"H":
				_put(_box(Vector3(0.9, 0.6, 0.9), Color(0.9, 0.78, 0.4)), c + Vector3(0, 0.3, 0))
			"A":
				_put(_fitted("pets", "animal-chick", 0.4), c, PI / 6.0)
			"E":
				# Petite scène de musique : estrade et guitare
				_put(_box(Vector3(0.95, 0.15, 0.95), Color(0.5, 0.32, 0.2)), c + Vector3(0, 0.07, 0))
				var guitar := _box(Vector3(0.18, 0.45, 0.08), Color(0.8, 0.5, 0.25))
				guitar.rotation.z = 0.4
				_put(guitar, c + Vector3(0.2, 0.4, -0.2))
			"F":
				_put(_fitted("survival", "barrel", 0.55), c)
				_put(_fitted("survival", "fish", 0.4), c + Vector3(0, 0.55, 0))
	# Plantes vertes sous les fenêtres et bannière au mur (maison)
	if map is HomeMap:
		for x: int in [2, 5, 10]:
			if chars.get(Vector2i(x, 1), "#") == "_":
				_put(_fitted("nature", "pot_small", 0.45), _cell3d(Vector2i(x, 1)) + Vector3(0, 0, -0.25))
		var banner := _fitted("dungeon", "banner", 1.1)
		Models.tint(banner, Color(0.7, 1.0, 0.75))
		_put(banner, Vector3(4.5, 0, 1.15))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.93, 0.82)
	lamp.omni_range = 9.0
	lamp.light_energy = 0.6
	_put(lamp, Vector3(size.x / 2.0, 2.5, size.y / 2.0))


# ------------------------------------------------------------ mine
func _build_mine() -> void:
	_env.background_color = Color(0.02, 0.02, 0.03)
	var batch := Models.Batch.new()
	var chars: Dictionary = map.get("_ground_chars")
	for cell: Vector2i in chars:
		var ch: String = chars[cell]
		var c := _cell3d(cell) - Vector3(0, 0, 0)
		if ch == "#":
			var open := false
			for dd: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if chars.get(cell + dd, "#") != "#":
					open = true
			if open:
				_place(batch, "dungeon", "wall", c, 1.0, 0.0)
		else:
			# Le sol de l'escalier qui descend est à part : on l'enlève quand on le trouve
			if cell == map.get("_ladder_cell"):
				_ladder_floor = _model("dungeon", "floor", 1.0)
				_put(_ladder_floor, c)
			elif ch != "U":
				_place(batch, "dungeon", "floor-detail" if _hash(cell) % 7 == 0 else "floor", c, 1.0, 0.0)
			if ch == "U":
				_stairs_up(cell)
	batch.build(_static)
	var mine := map as MineLevel
	if mine.elevator_cell != Vector2i(-1, -1):
		_elevator(_cell3d(mine.elevator_cell))
	if mine.treasure_cell != Vector2i(-1, -1):
		_build_treasure()


var _ladder_floor: Node3D
var _treasure: Node3D
var _treasure_open: bool = false
var _stair_arrows: Array = []  # [flèche, hauteur]

const STONE_STEP := Color(0.56, 0.52, 0.5)


## Escalier qui sort du sol vers le haut (on marche dessus pour remonter),
## éclairé par la lumière du dessus.
func _stairs_up(cell: Vector2i) -> void:
	var c := _cell3d(cell)
	# Les marches montent vers le mur (le haut de l'écran)
	for k in 5:
		var h := 0.14 * (k + 1)
		var step := _box(Vector3(0.9, h, 0.2), STONE_STEP.darkened(0.04 * k))
		_put(step, c + Vector3(0, h / 2.0, 0.4 - k * 0.2))
	for side: float in [-0.48, 0.48]:
		_put(_box(Vector3(0.06, 0.8, 1.0), Color(0.4, 0.36, 0.33)), c + Vector3(side, 0.4, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.8) if (map as MineLevel).level == 1 else Color(0.8, 0.85, 1.0)
	light.omni_range = 3.0
	light.light_energy = 1.4
	_put(light, c + Vector3(0, 1.4, -0.3))
	_stair_arrows.append([_put(_arrow(true), c + Vector3(0, 1.3, 0)), 1.3])


## Puits d'escalier qui s'enfonce dans le sol (révélé sous un rocher).
func _stairs_down(cell: Vector2i) -> void:
	var c := _cell3d(cell)
	if _ladder_floor == null or _ladder_floor.position.distance_to(c) > 0.1:
		# Escalier apparu sous un autre rocher : le sol est d'un seul tenant,
		# on dessine un trou sombre et des marches qui s'assombrissent.
		_put(_box(Vector3(0.92, 0.02, 0.92), Color(0.05, 0.04, 0.04)), c + Vector3(0, 0.012, 0))
		for k in 4:
			_put(_box(Vector3(0.8, 0.02, 0.2), STONE_STEP.darkened(0.2 + 0.18 * k)), c + Vector3(0, 0.025, 0.32 - k * 0.2))
		for edge: Array in [[Vector3(1.0, 0.08, 0.08), Vector3(0, 0.04, -0.5)], [Vector3(1.0, 0.08, 0.08), Vector3(0, 0.04, 0.5)],
				[Vector3(0.08, 0.08, 1.0), Vector3(-0.5, 0.04, 0)], [Vector3(0.08, 0.08, 1.0), Vector3(0.5, 0.04, 0)]]:
			_put(_box(edge[0], Color(0.5, 0.33, 0.2)), c + edge[1])
		_stair_arrows.append([_put(_arrow(false), c + Vector3(0, 1.0, 0)), 1.0])
		return
	_ladder_floor.queue_free()
	_ladder_floor = null
	var dark := Color(0.08, 0.07, 0.07)
	# Parois du puits
	for wall: Array in [[Vector3(0.96, 1.2, 0.04), Vector3(0, -0.6, -0.48)], [Vector3(0.96, 1.2, 0.04), Vector3(0, -0.6, 0.48)],
			[Vector3(0.04, 1.2, 0.96), Vector3(-0.48, -0.6, 0)], [Vector3(0.04, 1.2, 0.96), Vector3(0.48, -0.6, 0)]]:
		_put(_box(wall[0], Color(0.3, 0.27, 0.25)), c + wall[1])
	# Marches qui descendent vers le fond
	for k in 5:
		var top := -0.12 * (k + 1)
		_put(_box(Vector3(0.88, 0.12, 0.19), STONE_STEP.darkened(0.12 * (k + 1))), c + Vector3(0, top - 0.06, 0.38 - k * 0.19))
	_put(_box(Vector3(0.9, 0.05, 0.9), dark), c + Vector3(0, -1.2, 0))
	# Rebord en bois autour du trou
	for edge: Array in [[Vector3(1.0, 0.08, 0.08), Vector3(0, 0.04, -0.5)], [Vector3(1.0, 0.08, 0.08), Vector3(0, 0.04, 0.5)],
			[Vector3(0.08, 0.08, 1.0), Vector3(-0.5, 0.04, 0)], [Vector3(0.08, 0.08, 1.0), Vector3(0.5, 0.04, 0)]]:
		_put(_box(edge[0], Color(0.5, 0.33, 0.2)), c + edge[1])
	_stair_arrows.append([_put(_arrow(false), c + Vector3(0, 1.0, 0)), 1.0])


## Flèche lumineuse qui flotte au-dessus d'un escalier (haut ou bas).
func _arrow(up: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0 if up else 0.16
	cone.bottom_radius = 0.16 if up else 0.0
	cone.height = 0.28
	cone.radial_segments = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.2)
	mat.emission_energy_multiplier = 1.5
	cone.material = mat
	mi.mesh = cone
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Ascenseur de mineur : plateforme, montants en fer, poulie et lampe.
func _elevator(c: Vector3) -> void:
	var iron := Color(0.3, 0.3, 0.33)
	var wood := Color(0.55, 0.36, 0.22)
	_put(_box(Vector3(0.95, 0.1, 0.95), wood), c + Vector3(0, 0.05, 0))
	for corner: Vector2 in [Vector2(-0.44, -0.44), Vector2(0.44, -0.44), Vector2(-0.44, 0.44), Vector2(0.44, 0.44)]:
		_put(_box(Vector3(0.07, 2.4, 0.07), iron), c + Vector3(corner.x, 1.2, corner.y))
	for z: float in [-0.44, 0.44]:
		_put(_box(Vector3(0.95, 0.08, 0.08), iron), c + Vector3(0, 2.4, z))
		_put(_box(Vector3(0.95, 0.05, 0.05), iron), c + Vector3(0, 0.7, z))
	var wheel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = 0.08
	cyl.material = _flat_material(Color(0.6, 0.45, 0.25))
	wheel.mesh = cyl
	wheel.rotation.x = PI / 2.0
	_put(wheel, c + Vector3(0, 2.55, 0))
	_put(_box(Vector3(0.02, 2.1, 0.02), Color(0.7, 0.6, 0.4)), c + Vector3(0, 1.5, 0))  # câble
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.85, 0.5)
	m.emission_enabled = true
	m.emission = Color(1, 0.75, 0.35)
	m.emission_energy_multiplier = 2.5
	sphere.material = m
	bulb.mesh = sphere
	_put(bulb, c + Vector3(0.44, 2.0, 0.5))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.5)
	light.omni_range = 3.5
	light.light_energy = 1.2
	_put(light, c + Vector3(0.3, 1.8, 0.6))


## Coffre des paliers : il scintille tant qu'il n'est pas ouvert.
func _build_treasure() -> void:
	var mine := map as MineLevel
	if _treasure != null:
		_treasure.queue_free()
	_treasure = Node3D.new()
	_treasure.position = _cell3d(mine.treasure_cell)
	add_child(_treasure)
	_treasure_open = mine.treasure_opened()
	var chest := _fitted("survival", "box-open" if _treasure_open else "chest", 0.75)
	if not _treasure_open:
		Models.tint(chest, Color(1.15, 1.0, 0.7))
	_treasure.add_child(chest)
	if _treasure_open:
		return
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.4)
	glow.omni_range = 2.5
	glow.light_energy = 1.5
	glow.position.y = 0.8
	_treasure.add_child(glow)
	var sparkle := CPUParticles3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.03
	dot.height = 0.06
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1, 0.9, 0.5)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material = sm
	sparkle.mesh = dot
	sparkle.amount = 14
	sparkle.lifetime = 1.4
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparkle.emission_box_extents = Vector3(0.35, 0.2, 0.35)
	sparkle.direction = Vector3.UP
	sparkle.initial_velocity_min = 0.3
	sparkle.initial_velocity_max = 0.6
	sparkle.gravity = Vector3.ZERO
	sparkle.position.y = 0.5
	_treasure.add_child(sparkle)


func _sync_rocks() -> void:
	var data: Dictionary = map.get("_rock_data")
	for cell: Vector2i in _rocks.keys():
		if not data.has(cell):
			_rocks[cell].queue_free()
			_rocks.erase(cell)
	for cell: Vector2i in data:
		if _rocks.has(cell):
			continue
		var type: String = data[cell].type
		var model := "rock_smallC" if type == "pebbles" else "rock_smallA"
		var rock := _model("nature", model, 2.2)
		rock.position = _cell3d(cell)
		rock.rotation.y = float(_hash(cell) % 628) / 100.0
		var tint: Color = {
			"coal": Color(0.4, 0.38, 0.42), "copper": Color(1.0, 0.65, 0.45), "iron": Color(0.7, 0.78, 0.95),
			"gold": Color(1.0, 0.88, 0.45), "gem": Color(0.85, 0.6, 1.0),
		}.get(type, Color.WHITE)
		if tint != Color.WHITE:
			Models.tint(rock, tint)
		add_child(rock)
		_rocks[cell] = rock
	# Échelle de descente révélée
	var ladder: Vector2i = map.get("_ladder_cell")
	if map.get("_ladder_found") and not _rocks.has(ladder) and not has_meta("ladder"):
		set_meta("ladder", true)
		_stairs_down(ladder)
	# Coffre ouvert : on change son modèle
	if _treasure != null and (map as MineLevel).treasure_opened() != _treasure_open:
		_build_treasure()
	# Les flèches des escaliers flottent doucement
	var bob := sin(Time.get_ticks_msec() / 300.0) * 0.08
	for entry: Array in _stair_arrows:
		var arrow: Node3D = entry[0]
		if is_instance_valid(arrow):
			arrow.position.y = float(entry[1]) + bob
			arrow.rotation.y += 0.03


# ------------------------------------------------------------ ferme : cases vivantes
func _refresh_farm_all() -> void:
	for cell: Vector2i in _cells.keys():
		_cells[cell].queue_free()
	_cells.clear()
	var cells := {}
	for c: Vector2i in FarmState.tiles:
		cells[c] = true
	for c: Vector2i in FarmState.objects:
		cells[c] = true
	for c: Vector2i in FarmState.debris:
		cells[c] = true
	for c: Vector2i in cells:
		_refresh_farm_cell(c)


func _refresh_farm_cell(cell: Vector2i) -> void:
	if _cells.has(cell):
		_cells[cell].queue_free()
		_cells.erase(cell)
	var node := Node3D.new()
	node.position = _cell3d(cell)
	var rot := float(_hash(cell) % 628) / 100.0
	if FarmState.is_tilled(cell):
		var soil := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.86, 0.06, 0.86)
		soil.mesh = box
		soil.position.y = 0.03
		soil.material_override = _flat_material(Color(0.36, 0.24, 0.16) if FarmState.is_watered(cell) else Color(0.55, 0.38, 0.24))
		node.add_child(soil)
		var crop := FarmState.get_crop(cell)
		if crop != "":
			var plant := _crop_model(crop, FarmState.crop_stage(cell))
			if plant != null:
				plant.position.y = 0.05
				plant.rotation.y = rot
				node.add_child(plant)
	match str(FarmState.objects.get(cell, "")):
		"chest":
			var chest := _model("survival", "chest", 2.4)
			node.add_child(chest)
		"sprinkler", "quality_sprinkler":
			var s := _billboard(GameData.item_icon(str(FarmState.objects[cell])), 0.04)
			s.position.y = 0.32
			node.add_child(s)
		"tree":
			node.add_child(_fruit_tree(cell))
	if FarmState.debris.has(cell):
		var debris: Node3D
		match str(FarmState.debris[cell].type):
			"weed":
				debris = _model("nature", "grass_leafsLarge", 1.8)
			"twig":
				debris = _model("nature", "log", 1.0)
			"stone":
				debris = _model("nature", "rock_smallA", 1.8)
			_:
				debris = _model("nature", "stump_old", 2.4)
		debris.rotation.y = rot
		node.add_child(debris)
	if node.get_child_count() == 0:
		node.free()
		return
	add_child(node)
	_cells[cell] = node


## Plante en 3D selon son stade et son apparence (data/crops.json, « look »).
## Arbre fruitier : jeune pousse, arbuste, puis arbre avec ses fruits.
func _fruit_tree(cell: Vector2i) -> Node3D:
	var t: Dictionary = FarmState.trees[cell]
	var info: Dictionary = FarmState.tree_data[t.type]
	var stage := FarmState.tree_stage(cell)
	var autumn := TimeManager.season == 2
	var model := "tree_default_fall" if autumn else "tree_default"
	if TimeManager.season == 3:
		model = "tree_default_dark" if ResourceLoader.exists(Models.path("nature", "tree_default_dark")) else "tree_default"
	var tree := _model("nature", model, [0.45, 0.9, 1.55][stage])
	tree.rotation.y = float(_hash(cell) % 628) / 100.0
	var holder := Node3D.new()
	holder.add_child(tree)
	# Fleurs blanches au printemps pour le cerisier, fruits mûrs sinon
	var count := int(t.fruits) * 3
	var color := Color(str(info.color))
	for k in count:
		var fruit := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.07 if t.type != "cherry" else 0.05
		sphere.height = sphere.radius * 2.0
		sphere.material = _flat_material(color)
		fruit.mesh = sphere
		var a := k * 2.4
		fruit.position = Vector3(cos(a) * 0.38, 0.95 + float(k % 3) * 0.18, sin(a) * 0.38)
		holder.add_child(fruit)
	return holder


func _crop_model(crop: String, stage: int) -> Node3D:
	var look: Dictionary = GameData.crop(crop).get("look", {})
	var type := str(look.get("type", "root"))
	var color := Color(str(look.get("color", "#ffffff")))
	if stage <= 0:
		return _model("nature", "crops_leafsStageA", 0.6)
	match type:
		"corn":
			return _model("nature", ["crops_cornStageA", "crops_cornStageB", "crops_cornStageC", "crops_cornStageD"][mini(stage, 3)], 0.8)
		"grain":
			return _model("nature", "crops_wheatStageA" if stage < 3 else "crops_wheatStageB", 1.2 + stage * 0.15)
		"tall":
			# Tournesol : une tige qui monte, puis une grande fleur jaune
			var stem := _model("nature", ["crops_cornStageA", "crops_cornStageB", "crops_cornStageC", "crops_cornStageC"][mini(stage, 3)], 0.8)
			if stage >= 3:
				var head := MeshInstance3D.new()
				var disc := CylinderMesh.new()
				disc.top_radius = 0.22
				disc.bottom_radius = 0.22
				disc.height = 0.05
				disc.material = _flat_material(color)
				head.mesh = disc
				head.rotation.x = PI / 2.5
				head.position = Vector3(0, 1.0, 0.08) / 0.8
				stem.add_child(head)
				var heart := _box(Vector3(0.18, 0.06, 0.18), Color(0.4, 0.25, 0.1))
				heart.rotation.x = PI / 2.5
				heart.position = Vector3(0, 1.0, 0.11) / 0.8
				stem.add_child(heart)
			return stem
	if stage == 1:
		return _model("nature", "crops_leafsStageA", 1.2)
	if stage == 2:
		var young := _model("nature", "crops_leafsStageB", 1.2)
		if type == "ground":
			young.scale = Vector3.ONE * 1.4
		return young
	match type:
		"root":
			var spec: Array = look.get("model", ["nature", "crop_carrot"])
			if spec[0] == "nature":
				var plant := _model("nature", spec[1], 1.4)
				if look.has("color"):
					Models.tint(plant, color)
				return plant
			# Légume racine à moitié sorti de terre, sous ses feuilles
			var leaves := _model("nature", "crops_leafsStageB", 1.0)
			var root := _fitted(spec[0], spec[1], 0.44)
			if look.has("color"):
				Models.tint(root, color)
			root.position = Vector3(0, 0.04, 0.12)
			leaves.add_child(root)
			return leaves
		"head":
			var head := _model("food", "cabbage", 1.6)
			if look.has("color"):
				Models.tint(head, color * Color(1.3, 1.3, 1.3))
			return head
		"ground":
			var spec: Array = look.get("model", ["nature", "crop_pumpkin"])
			return _model(spec[0], spec[1], 1.3)
		"bush":
			var bush := _model("nature", "crops_leafsStageB", 1.3)
			var fruit_spec: Array = look.get("model", [])
			for k in 4:
				var fruit: Node3D
				if not fruit_spec.is_empty():
					fruit = _model(fruit_spec[0], fruit_spec[1], 1.6)
				else:
					var berry := MeshInstance3D.new()
					var sphere := SphereMesh.new()
					sphere.radius = 0.06
					sphere.height = 0.12
					sphere.material = _flat_material(color)
					berry.mesh = sphere
					fruit = berry
				fruit.position = Vector3(cos(k * 1.7) * 0.13, 0.2 + k * 0.07, sin(k * 1.7) * 0.13) / 1.3
				bush.add_child(fruit)
			return bush
	return _model("nature", "crops_leafsStageB", 1.3)


# ------------------------------------------------------------ joueur
## Personnage assis : hauteur des hanches et recul vers le dossier
const SEAT_HEIGHT := 0.0
const SEAT_BACK := 0.12


func _build_player() -> void:
	_player3d = _model("blocky", "character-a", CHARACTER_SCALE)
	add_child(_player3d)
	var shadow := _blob(1.6)
	_player3d.add_child(shadow)
	_player_anim = _player3d.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var arms := _player3d.find_children("arm-right", "", true, false)
	_hand = arms[0] as Node3D if not arms.is_empty() else _player3d
	map.player.gesture_started.connect(_on_gesture)


func _on_gesture(gesture: String) -> void:
	var anim: String = {"strike": "attack-melee-right", "sweep": "attack-melee-right", "cast": "attack-melee-right", "pour": "interact-right", "bend": "pick-up"}.get(gesture, "interact-right")
	_player_anim.play(anim, 0.05, 1.6)
	var slot: Variant = Inventory.get_selected()
	var id: String = "" if slot == null or gesture == "bend" else str(slot.id)
	_show_tool(id)
	if gesture == "strike" and slot != null and GameData.item(str(slot.id)).get("type") == "weapon":
		_slash()


func _show_tool(id: String) -> void:
	if id == _tool_id:
		if _tool3d != null:
			_tool3d.visible = id != ""
		return
	_tool_id = id
	if _tool3d != null:
		_tool3d.queue_free()
		_tool3d = null
	if id == "fishing_rod":
		_tool3d = _rod()
		_hand.add_child(_tool3d)
		return
	if TOOL_MODELS.has(id):
		var spec: Array = TOOL_MODELS[id]
		_tool3d = _model(spec[0], spec[1], 1.0)
		# Taille à l'écran ~TOOL_SIZE case, quel que soit le modèle d'origine
		var size := _model_size(_tool3d)
		var s := TOOL_SIZE / maxf(size, 0.05) / CHARACTER_SCALE
		_tool3d.scale = Vector3.ONE * s
		# Manche dans la main, outil pointé vers l'avant
		_tool3d.position = Vector3(0, -0.85, 0.1)
		_tool3d.rotation_degrees = Vector3(90, 0, 0)
		_hand.add_child(_tool3d)


## Plus grande dimension d'un modèle (pour le mettre à la bonne taille).
func _model_size(root: Node3D) -> float:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var t := mi.transform
		var p := mi.get_parent()
		while p != null and p != root:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		var b := t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return maxf(box.size.x, maxf(box.size.y, box.size.z))


func _sync_player(delta: float) -> void:
	var p := map.player
	_player3d.position = _to3d(p.position)
	var f := Vector2(p.facing)
	var target := atan2(f.x, f.y)
	_player3d.rotation.y = lerp_angle(_player3d.rotation.y, target, minf(1.0, delta * 14.0))
	if p.seated:
		# Assis sur le banc ou la chaise
		_player3d.rotation.y = target
		_player3d.position += Vector3(0, SEAT_HEIGHT, 0) - Vector3(f.x, 0, f.y) * SEAT_BACK
		if _tool3d != null:
			_tool3d.visible = false
		if _player_anim.current_animation != "sit":
			_player_anim.play("sit", 0.2)
		return
	if not p.busy():
		if _tool3d != null:
			_tool3d.visible = false
		var moving := p.velocity.length() > 5.0
		var want := "walk" if moving else "idle"
		if _player_anim.current_animation != want:
			_player_anim.play(want, 0.15, 1.5 if moving else 1.0)
	elif _tool3d != null and _tool_id != "":
		_tool3d.visible = true


# ------------------------------------------------------------ acteurs (miroir 2D -> 3D)
func _sync_proxies() -> void:
	var entities: Node = map.get("_entities")
	var seen := {}
	for child in entities.get_children():
		if child == map.player or child.has_meta("no3d") or not (child is Node2D):
			continue
		var id := child.get_instance_id()
		seen[id] = true
		var proxy: Node3D = _proxies.get(id)
		if proxy == null:
			proxy = _make_proxy(child)
			if proxy == null:
				continue
			_proxies[id] = proxy
			add_child(proxy)
		_update_proxy(child, proxy)
	for id: int in _proxies.keys():
		if not seen.has(id):
			_proxies[id].queue_free()
			_proxies.erase(id)


func _make_proxy(node: Node) -> Node3D:
	if node is Npc:
		# Chaque habitant porte la tenue de son métier ; Théo est un enfant : plus petit
		var npc_id := (node as Npc).id
		var npc := Models.npc(npc_id)
		npc.scale = Vector3.ONE * CHARACTER_SCALE * (0.75 if npc_id == "theo" else 1.0)
		npc.add_child(_blob(1.6))
		npc.set_meta("npc_id", (node as Npc).id)
		return npc
	if node is Monster:
		var kind: String = (node as Monster).kind
		if kind == "slime":
			var slime := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.24
			sphere.height = 0.34
			var mat := _flat_material(Color(0.45, 0.85, 0.5, 0.85))
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sphere.material = mat
			slime.mesh = sphere
			slime.position.y = 0.17
			var holder := Node3D.new()
			holder.add_child(slime)
			return holder
		if kind == "bat":
			var bat := _fitted("pets", "animal-parrot", 0.5)
			Models.tint(bat, Color(0.35, 0.3, 0.45))
			var holder := Node3D.new()
			holder.add_child(bat)
			holder.add_child(_blob(0.5))
			return holder
		var look: Array = MONSTER_LOOKS.get(kind, MONSTER_LOOKS["rat"])
		var m := _model("dungeon", look[0], look[2])
		Models.tint(m, look[1])
		m.add_child(_blob(0.9))
		return m
	if node is Critter:
		var look: Array = PET_MODELS.get((node as Critter).kind, PET_MODELS["chicken"])
		var holder := Node3D.new()
		holder.add_child(_fitted("pets", look[0], look[1]))
		holder.add_child(_blob(float(look[1]) * 1.4))
		return holder
	if node is Pickup or node is Sprite2D:
		var item := str(node.get_meta("item_id", "")) if node.has_meta("item_id") else (node as Pickup).item_id if node is Pickup else ""
		return _item_node(item, node)
	return null


func _item_node(item: String, node: Node) -> Node3D:
	var holder := Node3D.new()
	if ITEM_MODELS.has(item):
		var spec: Array = ITEM_MODELS[item]
		holder.add_child(_model(spec[0], spec[1], spec[2]))
	else:
		var tex: Texture2D = GameData.item_icon(item) if item != "" else (node as Sprite2D).texture if node is Sprite2D else null
		if tex == null:
			return null
		var s := _billboard(tex, 0.03)
		s.position.y = 0.28
		holder.add_child(s)
	return holder


func _update_proxy(node: Node2D, proxy: Node3D) -> void:
	var height := 0.0
	if node is Monster:
		var look: Array = MONSTER_LOOKS.get((node as Monster).kind, [null, null, 1.0, 0.0])
		height = float(look[3])
		if (node as Monster).kind == "bat":
			height = 0.45
		height += sin(Time.get_ticks_msec() / 200.0 + node.get_instance_id()) * (0.08 if height > 0.0 else 0.0)
	elif node is Pickup:
		height = 0.08 + absf(sin(Time.get_ticks_msec() / 250.0)) * 0.08
		proxy.rotation.y += 0.04
	var target := _to3d(node.position, height)
	var moved := target - proxy.position
	proxy.position = target
	proxy.visible = node.visible
	if node is Npc or node is Monster or node is Critter:
		var walking := Vector2(moved.x, moved.z).length() > 0.002
		if walking:
			proxy.rotation.y = lerp_angle(proxy.rotation.y, atan2(moved.x, moved.z), 0.25)
		if not proxy.has_meta("ap"):
			var found := proxy.find_children("*", "AnimationPlayer", true, false)
			proxy.set_meta("ap", found[0] if not found.is_empty() else false)
		var ap_value: Variant = proxy.get_meta("ap")
		var ap: AnimationPlayer = ap_value if ap_value is AnimationPlayer else null
		if ap != null:
			var want := "walk" if walking else ("static" if node is Critter else "idle")
			if ap.current_animation != want and ap.has_animation(want):
				ap.play(want, 0.2)


# ------------------------------------------------------------ boucle
func _process(delta: float) -> void:
	if map == null or not is_instance_valid(map) or map.player == null:
		return
	_sync_player(delta)
	_sync_proxies()
	if _is_mine:
		_sync_rocks()
		_lantern.position = _player3d.position + Vector3(0, 1.2, 0.3)
	# Curseur sur la case visée
	var target: Vector2i = map.get("_target_cell")
	_cursor.visible = not map.fishing.busy()
	_cursor.position = _cell3d(target) + Vector3(0, 0.02, 0)
	if _mail_alert != null:
		_mail_alert.visible = Mail.has_mail()
		_mail_alert.offset.y = sin(Time.get_ticks_msec() / 200.0) * 2.0
	# Pêche : bouchon et « ! »
	var fishing := map.fishing
	_bobber.visible = fishing.busy()
	if fishing.busy():
		# La canne reste en main pendant toute la pêche
		if _tool_id != "fishing_rod":
			_show_tool("fishing_rod")
		if _tool3d != null:
			_tool3d.visible = true
		var bob: Vector2 = fishing.get("_bobber_base")
		var reel := fishing.state == Fishing.State.REELING
		if not _bobber_flying:
			_bobber.position = _to3d(bob, -0.06 + sin(Time.get_ticks_msec() / 300.0) * 0.02 - (0.06 if fishing.state == Fishing.State.BITE else 0.0))
			if reel:
				_bobber.position += Vector3(randf_range(-0.04, 0.04), 0, randf_range(-0.04, 0.04))
		# Petites touches : des ronds dans l'eau de temps en temps
		_nibble -= delta
		if _nibble <= 0.0 and fishing.state == Fishing.State.WAITING and not _bobber_flying:
			_nibble = randf_range(0.8, 2.0)
			_ripple(_bobber.position, 0.5)
		_draw_line(reel)
	else:
		(_line.mesh as ImmediateMesh).clear_surfaces()
	_bite_alert.visible = fishing.state == Fishing.State.BITE
	_bite_alert.position = _player3d.position + Vector3(0, 1.45, 0)
	if _water_mat != null:
		_water_mat.uv1_offset.x += delta * 0.02
	if _lighthouse_beam != null:
		_lighthouse_beam.rotation.y += delta * 0.8
		var hour := TimeManager.minutes / 60
		_lighthouse_beam.visible = hour >= 19 or hour < 6
	_update_camera(false, delta)
	if _weather != null:
		_weather.position = _cam_target + Vector3(0, 6, 0)


func _update_camera(snap: bool = false, delta: float = 0.016) -> void:
	if map == null or not is_instance_valid(map):
		return
	var target := _to3d(map.player.position) + Vector3(0, 0.4, 0)
	if _is_home:
		# Petites pièces : on cadre toute la pièce, en suivant un peu le joueur
		var size: Vector2i = map.get("_map_size")
		var center := Vector3(size.x / 2.0, 0.4, size.y / 2.0 + 0.4)
		target = center + (target - center) * 0.5
	_cam_target = target if snap else _cam_target.lerp(target, minf(1.0, delta * 6.0))
	var distance := 17.0 / Settings.zoom
	var offset := Vector3(0, sin(CAMERA_PITCH), cos(CAMERA_PITCH)) * distance
	camera.position = _cam_target + offset
	camera.look_at(_cam_target, Vector3.UP)


## Secousse de la caméra 3D (coups, arbres qui tombent, rochers...).
var _shake_tween: Tween


func shake(strength: float = 2.0, duration: float = 0.15) -> void:
	if camera == null:
		return
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var amp := strength * 0.03
	var steps := maxi(2, int(duration / 0.03))
	for i in steps:
		var k := 1.0 - float(i) / steps
		_shake_tween.tween_property(camera, "h_offset", randf_range(-1, 1) * amp * k, 0.03)
		_shake_tween.parallel().tween_property(camera, "v_offset", randf_range(-1, 1) * amp * k, 0.03)
	_shake_tween.tween_property(camera, "h_offset", 0.0, 0.03)
	_shake_tween.parallel().tween_property(camera, "v_offset", 0.0, 0.03)


func _build_cursor() -> void:
	_cursor = MeshInstance3D.new()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var edge := x == 0 or y == 0 or x == 15 or y == 15
			img.set_pixel(x, y, Color(1, 1, 1, 0.85) if edge else Color(1, 1, 1, 0.06))
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	_cursor.mesh = quad
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cursor)


# ------------------------------------------------------------ lumière, saisons, météo
func _update_light(_h: int, _m: int) -> void:
	if _is_mine:
		_sun.visible = false
		var depth := clampf(float((map as MineLevel).level) / MineLevel.MAX_LEVEL, 0.0, 1.0)
		_env.ambient_light_color = Color(0.45, 0.42, 0.5).lerp(Color(0.12, 0.1, 0.16), depth)
		_env.ambient_light_energy = 1.0
		return
	if _is_home:
		_sun.light_energy = 0.55
		_sun.light_color = Color(1.0, 0.95, 0.88)
		_env.ambient_light_color = Color(0.72, 0.68, 0.64)
		_env.ambient_light_energy = 0.6
		return
	var hours := TimeManager.minutes / 60.0
	var night := clampf((hours - 18.0) / 4.0, 0.0, 1.0)
	var lit := hours >= 18.5 or hours < 6.0
	for l in _lanterns:
		l.visible = lit
	for g in _lantern_glows:
		g.visible = lit
	if _lamp_off != null and is_instance_valid(_lamp_off):
		_lamp_off.visible = not lit
	var rain := TimeManager.is_raining() or TimeManager.is_snowing()
	_sun.light_energy = lerpf(0.85, 0.1, night) * (0.6 if rain else 1.0)
	_sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(0.55, 0.6, 1.0), night)
	_env.ambient_light_color = Color(0.62, 0.66, 0.78).lerp(Color(0.16, 0.2, 0.36), night)
	_env.ambient_light_energy = 0.55
	if map is ForestMap:
		# Identité de la forêt : lumière verte, filtrée par les feuilles
		_sun.light_energy *= 0.8
		_env.ambient_light_color = Color(0.5, 0.68, 0.55).lerp(Color(0.12, 0.2, 0.2), night)
	if map is Village:
		# Identité du village : lumière dorée, chaleureuse
		_sun.light_color = Color(1.0, 0.92, 0.78).lerp(Color(0.6, 0.55, 0.9), night)
		_env.ambient_light_color = Color(0.7, 0.64, 0.66).lerp(Color(0.2, 0.18, 0.34), night)
	var sky := Color(0.55, 0.75, 0.92).lerp(Color(0.05, 0.07, 0.15), night)
	_env.background_color = sky.darkened(0.25) if rain else sky


func _on_day_started(_d: int, _s: int, _y: int) -> void:
	# Nouvelle saison : on reconstruit le décor (couleurs, arbres)
	if not _is_mine and not _is_home:
		_lanterns.clear()
		_lantern_glows.clear()
		_static.queue_free()
		_static = Node3D.new()
		add_child(_static)
		_build_ground()
		_build_props()
	_update_light(0, 0)
	_update_weather()


func _update_weather() -> void:
	var kind := "rain" if TimeManager.is_raining() else ("snow" if TimeManager.is_snowing() else "")
	if _is_mine or _is_home:
		kind = ""
	if kind == _weather_kind:
		return
	_weather_kind = kind
	if _weather != null:
		_weather.queue_free()
		_weather = null
	if kind == "":
		return
	_weather = CPUParticles3D.new()
	var drop: Mesh
	if kind == "rain":
		var box := BoxMesh.new()
		box.size = Vector3(0.015, 0.22, 0.015)
		drop = box
	else:
		var flake := SphereMesh.new()
		flake.radius = 0.035
		flake.height = 0.07
		drop = flake
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.85, 1.0, 0.7) if kind == "rain" else Color(1, 1, 1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = mat
	_weather.mesh = drop
	_weather.amount = int((400 if kind == "rain" else 220) * [0.35, 0.65, 1.0][Settings.quality])
	_weather.lifetime = 0.9 if kind == "rain" else 5.0
	_weather.preprocess = 3.0
	_weather.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_weather.emission_box_extents = Vector3(9, 0.5, 9)
	_weather.direction = Vector3(0.15, -1, 0)
	_weather.spread = 3.0 if kind == "rain" else 25.0
	_weather.gravity = Vector3(0, -30 if kind == "rain" else -1.2, 0)
	_weather.initial_velocity_min = 6.0 if kind == "rain" else 0.4
	_weather.initial_velocity_max = 8.0 if kind == "rain" else 0.9
	_weather.local_coords = false
	add_child(_weather)


# ------------------------------------------------------------ pêche (3D)
var _line: MeshInstance3D
var _bobber_flying: bool = false
var _nibble: float = 1.0


## Canne à pêche : manche en bois, moulinet, scion fin ; « Tip » = bout.
func _rod() -> Node3D:
	var rod := Node3D.new()
	var s := 1.0 / CHARACTER_SCALE
	for part: Array in [[Vector3(0.05, 0.5, 0.05), Vector3(0, 0.0, 0), Color(0.45, 0.3, 0.18)], [Vector3(0.025, 0.75, 0.025), Vector3(0, 0.6, 0), Color(0.85, 0.8, 0.7)]]:
		var b := _box(part[0], part[2])
		b.position = part[1]
		rod.add_child(b)
	var reel := _box(Vector3(0.1, 0.1, 0.06), Color(0.3, 0.32, 0.35))
	reel.position = Vector3(0.05, 0.12, 0)
	rod.add_child(reel)
	var tip := Node3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0, 0.98, 0)
	rod.add_child(tip)
	rod.scale = Vector3.ONE * s
	rod.position = Vector3(0, -0.6, 0.15)
	rod.rotation_degrees = Vector3(70, 0, 0)
	return rod


func _rod_tip() -> Vector3:
	if _tool3d != null and _tool3d.has_node("Tip"):
		return (_tool3d.get_node("Tip") as Node3D).global_position
	return _player3d.position + Vector3(0, 1.0, 0)


## Fil de pêche : de la canne au bouchon, avec un peu de mou (tendu au moulinet).
func _draw_line(taut: bool) -> void:
	var mesh := _line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var a := _rod_tip()
	var b := _bobber.position + Vector3(0, 0.05, 0)
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var sag := 0.05 if taut else 0.35
	for k in 13:
		var t := k / 12.0
		mesh.surface_add_vertex(a.lerp(b, t) - Vector3(0, sin(t * PI) * sag, 0))
	mesh.surface_end()


## Lancer : le bouchon part de la canne et décrit un arc jusqu'à l'eau.
func _on_cast(target: Vector2) -> void:
	_show_tool("fishing_rod")
	var start := _rod_tip()
	var end := _to3d(target, -0.06)
	_bobber_flying = true
	var tw := create_tween()
	tw.tween_interval(0.18)  # le temps de lever la canne
	tw.tween_method(func(t: float) -> void:
		_bobber.position = start.lerp(end, t) + Vector3(0, sin(t * PI) * 1.3, 0), 0.0, 1.0, 0.5)
	tw.tween_callback(func() -> void:
		_bobber_flying = false
		_ripple(end, 0.9)
		fx_burst(target, [Color(0.75, 0.88, 1.0), Color(1, 1, 1)], 10, 50.0))


## La touche : le bouchon plonge, gerbe d'eau et grands ronds.
func _on_bite() -> void:
	_ripple(_bobber.position, 1.3)
	_ripple(_bobber.position, 0.8)


## Prise : le poisson jaillit de l'eau et vole jusqu'au joueur.
func _on_caught(fish_id: String) -> void:
	var fish := _fitted("survival", "fish-large" if int(GameData.fish(fish_id).get("difficulty", 30)) > 50 else "fish", 0.45)
	var start := _bobber.position
	add_child(fish)
	fish.position = start
	_ripple(start, 1.2)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var end := _player3d.position + Vector3(0, 0.9, 0)
		fish.position = start.lerp(end, t) + Vector3(0, sin(t * PI) * 1.6, 0)
		fish.rotation = Vector3(t * TAU, t * PI, 0), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(fish.queue_free)


## Rond dans l'eau qui s'élargit et s'efface.
func _ripple(at: Vector3, size: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.2
	torus.rings = 16
	torus.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.97, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = mat
	ring.mesh = torus
	ring.position = Vector3(at.x, -0.07, at.z)
	ring.scale = Vector3(1, 0.15, 1)
	add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(size * 3.0, 0.15, size * 3.0), 0.9)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(ring.queue_free)


# ------------------------------------------------------------ combat (3D)
## Arc lumineux du coup d'épée, devant le joueur.
func _slash() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 10
	for k in steps:
		var a0 := deg_to_rad(-75.0 + 150.0 * k / steps)
		var a1 := deg_to_rad(-75.0 + 150.0 * (k + 1) / steps)
		var alpha := 0.15 + 0.75 * float(k) / steps
		st.set_color(Color(1, 1, 0.9, alpha))
		var pts := [Vector3(sin(a0), 0, cos(a0)) * 0.45, Vector3(sin(a0), 0, cos(a0)) * 0.95, Vector3(sin(a1), 0, cos(a1)) * 0.95, Vector3(sin(a1), 0, cos(a1)) * 0.45]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(pts[idx])
	var arc := MeshInstance3D.new()
	arc.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc.material_override = mat
	arc.position = _player3d.position + Vector3(0, 0.45, 0)
	arc.rotation.y = _player3d.rotation.y - 0.6
	add_child(arc)
	var tw := arc.create_tween().set_parallel()
	tw.tween_property(arc, "rotation:y", _player3d.rotation.y + 0.6, 0.18)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(arc.queue_free)


## Coup porté : le monstre sursaute, un chiffre de dégâts s'envole.
func _on_combat_hit(monster: Node2D, amount: int) -> void:
	var proxy: Node3D = _proxies.get(monster.get_instance_id())
	if proxy != null:
		var base := proxy.scale
		var tw := proxy.create_tween()
		tw.tween_property(proxy, "scale", base * Vector3(1.3, 0.75, 1.3), 0.06)
		tw.tween_property(proxy, "scale", base, 0.12)
	var label := Label3D.new()
	label.text = str(amount)
	label.font = UiTheme.title_font()
	label.font_size = 56
	label.pixel_size = 0.007
	label.outline_size = 12
	label.modulate = Color(1, 0.9, 0.3) if amount < 15 else Color(1, 0.45, 0.3)
	label.outline_modulate = Color(0.2, 0.05, 0.05)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = _to3d(monster.position, 0.9)
	add_child(label)
	var tw2 := label.create_tween().set_parallel()
	tw2.tween_property(label, "position:y", label.position.y + 0.8, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw2.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw2.chain().tween_callback(label.queue_free)


## Monstre vaincu : il tourbillonne, rétrécit et disparaît dans un nuage.
func _on_monster_killed(at: Vector2, _kind: String) -> void:
	var target := _to3d(at)
	var best: int = -1
	var best_d := 1.0
	for id: int in _proxies:
		var d := (_proxies[id] as Node3D).position.distance_to(target)
		if d < best_d:
			best_d = d
			best = id
	if best == -1:
		return
	var proxy: Node3D = _proxies[best]
	_proxies.erase(best)  # on l'anime nous-mêmes
	var tw := proxy.create_tween().set_parallel()
	tw.tween_property(proxy, "rotation:y", proxy.rotation.y + TAU * 1.5, 0.45)
	tw.tween_property(proxy, "position:y", proxy.position.y + 0.5, 0.2)
	tw.tween_property(proxy, "scale", Vector3.ONE * 0.01, 0.45).set_delay(0.1)
	tw.chain().tween_callback(func() -> void:
		fx_puff(at, Color(0.95, 0.95, 1.0, 0.9), 2.2)
		proxy.queue_free())


## Joueur touché : il clignote en rouge, le monstre s'est jeté sur lui.
func _on_player_hurt(from: Vector2) -> void:
	var overlay := StandardMaterial3D.new()
	overlay.albedo_color = Color(1, 0.15, 0.1, 0.6)
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi in _player3d.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = overlay
	var tw := create_tween()
	tw.tween_property(overlay, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		for mi in _player3d.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = null)
	# Le monstre le plus proche fait un bond vers le joueur
	var src := _to3d(from)
	for proxy: Node3D in _proxies.values():
		if proxy.position.distance_to(src) < 0.6:
			var dir := (_player3d.position - proxy.position).normalized() * 0.3
			var lunge := proxy.create_tween()
			lunge.tween_property(proxy, "position", proxy.position + dir, 0.08)
			break


# ------------------------------------------------------------ bulles des habitants
func _on_npc_bubble(npc_id: String, text: String) -> void:
	for proxy: Node3D in _proxies.values():
		if str(proxy.get_meta("npc_id", "")) != npc_id:
			continue
		var old := proxy.get_node_or_null("Bubble")
		if old != null:
			old.free()
		var label := Label3D.new()
		label.name = "Bubble"
		label.text = text
		label.font = UiTheme.font()
		label.font_size = 40
		label.pixel_size = 0.006
		label.outline_size = 10
		label.modulate = Color(1, 0.98, 0.9)
		label.outline_modulate = Color(0.2, 0.12, 0.08)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = Vector3(0, 1.3 / proxy.scale.y, 0)
		label.scale = Vector3.ONE / proxy.scale.x
		proxy.add_child(label)
		var tw := label.create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(label, "modulate:a", 0.0, 0.5)
		tw.tween_callback(label.queue_free)
		return


# ------------------------------------------------------------ effets 3D (appelés par Fx)
func fx_burst(at2d: Vector2, colors: Array, amount: int, speed: float) -> void:
	var p := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.06
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	box.material = mat
	p.mesh = box
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.6
	p.position = _to3d(at2d, 0.25)
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = speed / UNIT * 0.6
	p.initial_velocity_max = speed / UNIT * 1.1
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, colors[0])
	ramp.set_color(1, colors[colors.size() - 1])
	p.color_initial_ramp = ramp
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func fx_puff(at2d: Vector2, color: Color, size: float) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12 * size
	sphere.height = 0.18 * size
	var mat := _flat_material(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	mi.mesh = sphere
	mi.position = _to3d(at2d, 0.08)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * 2.0, 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(mi.queue_free)


func fx_item_pop(at2d: Vector2, texture: Texture2D) -> void:
	var s := _billboard(texture, 0.035)
	var start := _to3d(at2d, 0.3)
	s.position = start
	add_child(s)
	var peak := start + Vector3(0, 0.9, 0)
	var tw := s.create_tween()
	tw.tween_property(s, "position", peak, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.1)
	tw.tween_method(func(k: float) -> void:
		s.position = peak.lerp(_player3d.position + Vector3(0, 0.6, 0), k)
		s.scale = Vector3.ONE * lerpf(1.0, 0.3, k), 0.0, 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)
