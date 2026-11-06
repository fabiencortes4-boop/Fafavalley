class_name Models
extends RefCounted
## Chargement des modèles 3D Kenney (assets/kenney3d/*), avec cache.
## parts() extrait les maillages d'un modèle pour les dessiner en masse
## (MultiMesh) : indispensable pour de bonnes performances sur mobile.

const BASE := "res://assets/kenney3d/"

static var _scenes: Dictionary = {}
static var _parts: Dictionary = {}
static var _fixed: Dictionary = {}  # matériau d'origine -> matériau corrigé


## Certains modèles Kenney (Nature Kit) sont exportés en « métal pur » : sans
## reflets autour, leurs faces à l'ombre deviennent noires. On les rend mats.
static func fix_material(mat: Material) -> Material:
	if not (mat is StandardMaterial3D) or (mat as StandardMaterial3D).metallic == 0.0:
		return mat
	var key := mat.get_instance_id()
	if not _fixed.has(key):
		var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.metallic = 0.0
		m.roughness = 1.0
		m.metallic_specular = 0.2
		_fixed[key] = m
	return _fixed[key]


static func _fix_mesh_instance(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var m := mi.get_active_material(i)
		var fixed := fix_material(m)
		if fixed != m:
			mi.set_surface_override_material(i, fixed)


static func path(pack: String, name: String) -> String:
	return BASE + pack + "/" + name + ".glb"


static func scene(model_path: String) -> PackedScene:
	if not _scenes.has(model_path):
		_scenes[model_path] = load(model_path)
	return _scenes[model_path]


static func instance(model_path: String) -> Node3D:
	var root := scene(model_path).instantiate() as Node3D
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		_fix_mesh_instance(mi as MeshInstance3D)
	return root


## Liste des [Mesh, Transform3D] qui composent un modèle (statique).
static func parts(model_path: String) -> Array:
	if _parts.has(model_path):
		return _parts[model_path]
	var root := instance(model_path)
	var out: Array = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var t := mi.transform
		var p := mi.get_parent()
		while p != null and p != root:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		# Copie du maillage avec les matériaux actifs (corrigés)
		var mesh := mi.mesh.duplicate() as Mesh
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, mi.get_active_material(i))
		out.append([mesh, t])
	root.free()
	_parts[model_path] = out
	return out


## Teinte un modèle (multiplie la couleur de ses matériaux).
static func tint(node: Node, color: Color) -> void:
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var base := mi.get_active_material(i)
			if base is StandardMaterial3D:
				var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
				mat.albedo_color = mat.albedo_color * color
				if color.a < 1.0:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mi.set_surface_override_material(i, mat)


## Regroupe des placements statiques par modèle, puis crée les MultiMesh.
class Batch:
	var _items: Dictionary = {}  # chemin -> Array[Transform3D]

	func add(model_path: String, t: Transform3D) -> void:
		if not _items.has(model_path):
			_items[model_path] = []
		_items[model_path].append(t)

	func build(parent: Node3D) -> void:
		for model_path: String in _items:
			var transforms: Array = _items[model_path]
			for part: Array in Models.parts(model_path):
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = part[0]
				mm.instance_count = transforms.size()
				for i in transforms.size():
					mm.set_instance_transform(i, (transforms[i] as Transform3D) * (part[1] as Transform3D))
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				parent.add_child(mmi)
