class_name RockMesh
extends RefCounted
## Rochers à miner, modelés à la volée : un bloc de pierre à facettes (sphère
## bosselée, posée à plat), avec ses filons selon le minerai : pépites de
## cuivre, de fer ou d'or qui brillent, charbon noir lustré, grappes de
## cristaux (gemmes, givre, opale de feu qui rougeoie).
## Quelques variantes par type, mises en cache : très léger à dessiner.

static var _cache: Dictionary = {}
static var _ico: Array = []  # [sommets, faces] de l'icosphère de base

## Couleur de la pierre selon l'étage (ou la ferme)
const STONE := {
	"earth": Color(0.7, 0.64, 0.57), "ice": Color(0.66, 0.74, 0.84), "lava": Color(0.46, 0.38, 0.35),
	"deep": Color(0.5, 0.6, 0.62), "farm": Color(0.66, 0.64, 0.6),
}
## Minerai : [couleurs, forme, métal (brillant), lueur]
const ORE := {
	"coal": [[Color(0.1, 0.1, 0.12), Color(0.18, 0.17, 0.2)], "nugget", 0.3, 0.0],
	"copper": [[Color(0.95, 0.52, 0.28), Color(0.4, 0.75, 0.6)], "nugget", 0.3, 0.2],
	"iron": [[Color(0.82, 0.85, 0.94), Color(0.7, 0.56, 0.48)], "nugget", 0.35, 0.2],
	"gold": [[Color(1.0, 0.8, 0.22), Color(1.0, 0.9, 0.5)], "nugget", 0.4, 0.4],
	"gem": [[Color(0.78, 0.4, 1.0), Color(0.35, 0.9, 0.6), Color(0.4, 0.65, 1.0)], "crystal", 0.0, 0.45],
	"frost": [[Color(0.7, 0.93, 1.0), Color(0.88, 0.98, 1.0)], "crystal", 0.0, 0.35],
	"magma": [[Color(1.0, 0.42, 0.1), Color(1.0, 0.7, 0.2)], "crystal", 0.0, 1.4],
}


static func mesh(type: String, theme: String, variant: int) -> ArrayMesh:
	var key := "%s|%s|%d" % [type, theme, variant]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var base: Color = STONE.get(theme, STONE.earth)
	if type == "magma":
		base = Color(0.3, 0.23, 0.21)
	elif type == "coal":
		base = base.darkened(0.12)
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ore := SurfaceTool.new()
	ore.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array = []  # [centre, normale] des facettes, pour y poser les filons
	if type == "pebbles":
		var n := 3 + variant % 2
		for k in n:
			var a := TAU * float(k) / n + rng.randf_range(-0.4, 0.4)
			var d := rng.randf_range(0.1, 0.22)
			var s := rng.randf_range(0.8, 1.25)
			_boulder(stone, Vector3(cos(a) * d, 0, sin(a) * d), Vector3(0.13, 0.1, 0.11) * s, base, theme, rng)
	else:
		var s := rng.randf_range(0.94, 1.02)  # reste dans sa case (pas dans les murs)
		var vein := Color(0, 0, 0, 0)
		if ORE.has(type):
			vein = (ORE[type][0][0] as Color)
			vein.a = 0.55 if ORE[type][1] == "nugget" else 0.3
		faces = _boulder(stone, Vector3.ZERO, Vector3(0.42, 0.5, 0.4) * s, base, theme, rng, vein)
		if type == "stone" and theme == "earth" and variant % 2 == 0:
			_boulder(stone, Vector3(0.3, 0, 0.22), Vector3(0.14, 0.11, 0.12), base.darkened(0.05), theme, rng)
	var has_ore := ORE.has(type) and not faces.is_empty()
	if has_ore:
		var info: Array = ORE[type]
		var colors: Array = info[0]
		# Facettes visibles (côtés et dessus), mélangées
		var spots: Array = faces.filter(func(f: Array) -> bool: return (f[1] as Vector3).y > -0.05 and (f[0] as Vector3).y > 0.08)
		for i in range(spots.size() - 1, 0, -1):
			var j := rng.randi() % (i + 1)
			var tmp: Variant = spots[i]
			spots[i] = spots[j]
			spots[j] = tmp
		if info[1] == "nugget":
			var count := 6 if type == "coal" else 5
			for i in mini(count, spots.size()):
				var f: Array = spots[i]
				var col: Color = colors[0] if i % 3 != 2 else colors[1]
				var r := rng.randf_range(0.085, 0.12) * (1.25 if type == "coal" else 1.0)
				_nugget(ore, f[0] + f[1] * r * 0.25, f[1], r, col, rng)
		else:
			# Grappe de cristaux sur le dessus, et un ou deux sur les côtés
			var tops: Array = spots.filter(func(f: Array) -> bool: return (f[1] as Vector3).y > 0.45)
			var count := 4 if type == "frost" else 3
			for i in count:
				var f: Array = tops[i % maxi(1, tops.size())] if not tops.is_empty() else spots[i]
				var col: Color = colors[rng.randi() % colors.size()]
				var axis := ((f[1] as Vector3) + Vector3.UP * 0.9 + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))).normalized()
				var length := rng.randf_range(0.2, 0.34) * (1.2 if type == "frost" else 1.0)
				var at: Vector3 = f[0] - axis * 0.05 + Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
				_crystal(ore, at, axis, rng.randf_range(0.045, 0.065), length, col)
			for i in 2:
				var f: Array = spots[(i + 3) % spots.size()]
				var axis := ((f[1] as Vector3) + Vector3.UP * 0.4).normalized()
				_crystal(ore, f[0] - axis * 0.04, axis, 0.04, rng.randf_range(0.12, 0.18), colors[(i + 1) % colors.size()])
	var out := ArrayMesh.new()
	var stone_mat := StandardMaterial3D.new()
	stone_mat.vertex_color_use_as_albedo = true
	stone_mat.vertex_color_is_srgb = true
	stone_mat.roughness = 0.95
	stone.set_material(stone_mat)
	stone.commit(out)
	if has_ore:
		var info: Array = ORE[type]
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.metallic = float(info[2])
		mat.roughness = 0.35 if float(info[2]) > 0.0 or info[1] == "crystal" else 0.6
		mat.metallic_specular = 0.8
		if float(info[3]) > 0.0:
			mat.emission_enabled = true
			mat.emission = (info[0][0] as Color)
			mat.emission_energy_multiplier = float(info[3])
		ore.set_material(mat)
		ore.commit(out)
	_cache[key] = out
	return out


