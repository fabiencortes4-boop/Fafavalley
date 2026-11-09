extends Node3D
## Planche de tous les personnages Blocky (modèle x texture), pour choisir
## l'apparence des habitants.
##   xvfb-run godot --rendering-driver opengl3 res://tools/render_characters.tscn -- sortie.png

const W := 120
const H := 160


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--looks" in args:
		await _looks(args[args.find("--looks") + 1])
	elif "--portraits" in args:
		var only: Array = []
		for a in args:
			if a.begins_with("--only="):
				only = a.trim_prefix("--only=").split(",")
		await _portraits(only)
	else:
		await _sheet(args[0] if args.size() > 0 and not args[0].begins_with("--") else "res://characters.png")
	get_tree().quit()


## Planche d'apparences de l'éditeur de personnage (face et dos).
func _looks(out: String) -> void:
	var vp := _viewport(Vector2i(W, H))
	var cam: Camera3D = vp.get_meta("cam")
	var looks: Array = []
	for i in 6:
		var l := CharacterLook.default_look()
		l.sex = i % 2
		l.hair = [0, 5, 2, 4, 3, 6][i]
		l.hair_color = [1, 4, 0, 5, 0, 2][i]
		l.beard = [3, 0, 1, 0, 5, 0][i]
		l.skin = [0, 2, 4, 1, 5, 3][i]
		l.top = i
		looks.append(l)
	var sheet := Image.create(W * 6, H * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.3, 0.45, 0.3))
	for row in 2:
		for i in looks.size():
			var model := Models.instance(Models.path("blocky", "character-a"))
			Models.apply_texture(model, CharacterLook.texture(looks[i]))
			vp.add_child(model)
			model.rotation_degrees.y = 25 if row == 0 else 180
			var box := _aabb(model)
			cam.size = box.size.y * 1.15
			cam.position = box.get_center() + Vector3(0, 0, 4)
			cam.look_at(box.get_center(), Vector3.UP)
			for f in 3:
				await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blend_rect(img, Rect2i(0, 0, W, H), Vector2i(i * W, row * H))
			model.free()
	sheet.save_png(out)


## Planche des habitants en pied, avec leur tenue.
func _sheet(out: String) -> void:
	var vp := _viewport(Vector2i(W, H))
	var cam: Camera3D = vp.get_meta("cam")
	var ids: Array = GameData.npcs.keys()
	var sheet := Image.create(W * 7, H * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.2, 0.22))
	for i in ids.size():
		var model := npc_model(ids[i])
		vp.add_child(model)
		model.rotation_degrees.y = 25
		var box := _aabb(model)
		cam.size = box.size.y * 1.15
		cam.position = box.get_center() + Vector3(0, 0, 4)
		cam.look_at(box.get_center(), Vector3.UP)
		for f in 3:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(0, 0, W, H), Vector2i((i % 7) * W, (i / 7) * H))
		model.free()
	sheet.save_png(out)


## Portraits 64x64 (tête et épaules) tirés des vrais modèles 3D :
## assets/sprites/portraits/<habitant>.png
func _portraits(only: Array = []) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/portraits"))
	var vp := _viewport(Vector2i(64, 64))
	var cam: Camera3D = vp.get_meta("cam")
	for id: String in GameData.npcs.keys() + GameData.newcomers.keys():
		if not only.is_empty() and not id in only:
			continue
		var model := npc_model(id)
		vp.add_child(model)
		model.rotation_degrees.y = 22
		var box := _aabb(model)
		# Cadrage : la tête (le quart haut) et le haut des épaules
		var top := box.position.y + box.size.y
		var center := Vector3(box.get_center().x, top - box.size.y * 0.27, box.get_center().z)
		cam.size = box.size.y * 0.52
		cam.position = center + Vector3(0, 0.15, 4)
		cam.look_at(center, Vector3.UP)
		for f in 3:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("res://assets/sprites/portraits/%s.png" % id)
		print("portrait : ", id)
		model.free()
	await _sprites()


## Petits sprites 16x16 en pied (vue 2D) : assets/sprites/npcs.png, dans
## l'ordre des "sprite" de data/npcs.json.
func _sprites() -> void:
	var vp := _viewport(Vector2i(64, 64))
	var cam: Camera3D = vp.get_meta("cam")
	var count := GameData.npcs.size()
	var sheet := Image.create(16 * count, 16, false, Image.FORMAT_RGBA8)
	# Le joueur d'abord (son propre fichier), puis les habitants
	for id: String in ["__player"] + GameData.npcs.keys():
		var model := Models.instance(Models.path("blocky", "character-a")) if id == "__player" else npc_model(id)
		vp.add_child(model)
		model.rotation_degrees.y = 15
		var box := _aabb(model)
		cam.size = box.size.y * 1.02
		cam.position = box.get_center() + Vector3(0, 0, 4)
		cam.look_at(box.get_center(), Vector3.UP)
		for f in 3:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
		# Bords nets : chaque pixel est plein ou vide
		for y in 16:
			for x in 16:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r / maxf(c.a, 0.01), c.g / maxf(c.a, 0.01), c.b / maxf(c.a, 0.01), 1.0) if c.a > 0.45 else Color(0, 0, 0, 0))
		model.free()
		if id == "__player":
			img.save_png("res://assets/sprites/player.png")
			continue
		var index := int(GameData.npc(id).get("sprite", 0))
		sheet.blit_rect(img, Rect2i(0, 0, 16, 16), Vector2i(index * 16, 0))
	sheet.save_png("res://assets/sprites/npcs.png")
	print("sprites 2D : ", count)


static func npc_model(id: String) -> Node3D:
	return Models.npc(id)


func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -25, 0)
	sun.light_energy = 0.9
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	vp.set_meta("cam", cam)
	return vp


func _aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
