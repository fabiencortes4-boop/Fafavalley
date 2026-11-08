extends Node3D
## Planche des rochers à miner (RockMesh) : chaque type, sur chaque thème.
##   xvfb-run godot --rendering-driver opengl3 res://tools/render_rocks.tscn -- sortie.png

const TYPES := ["stone", "pebbles", "coal", "copper", "iron", "gold", "gem", "frost", "magma"]
const THEMES := ["earth", "ice", "lava", "farm"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "res://rocks.png"
	var vp := SubViewport.new()
	vp.size = Vector2i(1400, 640)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.24, 0.27)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	vp.add_child(sun)
	for row in THEMES.size():
		for col in TYPES.size():
			var mi := MeshInstance3D.new()
			mi.mesh = RockMesh.mesh(TYPES[col], THEMES[row], col + row)
			mi.position = Vector3(col * 1.1, 0, row * 1.1)
			vp.add_child(mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.2
	cam.position = Vector3(4.4, 6, 8.5)
	vp.add_child(cam)
	cam.look_at(Vector3(4.4, 0, 1.6))
	for i in 4:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	get_tree().quit()