## Paroi de la mine : un haut bloc de roche irrégulier (et un second, plus
## petit, posé de travers dessus), aux couleurs de l'étage. Les blocs voisins
## se chevauchent un peu : la paroi paraît continue, sans arêtes de cube.
static func wall(theme: String, variant: int) -> ArrayMesh:
	var key := "wall|%s|%d" % [theme, variant]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	# Plus sombre que les rochers à miner : on voit tout de suite ce qui se casse
	var base: Color = STONE.get(theme, STONE.earth).darkened(0.32)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_boulder(st, Vector3.ZERO, Vector3(0.5, 1.55, 0.5), base, "wall", rng)
	_boulder(st, Vector3(rng.randf_range(-0.12, 0.12), 0.75, rng.randf_range(-0.12, 0.12)), Vector3(0.36, 0.8, 0.36), base.lightened(0.04), "wall", rng)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	st.set_material(mat)
	var out := st.commit()
	_cache[key] = out
	return out


## Bloc de pierre : icosphère bosselée, aplatie dessous, teinte par facette
## (dessus plus clair, givré dans les étages de glace). Renvoie les facettes.
static func _boulder(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, theme: String, rng: RandomNumberGenerator, vein: Color = Color(0, 0, 0, 0)) -> Array:
	# Filon : une bande colorée qui traverse le rocher en biais
	var vein_dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.6, 1.2), rng.randf_range(-1, 1)).normalized()
	var vein_at := rng.randf_range(-0.05, 0.08)
	var ico := _icosphere()
	var verts: Array = []
	for v: Vector3 in ico[0]:
		# Bosses irrégulières, dessus taillé à plat, base enfoncée dans le sol
		var p := v * rng.randf_range(0.86, 1.1)
		p = Vector3(p.x * size.x, (p.y + 0.3) * size.y * 0.78, p.z * size.z)
		p.y = clampf(p.y, 0.0, size.y * (0.82 + 0.1 * _bump(v, rng)))
		verts.append(center + p)
	var mid := center + Vector3(0, size.y * 0.5, 0)
	var out: Array = []
	for f: Array in ico[1]:
		var a: Vector3 = verts[f[0]]
		var b: Vector3 = verts[f[1]]
		var c: Vector3 = verts[f[2]]
		var n := _face(st, a, b, c, mid, Color.BLACK, true)
		if n == Vector3.ZERO:
			continue
		var col := color * rng.randf_range(0.88, 1.08)
		if n.y > 0.55:
			col = col.lightened(0.1)
			if theme == "ice":
				col = col.lerp(Color(0.92, 0.97, 1.0), 0.45)
		elif n.y < -0.2:
			col = col.darkened(0.2)
		if vein.a > 0.0:
			var d := absf(((a + b + c) / 3.0 - mid).dot(vein_dir) - vein_at)
			if d < 0.07:
				col = col.lerp(vein, vein.a * (1.0 - d / 0.1))
		col.a = 1.0
		_face(st, a, b, c, mid, col)
		out.append([(a + b + c) / 3.0, n])
	return out


