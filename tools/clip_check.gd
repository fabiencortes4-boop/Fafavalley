extends Node
## Détecte les objets 3D qui se chevauchent : décor qui rentre dans une
## maison (murs, toit) et gros objets de décor qui s'interpénètrent.
##   xvfb-run godot --rendering-driver opengl3 res://tools/clip_check.tscn -- village port farm

const OVERHANG := 0.24


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.call("_start", false)
	Tutorial.skip()
	var total := 0
	for place: String in (args if not args.is_empty() else ["village", "port", "farm"]):
		main.call("_switch_to", place)
		for i in 3:
			await get_tree().process_frame
		total += _check(place)
	print("CLIP TOTAL : %d" % total)
	get_tree().quit()


func _check(place: String) -> int:
	var view: Node3D = View3D.current
	var houses: Array = []  # [Rect2, racine]
	for n in view.find_children("*", "Node3D", true, false):
		if n.has_meta("house_rect"):
			houses.append([n.get_meta("house_rect"), n])
	var objects: Array = []  # [AABB, nom]
	for n in view.find_children("*", "GeometryInstance3D", true, false):
		if not (n as Node3D).is_visible_in_tree() or _in_house(n, houses) or _is_actor(n, view):
			continue
		if n is MultiMeshInstance3D:
			var mm := (n as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			var base := mm.mesh.get_aabb()
			for i in mm.instance_count:
				objects.append([((n as Node3D).global_transform * mm.get_instance_transform(i)) * base, "%s#%d (%s)" % [n.get_parent().name, i, _mesh_name(mm.mesh)]])
		elif n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			objects.append([(n as Node3D).global_transform * (n as MeshInstance3D).mesh.get_aabb(), _label(n)])
	var count := 0
	for o: Array in objects:
		var box: AABB = o[0]
		if box.size.x > 3.0 or box.size.z > 3.0 or box.size.y < 0.25:
			continue  # sol, eau, grands maillages fusionnés, herbe
		var center := Vector2(box.get_center().x, box.get_center().z)
		for h: Array in houses:
			var r: Rect2 = h[0]
			if r.grow(0.05).has_point(center):
				continue  # la maison elle-même (murs)
			# Murs (emprise de la maison) et toit (avec son débord, au-dessus de 0,85)
			var walls := AABB(Vector3(r.position.x - 0.1, 0.12, r.position.y - 0.1), Vector3(r.size.x + 0.2, 1.0, r.size.y + 0.25))
			var roof := AABB(Vector3(r.position.x - OVERHANG, 0.85, r.position.y - OVERHANG), Vector3(r.size.x + OVERHANG * 2, 1.6, r.size.y + OVERHANG * 2))
			var hit := false
			for vol: AABB in [walls, roof]:
				var inter := vol.intersection(box)
				if inter.size.x > 0.03 and inter.size.z > 0.03 and inter.size.y > 0.05:
					hit = true
			if hit:
				print("%s : %s (%.1f, %.1f) entre dans la maison %s" % [place, o[1], center.x, center.y, r])
				count += 1
	# Gros objets qui se chevauchent entre eux
	var big := objects.filter(func(o: Array) -> bool: return (o[0] as AABB).size.y > 0.3 and (o[0] as AABB).size.x < 2.0 and (o[0] as AABB).size.z < 2.0)
	for i in big.size():
		for j in range(i + 1, big.size()):
			var a: AABB = big[i][0]
			var b: AABB = big[j][0]
			var ta := str(big[i][1]).contains("tree")
			var tb := str(big[j][1]).contains("tree")
			if ta != tb and not _plant(str(big[i][1] if tb else big[j][1])):
				# Feuillage d'un arbre (haut de sa boîte) contre un objet solide
				var tree: AABB = a if ta else b
				var crown := AABB(tree.position + Vector3(tree.size.x * 0.15, tree.size.y * 0.35, tree.size.z * 0.15), tree.size * Vector3(0.7, 0.65, 0.7))
				var hit := crown.intersection(b if ta else a)
				if hit.size.x > 0.1 and hit.size.z > 0.1 and hit.size.y > 0.05:
					print("%s : feuillage %s touche %s vers (%.1f, %.1f)" % [place, big[i][1] if ta else big[j][1], big[j][1] if ta else big[i][1], hit.get_center().x, hit.get_center().z])
					count += 1
				continue
			if _plant(str(big[i][1])) or _plant(str(big[j][1])):
				continue  # végétation : les feuillages se touchent, c'est voulu
			var inter := a.intersection(b)
			if inter.size.x > 0.15 and inter.size.z > 0.15 and inter.size.y > 0.1:
				print("%s : %s chevauche %s vers (%.1f, %.1f)" % [place, big[i][1], big[j][1], inter.get_center().x, inter.get_center().z])
				count += 1
	print("%s : %d chevauchements" % [place, count])
	return count


func _in_house(n: Node, houses: Array) -> bool:
	for h: Array in houses:
		if (h[1] as Node).is_ancestor_of(n):
			return true
	return false


func _is_actor(n: Node, view: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != view:
		if p.get_parent() == view and p.name != "Static" and p != view.get("_static"):
			return p != view.get("_static")
		p = p.get_parent()
	return false


func _mesh_name(m: Mesh) -> String:
	return m.resource_name if m.resource_name != "" else str(m.get_aabb().size.snapped(Vector3.ONE * 0.1))


func _label(n: Node) -> String:
	var p := n
	while p.get_parent() != null and p.get_parent() != View3D.current and p.get_parent() != View3D.current.get("_static"):
		p = p.get_parent()
	return "%s/%s (%s)" % [p.name, n.name, _mesh_name((n as MeshInstance3D).mesh)]


func _plant(name: String) -> bool:
	for w: String in ["tree", "grass", "bush", "flower", "plant", "mushroom", "crop", "hedge", "leek", "cabbage", "carrot", "tomato"]:
		if name.contains(w):
			return true
	return false
