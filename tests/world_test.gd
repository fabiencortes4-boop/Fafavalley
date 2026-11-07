extends Node
## Test automatique : tableau des demandes, scènes de cœur, anniversaires,
## zones débloquées par l'histoire (forêt, mine, source).
##   godot --headless res://tests/world_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var hud: Hud = _main.get("_hud")
	Tutorial.skip()
	_check(Story.arrival.size() >= 5, "une scène d'arrivée à Valfleur ouvre l'histoire")
	# ---- Zones fermées au début
	var farm: Farm = _main.call("current_map")
	_check(not farm.is_walkable(Vector2i(23, 1)), "un tronc barre le chemin de la forêt")
	_check(not Village.mine_open(), "la mine est éboulée au début")
	# ---- Tableau des demandes
	await _go("village", Vector2i(32, 19))
	var v: Village = _main.call("current_map")
	var board_opened := [false]
	EventBus.board_requested.connect(func() -> void: board_opened[0] = true)
	v.act_on(Vector2i(33, 18))
	_check(board_opened[0] and hud.get("_modal") != null, "le panneau de la place ouvre le tableau des demandes")
	hud.close_modal()
	var offers := Quests.offers()
	_check(offers.size() == 3 and offers == Quests.offers(), "3 demandes par jour, les mêmes toute la journée")
	_check(Quests.accept(0) and not Quests.accept(0), "on accepte une demande (une seule fois)")
	var q: Dictionary = Quests.active[0]
	var found := v.npcs.filter(func(n: Npc) -> bool: return n.id == q.npc)
	var npc: Npc
	if found.is_empty():
		# Demande d'un habitant du port : on le fait venir pour le test
		npc = Npc.new()
		npc.id = str(q.npc)
		v.get("_entities").add_child(npc)
	else:
		npc = found[0]
	_check(Quests.deliverable(str(q.npc)) == -1, "sans les objets, rien à livrer")
	Inventory.add_item(str(q.item), int(q.qty))
	var gold := Inventory.gold
	var points := int(Relations.points.get(q.npc, 0))
	v.talk_to_npc(npc)
	hud.close_modal()
	_check(Quests.active.is_empty() and Inventory.gold == gold + int(q.gold), "parler à l'habitant livre la demande (+%d or)" % int(q.gold))
	_check(int(Relations.points.get(q.npc, 0)) > points, "et rapporte de l'amitié")
	_check(Story.stats.get("quests", 0) == 1, "les demandes comptent pour l'histoire")
	Quests.accept(1)
	for i in 3:
		Quests.new_day()
	_check(Quests.active.is_empty(), "une demande expire après 3 jours")
	# ---- Scène de cœur à 2 cœurs
	var scene_for := [""]
	EventBus.heart_scene_requested.connect(func(id: String, _s: Dictionary) -> void: scene_for[0] = id)
	var lina: Npc = v.npcs.filter(func(n: Npc) -> bool: return n.id == "lina")[0]
	Relations.met["lina"] = true
	Relations.add_points("lina", 2 * Relations.POINTS_PER_HEART)
	v.talk_to_npc(lina)
	_check(scene_for[0] == "lina" and hud.get("_modal") != null, "à 2 cœurs, une scène se joue avec Lina")
	var e := HeartEvents.pending("lina")
	var before := int(Relations.points["lina"])
	var reply := HeartEvents.choose("lina", e, 0)
	_check(reply != "" and int(Relations.points["lina"]) > before, "le choix de réponse change l'amitié")
	_check(HeartEvents.pending("lina").is_empty(), "la scène ne se rejoue pas")
	hud.close_modal()
	# ---- Anniversaire : cadeau x5
	TimeManager.season = 1
	TimeManager.day = 9
	_check(HeartEvents.birthday_today() == "lina", "le 9 de l'été, c'est l'anniversaire de Lina")
	var p0 := int(Relations.points["lina"])
	Relations.gifted_today.erase("lina")
	Relations.give_gift("lina", "wheat")
	_check(int(Relations.points["lina"]) - p0 == Relations.GIFT_POINTS.loved * HeartEvents.BIRTHDAY_FACTOR, "un cadeau d'anniversaire compte 5 fois plus")
	TimeManager.season = 0
	TimeManager.day = 1
	# ---- Chapitre 1 : la forêt s'ouvre
	PlayerState.flags["story_ch1"] = true
	await _go("farm", Vector2i(23, 3))
	farm = _main.call("current_map")
	_check(farm.is_walkable(Vector2i(23, 1)), "après le chapitre 1, le tronc est dégagé")
	farm.player.position = farm.cell_center(Vector2i(23, 0))
	await get_tree().physics_frame
	await _frames(3)
	var forest: WorldMap = _main.call("current_map")
	_check(forest is ForestMap, "le chemin du nord mène à la Forêt de la source")
	_check(not forest.is_walkable(Vector2i(19, 7)), "des ronces cachent la source")
	_check((forest.get("_forage_sprites") as Dictionary).size() >= 5, "la forêt a ses cueillettes (%d)" % (forest.get("_forage_sprites") as Dictionary).size())
	_check(GameData.fishes.values().filter(func(f: Dictionary) -> bool: return "forest" in f.places).size() >= 4, "on peut pêcher dans le lac de la forêt")
	# ---- Chapitre 4 : les ronces sont coupées
	PlayerState.flags["story_ch4"] = true
	await _go("forest", Vector2i(22, 23))
	forest = _main.call("current_map")
	_check(forest.is_walkable(Vector2i(19, 7)), "après le chapitre 4, les ronces sont coupées")
	# ---- Retour à la ferme par le bas de la forêt
	forest.player.position = forest.cell_center(Vector2i(22, 25))
	await get_tree().physics_frame
	await _frames(3)
	_check(_main.call("current_map") is Farm, "le bas de la forêt ramène à la ferme")
	# ---- Chapitre 2 : la mine se dégage
	PlayerState.flags["story_ch2"] = true
	_check(Village.mine_open(), "après le chapitre 2, la mine est rouverte")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _go(map_id: String, cell: Vector2i) -> void:
	EventBus.map_change_requested.emit(map_id, cell)
	await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
