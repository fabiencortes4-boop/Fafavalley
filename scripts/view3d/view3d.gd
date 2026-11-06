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

const NPC_MODELS := ["character-b", "character-c", "character-d", "character-e", "character-f"]
## Objet -> modèle 3D (sinon : l'icône pixel en panneau face caméra)
const ITEM_MODELS := {
	"carrot": ["food", "carrot", 0.9], "turnip": ["food", "radish", 0.9], "cabbage": ["food", "cabbage", 1.0],
	"tomato": ["food", "tomato", 1.8], "corn": ["food", "corn", 1.0], "wheat": ["nature", "crops_wheatStageB", 0.7],
	"leek": ["food", "leek", 0.8], "mushroom": ["food", "mushroom", 2.2], "berries": ["food", "cherries", 2.2],
	"winter_root": ["food", "beet", 1.6], "daffodil": ["nature", "flower_yellowA", 2.0], "poppy": ["nature", "flower_redA", 2.0],
	"wood": ["survival", "resource-wood", 2.0], "stone": ["survival", "resource-stone", 2.0],
	"roach": ["survival", "fish", 2.0], "carp": ["survival", "fish-large", 1.6], "chest": ["survival", "chest", 1.6],
}
const TOOL_MODELS := {
	"hoe": ["survival", "tool-hoe"], "axe": ["survival", "tool-axe"], "pickaxe": ["survival", "tool-pickaxe"],
	"steel_pickaxe": ["survival", "tool-pickaxe-upgraded"], "watering_can": ["survival", "bucket"],
	"copper_can": ["survival", "bucket"], "scythe": ["survival", "tool-shovel"],
	"rusty_sword": ["dungeon", "weapon-sword"], "iron_sword": ["dungeon", "weapon-sword"], "war_axe": ["survival", "tool-axe-upgraded"],
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
	_build_environment()
	_static = Node3D.new()
	add_child(_static)
	if _is_mine:
		_build_mine()
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
	for cell: Vector2i in chars:
		var ch: String = chars[cell]
		var h := 0.0
		var col: Color
		match ch:
			"~":
				h = -0.28
				col = Color(0.55, 0.47, 0.33)
			"=":
				col = Color(0.86, 0.69, 0.47)
			"c":
				col = Color(0.72, 0.70, 0.66)
			_:
				col = colors.grass if _hash(cell) % 3 != 0 else colors.grass2
		var v := (float(_hash(cell) % 100) / 100.0 - 0.5) * 0.04
		col = col.lightened(v) if v > 0 else col.darkened(-v)
		_quad(st, Vector3(cell.x, h, cell.y), Vector3(cell.x + 1, h, cell.y + 1), col)
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
		_water_mat.albedo_color = Color(0.36, 0.66, 0.9, 0.78) if TimeManager.season != 3 else Color(0.78, 0.9, 0.98, 0.92)
		_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_water_mat.roughness = 0.15
		_water_mat.metallic_specular = 0.8
		wmi.material_override = _water_mat
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_static.add_child(wmi)


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
			".":
				if TimeManager.season != 3 and _hash(cell) % 9 == 0:
					_place(batch, "nature", "grass", c, 1.4, rot)
	batch.build(_static)
	_build_buildings(chars)


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
		elif map is Village and Village.BUILDINGS.has(ch):
			var b: Array = Village.BUILDINGS[ch]
			match str(b[0]):
				"store":
					_house(cell, b[1], b[3], "wall", Color(0.85, 0.35, 0.3))
					var stall := _model("town", "stall-red", 1.0)
					stall.position = _cell3d(cell + Vector2i(4, 2))
					_static.add_child(stall)
				"gaston", "mairie":
					_house(cell, b[1], b[3], "wall", Color(0.42, 0.5, 0.62))
				"odette", "lina":
					_house(cell, b[1], b[3], "wall-wood", Color(0.78, 0.3, 0.25) if b[0] == "odette" else Color(0.35, 0.55, 0.75))
				"well":
					var f := _model("town", "fountain-round-detail", 0.5)
					f.position = _cell3d(cell) + Vector3(0, 0, 0.5)
					_static.add_child(f)
				"mine":
					for dx in 3:
						var rock := _model("nature", "cliff_block_rock" if dx != 1 else "cliff_cave_rock", 1.0)
						rock.scale = Vector3(1, 1.6, 1) if dx != 1 else Vector3(1, 1.6, 6)
						rock.position = Vector3(cell.x + dx + 0.5, 0, cell.y + 1.5 - (0.0 if dx != 1 else 0.33 * 6 - 0.33))
						rock.rotation.y = PI if dx == 1 else 0.0
						_static.add_child(rock)
		if ch == "N":
			var anvil := _model("survival", "workbench-anvil", 2.2)
			anvil.position = _cell3d(cell)
			_static.add_child(anvil)


## Maison : murs Kenney (porte, fenêtres) sur 2 étages et toit à deux pans.
func _house(cell: Vector2i, size: Vector2i, door_col: int, wall: String, roof_color: Color) -> void:
	var root := Node3D.new()
	_static.add_child(root)
	var x0 := float(cell.x)
	var z0 := float(cell.y)
	var w := size.x
	var d := size.y
	for level in 2:
		var y := float(level)
		for i in w:
			var front: String = wall + "-window-shutters"
			if level == 0 and i == door_col:
				front = wall + "-door"
			elif level == 1 or (i % 2 == 0 and i != door_col):
				front = wall if level == 1 and i % 2 == 0 else wall + "-window-shutters"
			_wall(root, front, Vector3(x0 + i + 0.5, y, z0 + d - 0.5), -PI / 2.0)
			_wall(root, wall, Vector3(x0 + i + 0.5, y, z0 + 0.5), PI / 2.0)
		for j in d:
			_wall(root, wall if j % 2 == 0 else wall + "-window-shutters", Vector3(x0 + 0.5, y, z0 + j + 0.5), PI)
			_wall(root, wall, Vector3(x0 + w - 0.5, y, z0 + j + 0.5), 0.0)
	root.add_child(_roof(Vector3(x0, 2.0, z0), float(w), float(d), roof_color))
	var chimney := _model("town", "chimney", 1.0)
	chimney.position = Vector3(x0 + w - 0.7, 2.3, z0 + 0.8)
	root.add_child(chimney)


func _wall(parent: Node3D, model: String, at: Vector3, rot: float) -> void:
	var n := _model("town", model, 1.0)
	n.position = at
	n.rotation.y = rot
	parent.add_child(n)


## Toit à deux pans (prisme) dessiné à la main, couleurs façon Kenney.
func _roof(origin: Vector3, w: float, d: float, color: Color) -> MeshInstance3D:
	var o := 0.18  # débord
	var h := 1.1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -o
	var x1 := w + o
	var zf := d + o
	var zb := -o
	var zm := d / 2.0
	var a := Vector3(x0, 0, zb)
	var b := Vector3(x1, 0, zb)
	var c := Vector3(x1, 0, zf)
	var e := Vector3(x0, 0, zf)
	var r0 := Vector3(x0, h, zm)
	var r1 := Vector3(x1, h, zm)
	st.set_color(color)
	for p in [e, c, r1, e, r1, r0]:  # pan avant
		st.add_vertex(p)
	st.set_color(color.darkened(0.15))
	for p in [b, a, r0, b, r0, r1]:  # pan arrière
		st.add_vertex(p)
	st.set_color(Color(0.9, 0.82, 0.68))
	for p in [Vector3(o, 0, zf - o), Vector3(o, 0, zb + o), Vector3(o, h - 0.1, zm)]:  # pignons
		st.add_vertex(p)
	for p in [Vector3(w - o, 0, zb + o), Vector3(w - o, 0, zf - o), Vector3(w - o, h - 0.1, zm)]:
		st.add_vertex(p)
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
			_place(batch, "dungeon", "floor-detail" if _hash(cell) % 7 == 0 else "floor", c, 1.0, 0.0)
			if ch == "U":
				_place(batch, "dungeon", "stairs", c, 1.0, PI)
	batch.build(_static)


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
		var hole := _model("dungeon", "stairs", 1.0)
		hole.position = _cell3d(ladder) + Vector3(0, -0.85, 0)
		add_child(hole)


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


func _crop_model(crop: String, stage: int) -> Node3D:
	if stage <= 0:
		return _model("nature", "crops_leafsStageA", 0.6)
	match crop:
		"corn":
			return _model("nature", ["crops_cornStageA", "crops_cornStageB", "crops_cornStageC", "crops_cornStageD"][mini(stage, 3)], 0.8)
		"wheat":
			return _model("nature", "crops_wheatStageA" if stage < 3 else "crops_wheatStageB", 1.2 + stage * 0.15)
	if stage == 1:
		return _model("nature", "crops_leafsStageA", 1.2)
	if stage == 2:
		return _model("nature", "crops_leafsStageB", 1.2)
	match crop:
		"carrot":
			return _model("nature", "crop_carrot", 1.4)
		"turnip":
			return _model("nature", "crop_turnip", 1.4)
		"cabbage":
			return _model("food", "cabbage", 1.6)
		"tomato":
			var n := _model("nature", "crops_leafsStageB", 1.3)
			for k in 3:
				var t := _model("food", "tomato", 1.6)
				t.position = Vector3(cos(k * 2.1) * 0.12, 0.25 + k * 0.08, sin(k * 2.1) * 0.12) / 1.3
				n.add_child(t)
			return n
	return _model("nature", "crops_leafsStageB", 1.3)


# ------------------------------------------------------------ joueur
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


func _show_tool(id: String) -> void:
	if id == _tool_id:
		if _tool3d != null:
			_tool3d.visible = id != ""
		return
	_tool_id = id
	if _tool3d != null:
		_tool3d.queue_free()
		_tool3d = null
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
		var index := int(GameData.npc((node as Npc).id).get("sprite", 0)) % NPC_MODELS.size()
		var npc := _model("blocky", NPC_MODELS[index], CHARACTER_SCALE)
		npc.add_child(_blob(1.6))
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
			var bat := _billboard(load("res://assets/sprites/monsters.png"), 0.04)
			bat.hframes = 7
			bat.frame = 1
			var holder := Node3D.new()
			holder.add_child(bat)
			return holder
		var look: Array = MONSTER_LOOKS.get(kind, MONSTER_LOOKS["rat"])
		var m := _model("dungeon", look[0], look[2])
		Models.tint(m, look[1])
		m.add_child(_blob(0.9))
		return m
	if node is Critter:
		var s := _billboard(load("res://assets/sprites/animals.png"), 0.045)
		s.hframes = 3
		s.frame = (node as Critter).frame
		s.position.y = 0.36
		var holder := Node3D.new()
		holder.add_child(s)
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
	if node is Npc or node is Monster:
		if Vector2(moved.x, moved.z).length() > 0.002:
			proxy.rotation.y = lerp_angle(proxy.rotation.y, atan2(moved.x, moved.z), 0.25)
		var anims := proxy.find_children("*", "AnimationPlayer", true, false)
		if not anims.is_empty():
			var ap := anims[0] as AnimationPlayer
			var want := "walk" if Vector2(moved.x, moved.z).length() > 0.002 else "idle"
			if ap.current_animation != want:
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
		var bob: Vector2 = fishing.get("_bobber_base")
		_bobber.position = _to3d(bob, -0.06 + sin(Time.get_ticks_msec() / 300.0) * 0.02 - (0.05 if fishing.state == Fishing.State.BITE else 0.0))
	_bite_alert.visible = fishing.state == Fishing.State.BITE
	_bite_alert.position = _player3d.position + Vector3(0, 1.45, 0)
	if _water_mat != null:
		_water_mat.uv1_offset.x += delta * 0.02
	_update_camera(false, delta)
	if _weather != null:
		_weather.position = _cam_target + Vector3(0, 6, 0)


func _update_camera(snap: bool = false, delta: float = 0.016) -> void:
	if map == null or not is_instance_valid(map):
		return
	var target := _to3d(map.player.position) + Vector3(0, 0.4, 0)
	_cam_target = target if snap else _cam_target.lerp(target, minf(1.0, delta * 6.0))
	var distance := 17.0 / Settings.zoom
	var offset := Vector3(0, sin(CAMERA_PITCH), cos(CAMERA_PITCH)) * distance
	camera.position = _cam_target + offset
	camera.look_at(_cam_target, Vector3.UP)


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
	var hours := TimeManager.minutes / 60.0
	var night := clampf((hours - 18.0) / 4.0, 0.0, 1.0)
	var rain := TimeManager.is_raining() or TimeManager.is_snowing()
	_sun.light_energy = lerpf(0.85, 0.1, night) * (0.6 if rain else 1.0)
	_sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(0.55, 0.6, 1.0), night)
	_env.ambient_light_color = Color(0.62, 0.66, 0.78).lerp(Color(0.16, 0.2, 0.36), night)
	_env.ambient_light_energy = 0.55
	var sky := Color(0.55, 0.75, 0.92).lerp(Color(0.05, 0.07, 0.15), night)
	_env.background_color = sky.darkened(0.25) if rain else sky


func _on_day_started(_d: int, _s: int, _y: int) -> void:
	# Nouvelle saison : on reconstruit le décor (couleurs, arbres)
	if not _is_mine:
		_static.queue_free()
		_static = Node3D.new()
		add_child(_static)
		_build_ground()
		_build_props()
	_update_weather()


func _update_weather() -> void:
	var kind := "rain" if TimeManager.is_raining() else ("snow" if TimeManager.is_snowing() else "")
	if _is_mine:
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
	_weather.amount = 400 if kind == "rain" else 220
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
