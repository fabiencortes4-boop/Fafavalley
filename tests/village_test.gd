extends Node
## Test automatique du village : passage ferme -> village, emplois du temps
## des habitants, discussion, cadeaux, boutique, retour à la ferme.
##   godot --headless res://tests/village_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var farm: WorldMap = _main.call("current_map")
	# Marcher jusqu'au bord est de la ferme
	farm.player.position = farm.cell_center(Vector2i(39, 9))
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var village: WorldMap = _main.call("current_map")
	_check(village is Village, "le bord est de la ferme mène au village")
	_check(village.player_cell() == Vector2i(2, 19), "on arrive à l'entrée du village")
	var v: Village = village as Village
	_check(v.npcs.size() == 10, "10 habitants au village")
	# Jardins : ils ne coupent aucun trajet des habitants
	var blocked_routes: Array = []
	for n: Npc in v.npcs:
		for e: Dictionary in GameData.npc(n.id).get("schedule", []):
			if e.has("cell") and v.find_path(n.home_cell, Vector2i(int(e.cell[0]), int(e.cell[1]))).is_empty():
				blocked_routes.append("%s -> %s" % [n.id, e.cell])
	_check(Village.gardens().size() >= 15 and blocked_routes.is_empty(), "%d jardins, tous les trajets restent possibles %s" % [Village.gardens().size(), blocked_routes])
	# 6h : tout le monde dort encore
	# (sauf Jules le pêcheur, déjà au bord de l'étang à 6h)
	_check(v.npcs.all(func(n: Npc) -> bool: return n.is_inside() or n.id == "jules"), "à 6h, les habitants sont chez eux")
	var jules: Npc = v.npcs.filter(func(n: Npc) -> bool: return n.id == "jules")[0]
	_check(not jules.is_inside(), "Jules le pêcheur est déjà dehors à 6h")
	# Avancer à 8h30 : Rosalie sort et marche vers sa place
	TimeManager.minutes = 8 * 60 + 30
	TimeManager.time_changed.emit(8, 30)
	var rosalie: Npc = v.npcs.filter(func(n: Npc) -> bool: return n.id == "rosalie")[0]
	_check(not rosalie.is_inside(), "à 8h30, Rosalie est sortie")
	await get_tree().create_timer(2.0).timeout
	_check(rosalie.cell() == Vector2i(24, 18), "Rosalie a marché jusqu'à sa place (%s)" % rosalie.cell())
	# Parler : première rencontre
	v.player.position = v.cell_center(Vector2i(24, 19))
	v.act_on(Vector2i(24, 18))
	_check(Relations.met.has("rosalie"), "on fait connaissance avec Rosalie")
	_check(Relations.points.get("rosalie", 0) == Relations.TALK_POINTS, "parler donne des points d'amitié")
	_main._hud.close_modal()
	v.act_on(Vector2i(24, 18))
	_check(Relations.points.get("rosalie", 0) == Relations.TALK_POINTS, "une seule discussion comptée par jour")
	_main._hud.close_modal()
	# Cadeau aimé
	Inventory.add_item("tomato", 2)
	for i in Inventory.SIZE:
		if Inventory.slots[i] != null and Inventory.slots[i].id == "tomato":
			Inventory.select(i)
	v.act_on(Vector2i(24, 18))
	_check(Relations.points.get("rosalie", 0) == Relations.TALK_POINTS + 80, "Rosalie adore les tomates (+80)")
	_check(Inventory.count_of("tomato") == 1, "le cadeau quitte l'inventaire")
	_main._hud.close_modal()
	v.act_on(Vector2i(24, 18))
	_check(Inventory.count_of("tomato") == 1, "un seul cadeau par jour")
	_main._hud.close_modal()
	# Épicerie : on entre (9h30), Rosalie est au comptoir, on ressort ; fermée à 18h
	TimeManager.minutes = 9 * 60 + 30
	TimeManager.time_changed.emit(9, 30)
	v.act_on(Vector2i(26, 17))
	await _frames(3)
	var store: WorldMap = _main.call("current_map")
	_check(store is InteriorMap and store.map_id == "in:store", "la porte mène à l'intérieur de l'épicerie")
	_check((store as InteriorMap).residents.any(func(n: Npc) -> bool: return n.id == "rosalie"), "Rosalie tient sa boutique à 9h30")
	var opened := [false]
	EventBus.shop_opened.connect(func(_id: String) -> void: opened[0] = true)
	store.act_on(Vector2i(4, 3))
	_check(opened[0], "le comptoir ouvre la boutique")
	_main._hud.close_modal()
	store.player.position = store.cell_center(Vector2i(5, 7))
	await get_tree().physics_frame
	await _frames(3)
	v = _main.call("current_map")
	_check(v is Village and v.player_cell() == Vector2i(26, 18), "on ressort devant l'épicerie")
	TimeManager.minutes = 18 * 60
	v.act_on(Vector2i(26, 17))
	await _frames(3)
	_check(_main.call("current_map") == v, "l'épicerie est fermée à 18h")
	_main._hud.close_modal()
	# Une maison : on entre chez Odette en journée
	TimeManager.minutes = 10 * 60
	v.act_on(Vector2i(6, 26))
	await _frames(3)
	_check(_main.call("current_map").map_id == "in:odette", "on peut rendre visite à Odette")
	_main.call("current_map").player.position = _main.call("current_map").cell_center(Vector2i(4, 6))
	await get_tree().physics_frame
	await _frames(3)
	v = _main.call("current_map")
	# Le soir, tout le monde rentre
	TimeManager.minutes = 22 * 60
	TimeManager.time_changed.emit(22, 0)
	await get_tree().create_timer(22.0).timeout
	_check(v.npcs.all(func(n: Npc) -> bool: return n.is_inside()), "à 22h, les habitants sont rentrés")
	# S'évanouir au village -> réveil à la maison
	GameFlow.end_day(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_main.call("current_map") is HomeMap, "on se réveille à la maison")
	_check(not Relations.talked_today.has("rosalie"), "les discussions sont remises à zéro chaque jour")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
