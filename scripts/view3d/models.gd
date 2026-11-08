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
	var soft := model_path.contains("/blocky/")
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if soft:
			(mi as MeshInstance3D).mesh = rounded((mi as MeshInstance3D).mesh)
		_fix_mesh_instance(mi as MeshInstance3D)
	return root


static var _rounded: Dictionary = {}

## Personnages « peluche » : chaque pièce cubique du modèle Blocky (tête,
## buste, bras, jambes) devient une boîte aux arêtes bien arrondies. Les
## faces sont subdivisées puis projetées sur la forme arrondie ; les UV
## suivent, donc les textures (tenues, éditeur de personnage) restent
## valables. Normales lisses exactes. Mis en cache par maillage.
static func rounded(mesh: Mesh) -> Mesh:
	if mesh == null:
		return mesh
	var key := mesh.get_instance_id()
	if _rounded.has(key):
		return _rounded[key]
	var aabb := mesh.get_aabb()
	var half := aabb.size / 2.0
	var center := aabb.position + half
	var big := half.x > 1.0  # la tête (à une autre échelle) : plus de finesse
	var r := minf(half.x, minf(half.y, half.z)) * (0.44 if big else 0.5)
	var m := 3 if big else 2  # segments par demi-face
	var inner := (half - Vector3.ONE * r)
	var rho := Vector3(r / half.x, r / half.y, r / half.z)
	var out := ArrayMesh.new()
	for surf in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surf)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			for i in verts.size():
				idx.append(i)
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var nu := PackedVector2Array()
		var ni := PackedInt32Array()
		var n := 2 * m
		for t in range(0, idx.size(), 3):
			var a := verts[idx[t]]
			var b := verts[idx[t + 1]]
			var c := verts[idx[t + 2]]
			var ua := uvs[idx[t]]
			var ub := uvs[idx[t + 1]]
			var uc := uvs[idx[t + 2]]
			var base := nv.size()
			var row_start: Array[int] = []
			for i in n + 1:
				row_start.append(nv.size() - base)
				for j in n + 1 - i:
					var p := a + (b - a) * (float(i) / n) + (c - a) * (float(j) / n)
					# Resserre les points vers les arêtes (là où ça s'arrondit)
					var q := (p - center) / half
					var w := Vector3(_warp(q.x, rho.x, m), _warp(q.y, rho.y, m), _warp(q.z, rho.z, m))
					var pw := center + w * half
					nu.append(_bary_uv(pw, a, b, c, ua, ub, uc))
					var core := (pw - center).clamp(-inner, inner) + center
					var dir := pw - core
					var nrm := dir.normalized() if dir.length_squared() > 1e-12 else (b - a).cross(c - a).normalized() * -1.0
					nv.append(core + nrm * r)
					nn.append(nrm)
			for i in n:
				for j in n - i:
					var v0 := base + row_start[i] + j
					var v1 := base + row_start[i + 1] + j
					ni.append_array([v0, v1, v0 + 1])
					if j < n - i - 1:
						ni.append_array([v1, v1 + 1, v0 + 1])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = nv
		arr[Mesh.ARRAY_NORMAL] = nn
		arr[Mesh.ARRAY_TEX_UV] = nu
		arr[Mesh.ARRAY_INDEX] = ni
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(surf))
	_rounded[key] = out
	return out


## Position d'un point de grille (−1..1) le long d'un axe : un premier pas
## jusqu'au début de l'arrondi, puis des pas réguliers en angle dessus.
static func _warp(t: float, rho: float, m: int) -> float:
	var u := clampf(absf(t), 0.0, 1.0) * m
	var c := 1.0 - rho
	var s: float
	if u <= 1.0:
		s = c * u
	else:
		s = c + rho * tan(PI / 4.0 * (u - 1.0) / float(m - 1))
	return signf(t) * minf(s, 1.0)


## UV d'un point du plan d'un triangle (coordonnées barycentriques).
static func _bary_uv(p: Vector3, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> Vector2:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var den := d00 * d11 - d01 * d01
	if absf(den) < 1e-12:
		return ua
	var v := (d11 * d20 - d01 * d21) / den
	var w := (d00 * d21 - d01 * d20) / den
	return ua * (1.0 - v - w) + ub * v + uc * w


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
	apply_texture(node, load(texture_path))


## Même chose avec une texture déjà chargée (apparence générée du joueur).
static func apply_texture(node: Node, tex: Texture2D) -> void:
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
