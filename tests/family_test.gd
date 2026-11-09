extends Node
## Test automatique : arbres fruitiers, serre, mariage.
##   godot --headless res://tests/family_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	Tutorial.skip()
	var hud: Hud = _main.get("_hud")
	var farm: Farm = _main.call("current_map")
	FarmState.debris.clear()
	farm.call("_refresh_all")
	# ---- Arbres fruitiers
	_check(Shops.items("store").has("sapling_cherry"), "Rosalie vend de jeunes arbres fruitiers")
	Inventory.add_item("sapling_cherry", 2)
	_select("sapling_cherry")
	var cell := Vector2i(20, 14)
	farm.player.position = farm.cell_center(cell + Vector2i.DOWN)
	farm.act_on(cell)
	_check(FarmState.objects.get(cell) == "tree" and Inventory.count_of("sapling_cherry") == 1, "on plante un cerisier sur l'herbe")
	farm.act_on(cell + Vector2i.RIGHT)
	_check(Inventory.count_of("sapling_cherry") == 1, "pas deux arbres collés")
	_check(not farm.is_walkable(cell), "l'arbre bloque le passage")
	for i in 10:
		FarmState.advance_day(0, false)
	_check(FarmState.tree_stage(cell) == 2, "adulte en 10 jours")
	_check(int(FarmState.trees[cell].fruits) >= 1, "il donne des fruits au printemps")
	FarmState.advance_day(0, false)
	FarmState.advance_day(0, false)
	FarmState.advance_day(0, false)
	_check(int(FarmState.trees[cell].fruits) == FarmState.MAX_FRUITS, "3 fruits au plus sur l'arbre")
	farm.act_on(cell)
	_check(Inventory.count_of("cherry") == 3 and int(FarmState.trees[cell].fruits) == 0, "secouer l'arbre donne les cerises")
	FarmState.advance_day(1, false)
	_check(int(FarmState.trees[cell].fruits) == 0, "pas de cerises en été")
	# ---- Serre
	_check(Animals.data.buildings.has("greenhouse"), "Mathis peut construire une serre")
	Inventory.add_gold(10000)
	Inventory.add_item("wood", 200)
	Inventory.add_item("stone", 100)
	Inventory.add_item("hardwood", 10)
	Inventory.add_item("quartz", 5)
	_check(Animals.start_construction("greenhouse"), "on commande la serre")
	for i in 3:
		GameFlow.end_day(false)
		hud.close_modal()
	_check(Animals.is_built("greenhouse"), "la serre est construite en 3 jours")
	EventBus.map_change_requested.emit("farm", Vector2i(6, 26))
	await _frames(3)
	farm = _main.call("current_map")
	var inside := Vector2i(6, 23)
	_check(FarmState.in_greenhouse(inside) and farm.is_walkable(inside), "on entre dans la serre")
	_check(not farm.is_walkable(Vector2i(3, 22)), "ses murs vitrés bloquent le passage")
	TimeManager.season = 3
	FarmState.till(inside)
	Inventory.add_item("seed_tomato", 1)
	_select("seed_tomato")
	farm.player.position = farm.cell_center(inside + Vector2i.DOWN)
	farm.call("_plant", inside, "tomato")
	_check(FarmState.get_crop(inside) == "tomato", "dans la serre, on plante des tomates en hiver")
	FarmState.water(inside)
	FarmState.advance_day(3, true)
	_check(FarmState.get_crop(inside) == "tomato", "et elles survivent à l'hiver")
	_check(not FarmState.is_watered(inside), "la pluie n'entre pas dans la serre")
	TimeManager.season = 0
	# ---- Mariage
	var rosalie := "rosalie"
	Relations.met[rosalie] = true
	Relations.add_points(rosalie, 3000)
	_check(Relations.hearts(rosalie) == 8, "célibataire : 8 cœurs au plus avant de sortir ensemble")
	_check(Marriage.give("gaston", "bouquet").used == false, "Gaston n'est pas un prétendant")
	var res := Marriage.give(rosalie, "bouquet")
	_check(res.used and Marriage.dating.has(rosalie), "à 8 cœurs, le bouquet : on sort ensemble")
	_check(Marriage.give(rosalie, "pendant").used == false, "trop tôt pour le pendentif")
	Relations.add_points(rosalie, 1000)
	_check(Relations.hearts(rosalie) == 10, "en couple, l'amitié monte jusqu'à 10 cœurs")
	_check(Crafting.recipes.has("pendant") and Crafting.recipes.pendant.station == "forge", "Gaston forge le pendentif de la source")
	res = Marriage.give(rosalie, "pendant")
	_check(res.used and Marriage.fiance == rosalie, "à 10 cœurs, le pendentif : la demande en mariage")
	for i in 3:
		GameFlow.end_day(false)
		hud.close_modal()
	_check(Marriage.spouse == rosalie and Marriage.wedding_pending, "3 jours plus tard : le mariage")
	await _frames(3)
	_check(hud.get("_modal") != null, "la scène du mariage se joue")
	for i in 12:
		hud.close_modal()
		await _frames(1)
	Marriage.wedding_pending = false
	# ---- La vie à deux
	TimeManager.minutes = 8 * 60
	EventBus.map_change_requested.emit("home", Vector2i(6, 6))
	await _frames(3)
	var home: WorldMap = _main.call("current_map")
	_check(home.get("_spouse_npc") != null, "le matin, Rosalie est à la maison")
	var said := [""]
	EventBus.dialogue_requested.connect(func(id: String, text: String) -> void: said[0] = id + ":" + text)
	home.act_on(Vector2i(8, 5))
	_check(said[0].begins_with("rosalie:"), "on lui parle à la maison")
	hud.close_modal()
	TimeManager.minutes = 14 * 60
	TimeManager.weather = "sunny"
	EventBus.map_change_requested.emit("farm", Vector2i(10, 12))
	await _frames(3)
	_check(_main.call("current_map").get("_spouse_npc") != null, "l'après-midi, elle est dehors à la ferme")
	await _go("village", Vector2i(2, 19))
	var v: Village = _main.call("current_map")
	_check(not v.npcs.any(func(n: Npc) -> bool: return n.id == rosalie), "elle ne vit plus au village")
	FarmState.till(Vector2i(15, 15))
	var helped := false
	for i in 20:
		Marriage.new_day()
		if Marriage.last_help != "":
			helped = true
	_check(helped, "chaque matin, elle aide à la ferme")
	var saved := Marriage.to_dict()
	Marriage.reset()
	Marriage.from_dict(saved)
	_check(Marriage.spouse == rosalie, "le mariage est sauvegardé")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _select(id: String) -> void:
	for i in Inventory.SIZE:
		if Inventory.slots[i] != null and Inventory.slots[i].id == id:
			Inventory.select(i)


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
