extends Node
## Outil : affiche la taille (AABB) des modèles 3D et les animations.
##   godot --headless res://tools/inspect_models.tscn

func _ready() -> void:
	for pack in ["nature", "survival", "town", "food", "blocky", "dungeon", "pets"]:
		var dir := DirAccess.open("res://assets/kenney3d/" + pack)
		for f in dir.get_files():
			if not f.ends_with(".glb"):
				continue
			var scene: PackedScene = load("res://assets/kenney3d/%s/%s" % [pack, f])
			var root := scene.instantiate()
			add_child(root)
			var box := AABB()
			var first := true
			for mi in root.find_children("*", "MeshInstance3D", true, false):
				var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				box = b if first else box.merge(b)
				first = false
			var anims := ""
			var ap := root.find_children("*", "AnimationPlayer", true, false)
			if not ap.is_empty():
				anims = " anims=" + ",".join((ap[0] as AnimationPlayer).get_animation_list())
			print("%s/%s pos=(%.2f,%.2f,%.2f) size=(%.2f,%.2f,%.2f)%s" % [pack, f.get_basename(), box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z, anims])
			root.queue_free()
	get_tree().quit()