## Petite variation douce (pour la hauteur du dessus taillé).
static func _bump(v: Vector3, rng: RandomNumberGenerator) -> float:
	return sin(v.x * 3.1 + rng.seed % 7) * cos(v.z * 2.7)


## Pépite : petit éclat à facettes à moitié enfoncé dans la roche.
static func _nugget(st: SurfaceTool, at: Vector3, normal: Vector3, r: float, color: Color, rng: RandomNumberGenerator) -> void:
	var basis := _basis_for(normal).rotated(normal, rng.randf() * TAU)
	var pts := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r * 0.7, 0), Vector3(0, -r * 0.5, 0), Vector3(0, 0, r * 0.9), Vector3(0, 0, -r * 0.9)]
	var w: Array = []
	for p: Vector3 in pts:
		w.append(at + basis * (p * rng.randf_range(0.8, 1.2)))
	for t: Array in [[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [0, 4, 3], [4, 1, 3], [1, 5, 3], [5, 0, 3]]:
		var col := color.lightened(0.15) if t.has(2) else color
		_face(st, w[t[0]], w[t[1]], w[t[2]], at, col)


## Cristal : prisme hexagonal terminé en pointe.
static func _crystal(st: SurfaceTool, at: Vector3, axis: Vector3, radius: float, length: float, color: Color) -> void:
	var basis := _basis_for(axis)
	var body := length * 0.72
	var ring_b: Array = []
	var ring_t: Array = []
	for i in 6:
		var a := TAU * float(i) / 6.0
		ring_b.append(at + basis * Vector3(cos(a) * radius, 0, sin(a) * radius))
		ring_t.append(at + basis * Vector3(cos(a) * radius, body, sin(a) * radius))
	var tip := at + basis * Vector3(0, length, 0)
	var mid := at + basis * Vector3(0, body * 0.5, 0)
	for i in 6:
		var j := (i + 1) % 6
		var side := color.darkened(0.12 * float(i % 2))
		_face(st, ring_b[i], ring_t[i], ring_t[j], mid, side)
		_face(st, ring_b[i], ring_t[j], ring_b[j], mid, side)
		_face(st, ring_t[i], tip, ring_t[j], mid, color.lightened(0.25))


## Base orthonormée dont l'axe Y suit `up`.
static func _basis_for(up: Vector3) -> Basis:
	up = up.normalized()
	var side := Vector3.FORWARD if absf(up.y) > 0.9 else Vector3.UP
	var x := side.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)


## Triangle à normale plate, tourné vers l'extérieur (`inside` : un point
## intérieur à la forme). Renvoie la normale (ZERO si dégénéré). Avec
## `dry`, ne dessine rien.
static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color, dry: bool = false) -> Vector3:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-10:
		return Vector3.ZERO
	var n := cr.normalized()
	var outward := (a + b + c) / 3.0 - inside
	if n.dot(outward) < 0.0:
		n = -n
	else:
		var t := b
		b = c
		c = t
	if dry:
		return n
	# Godot : faces avant dans le sens des aiguilles d'une montre vu de dehors
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)
	return n


## Icosphère (une subdivision : 80 facettes).
static func _icosphere() -> Array:
	if not _ico.is_empty():
		return _ico
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array = []
	for p: Vector3 in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		v.append(p.normalized())
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var mids: Dictionary = {}
	var out: Array = []
	for f: Array in faces:
		var m: Array = []
		for k in 3:
			var i0: int = f[k]
			var i1: int = f[(k + 1) % 3]
			var key := Vector2i(mini(i0, i1), maxi(i0, i1))
			if not mids.has(key):
				v.append(((v[i0] as Vector3) + (v[i1] as Vector3)).normalized())
				mids[key] = v.size() - 1
			m.append(mids[key])
		out.append([f[0], m[0], m[2]])
		out.append([f[1], m[1], m[0]])
		out.append([f[2], m[2], m[1]])
		out.append([m[0], m[1], m[2]])
	_ico = [v, out]
	return _ico
