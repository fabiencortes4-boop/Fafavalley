class_name LookPreview
extends SubViewportContainer
## Aperçu 3D du personnage qui tourne sur lui-même (éditeur de personnage,
## écran titre et menu Apparence).

var _pivot: Node3D
var _model: Node3D


func _init(min_size: Vector2 = Vector2(112, 200)) -> void:
	custom_minimum_size = min_size
	stretch = true
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(min_size * 2)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.8, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.4
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3(0, 1.45, 6)
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 1.3, 0), Vector3.UP)
	_pivot = Node3D.new()
	vp.add_child(_pivot)


func _ready() -> void:
	var tw := _pivot.create_tween().set_loops()
	tw.tween_property(_pivot, "rotation:y", TAU, 6.0).from(0.0)


## Affiche cette apparence.
func show_look(look: Dictionary) -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = Models.instance(Models.path("blocky", "character-a"))
	Models.apply_texture(_model, CharacterLook.texture(look))
	_pivot.add_child(_model)
	var anim := _model.find_children("*", "AnimationPlayer", true, false)
	if not anim.is_empty():
		(anim[0] as AnimationPlayer).play("idle")
