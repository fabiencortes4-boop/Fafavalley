class_name Models
extends RefCounted
## Chargement des modèles 3D Kenney (assets/kenney3d/*), avec cache.
## parts() extrait les maillages d'un modèle pour les dessiner en masse
## (MultiMesh) : indispensable pour de bonnes performances sur mobile.

const BASE := "res://assets/kenney3d/"

static var _scenes: Dictionary = {}
static var _parts: Dictionary = {}
static var _fixed: Dictionary = {}  # matériau d'origine -> matériau corrigé


## Corrige les matériaux Kenney : certains (Nature Kit) sont exportés en
## « métal pur » (faces à l'ombre noires) : on les rend mats. Et toutes les
## textures sont lissées (filtrage linéaire au lieu de pixels nets).
static func fix_material(mat: Material) -> Material:
	if not (mat is StandardMaterial3D):
		return mat
	var key := mat.get_instance_id()
	if not _fixed.has(key):
		var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		if m.metallic != 0.0:
			m.metallic = 0.0
			m.roughness = 1.0
			m.metallic_specular = 0.2
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
## Remplace la texture d'un personnage Blocky (tenue d'un habitant).
static func retexture(node: Node, texture_path: String) -> void:
	var tex: Texture2D = load(texture_path)
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var base := mi.get_active_material(i)
			if base is StandardMaterial3D:
				var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
				mat.albedo_texture = tex
				mi.set_surface_override_material(i, mat)


## Un habitant en 3D : le corps Blocky commun avec sa tenue de métier
## (assets/kenney3d/blocky/Textures/npc/<id>.png, tools/build_npc_textures.py).
static func npc(id: String) -> Node3D:
	var model := instance(path("blocky", "character-a"))
	var tex := "res://assets/kenney3d/blocky/Textures/npc/%s.png" % id
	if ResourceLoader.exists(tex):
		retexture(model, tex)
	return model


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
## Découpés en morceaux de CHUNK cases : ce qui est hors de l'écran n'est
## pas dessiné (indispensable sur téléphone).
class Batch:
	const CHUNK := 8.0
	var _items: Dictionary = {}  # [chemin, morceau] -> Array[Transform3D]

	func add(model_path: String, t: Transform3D) -> void:
		var key := [model_path, floori(t.origin.x / CHUNK), floori(t.origin.z / CHUNK)]
		if not _items.has(key):
			_items[key] = []
		_items[key].append(t)

	func build(parent: Node3D) -> void:
		for key: Array in _items:
			var model_path: String = key[0]
			var transforms: Array = _items[key]
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
