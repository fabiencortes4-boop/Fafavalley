extends Node3D
## Rend une icône 64x64 de chaque animal (modèles Cube Pets) dans
## assets/sprites/pets/<espèce>.png, pour les boutiques et les soins.
##   xvfb-run godot --rendering-driver opengl3 res://tools/render_pet_icons.tscn

const PETS := {"chicken": "animal-chick", "bunny": "animal-bunny", "cow": "animal-cow", "pig": "animal-pig",
	"dog": "animal-dog", "cat": "animal-cat"}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/pets"))
	var vp := SubViewport.new()
	vp.size = Vector2i(64, 64)
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
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 0.9
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	for type: String in PETS:
		var model := Models.instance(Models.path("pets", PETS[type]))
		vp.add_child(model)
		model.rotation_degrees.y = 35
		var box := _aabb(model)
		var center := box.get_center()
		cam.size = maxf(box.size.x, box.size.y) * 1.35
		cam.position = center + Vector3(0, box.size.y * 0.25, 4)
		cam.look_at(center, Vector3.UP)
		for i in 4:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("res://assets/sprites/pets/%s.png" % type)
		print("icône : ", type)
		model.free()
	get_tree().quit()


func _aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
