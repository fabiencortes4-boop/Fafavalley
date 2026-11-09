extends Node
## Test automatique des « petits plus » : défi du jour, commande de la
## semaine, rumeurs, météo de la ferme, épouvantail, hybrides, miel parfumé,
## rénovations, musée, compagnon, beauté et visiteurs, mode photo, grotte.
##   godot --headless res://tests/fun_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	Tutorial.skip()
	var hud: Node = _main.get("_hud")
	# ---- Défi du jour
	_check(not Challenges.today.is_empty() and Challenges.summary() != "", "un défi du jour dès le premier matin : %s" % Challenges.summary())
	Challenges.today = {"stat": "harvest", "text": "Récolte 3 cultures", "goal": 3, "base": int(Story.stats.get("harvest", 0)), "gold": 150, "done": false}
	var gold := Inventory.gold
	Story.bump("harvest", 3)
	_check(bool(Challenges.today.done) and Inventory.gold >= gold + 150, "le défi réussi rapporte de l'or")
	# ---- Commande de la semaine
	Quests.active.clear()
	Quests.weekly_order()
	var big: Array = Quests.active.filter(func(q: Dictionary) -> bool: return q.get("big", false))
	_check(big.size() == 1 and int(big[0].days_left) == 7, "une commande de la semaine, à livrer en 7 jours")
	_check(Quests.can_accept(0), "elle ne prend pas la place des demandes du tableau")
	# ---- Rumeurs de la taverne
	Rumors.reset()
	Rumors._day = Rumors._day_number()
	Rumors.today = {"type": "shoal", "fish": "carp", "heard": false}
	_check(Rumors.fish_factor("carp") == 1, "sans l'avoir entendue, la rumeur ne change rien")
	_check(Rumors.try_hear("marius") != "" and Rumors.fish_factor("carp") == 5, "le banc de poissons dont parle Marius mord bien plus")
	Rumors.today = {"type": "purse", "gold": 400, "heard": false}
	Rumors.try_hear("marius")
	var place := str(Rumors.today.get("place", ""))
	_check(place != "" and Forage.spots.get(place, {}).values().has("lost_purse"), "la bourse perdue est cachée dans la nature")
	Rumors.today = {"type": "gift", "npc": "lina", "item": "sunflower", "heard": false}
	Rumors.try_hear("marius")
	_check(Rumors.gift_factor("lina", "sunflower") == 2, "le cadeau rêvé compte double")
	# ---- Ferme : météo, corbeaux, hybrides, miel
	FarmState.weather_events = true
	FarmState.tiles.clear()
	FarmState.objects.clear()
	var cell := Vector2i(20, 14)
	FarmState.till(cell)
	FarmState.plant(cell, "tomato")
	TimeManager.heat_yesterday = true
	FarmState.water(cell)
	FarmState.advance_day(1, false)
	_check(int(FarmState.tiles[cell].age) == 0 and int(FarmState.last_night.heat) == 1, "canicule : un seul arrosage ne suffit pas")
	FarmState.water(cell)
	FarmState.water(cell)
	FarmState.advance_day(1, false)
	_check(int(FarmState.tiles[cell].age) == 1, "arrosée deux fois, elle pousse")
	TimeManager.heat_yesterday = false
	# Corbeaux : 20 cultures sans épouvantail, puis avec
	FarmState.tiles.clear()
	for i in 20:
		var c := Vector2i(10 + i % 5, 12 + i / 5)
		FarmState.till(c)
		FarmState.plant(c, "carrot")
	var eaten := 0
	for night in 12:
		FarmState.advance_day(0, true)
		eaten += int(FarmState.last_night.crows)
	_check(eaten > 0, "les corbeaux picorent une grande ferme sans épouvantail (%d)" % eaten)
	FarmState.place_object(Vector2i(12, 13), "scarecrow")
	eaten = 0
	for night in 12:
		for i in 20:
			var c := Vector2i(10 + i % 5, 12 + i / 5)
			if FarmState.get_crop(c) == "":
				FarmState.plant(c, "carrot")
		FarmState.advance_day(0, true)
		eaten += int(FarmState.last_night.crows)
	_check(eaten == 0, "l'épouvantail protège les cultures autour de lui")
	# Hybrides : deux cultures mûres et différentes côte à côte
	FarmState.tiles.clear()
	FarmState.objects.clear()
	var a := Vector2i(30, 14)
	for c: Vector2i in [a, a + Vector2i.RIGHT]:
		FarmState.till(c)
	FarmState.plant(a, "carrot")
	FarmState.plant(a + Vector2i.RIGHT, "radish")
	FarmState.tiles[a].age = 10
	FarmState.tiles[a + Vector2i.RIGHT].age = 10
	var seeds := Inventory.count_of("seed_hybrid")
	for night in 120:
		FarmState.advance_day(0, true)
		FarmState.tiles[a].age = 10
		FarmState.tiles[a + Vector2i.RIGHT].age = 10
	_check(Inventory.count_of("seed_hybrid") > seeds, "deux cultures voisines donnent parfois des graines hybrides")
	# Miel parfumé : ruche près de tournesols
	FarmState.tiles.clear()
	var hive := Vector2i(22, 18)
	FarmState.place_object(hive, "beehive")
	Machines.start_auto(hive, "beehive")
	FarmState.till(hive + Vector2i(2, 0))
	FarmState.plant(hive + Vector2i(2, 0), "sunflower")
	TimeManager.season = 1
	for night in 5:
		Machines.new_day()
	_check(str(Machines.state[hive].output).begins_with("flower_honey:sunflower"), "une ruche près des tournesols donne du miel de tournesol (%s)" % GameData.item_name(str(Machines.state[hive].output)))
	TimeManager.season = 0
	FarmState.weather_events = false
	# ---- Rénovations du village
	Inventory.add_gold(20000)
	for e: Array in [["wood", 150], ["stone", 80], ["hardwood", 10]]:
		Inventory.add_item(e[0], e[1])
	_check(Projects.fund("mill") and Projects.state("mill") == "works" and Projects.sell_factor("wheat") == 1.0, "le moulin : d'abord des travaux")
	for i in Projects.WORK_DAYS:
		TimeManager.day += 1
		Projects.new_day()
	TimeManager.day -= Projects.WORK_DAYS
	_check(Projects.state("mill") == "done" and Projects.sell_factor("wheat") == 1.5, "le moulin rénové : le blé se vend 50 % plus cher")
	# ---- Musée
	for p: String in Museum.PIECES:
		Inventory.add_item(p, 1)
		Museum.donate(p)
	_check(Museum.complete() and PlayerState.flags.has("museum_complete"), "le squelette complet au musée")
	_check(Museum.roll_find(1.0) in Museum.PIECES, "on trouve des fossiles")
	# ---- Compagnon
	var scene: Dictionary = HeartEvents.pending("leon")
	_check(scene.get("pet", false), "Léon propose d'adopter un compagnon")
	HeartEvents.choose("leon", scene, 1)
	_check(Pet.kind == "dog" and Pet.pet_name == "Biscuit", "on adopte Biscuit, le chiot")
	_main.call("_switch_to", "farm")
	await get_tree().process_frame
	await get_tree().process_frame
	var farm: WorldMap = _main.call("current_map")
	var follower: Node = farm.get("_pet")
	_check(follower != null and is_instance_valid(follower), "le chiot suit le joueur à la ferme")
	farm.player.position += Vector2(60, 0)
	for i in 120:
		await get_tree().process_frame
	_check(follower.position.distance_to(farm.player.position) < 40.0, "il rattrape le joueur")
	_check(Pet.pet() and not Pet.pet(), "une caresse par jour")
	# ---- Beauté et visiteurs du dimanche
	FarmState.objects.clear()
	for i in 4:
		FarmState.place_object(Vector2i(8 + i * 2, 11), "garden_fountain")
	_check(FarmState.beauty() >= 40 and FarmState.visitors_count() >= 1, "la décoration embellit la ferme (beauté %d)" % FarmState.beauty())
	while TimeManager.weekday() != "Dim.":
		TimeManager.day += 1
	_main.call("_switch_to", "farm")
	await get_tree().process_frame
	await get_tree().process_frame
	farm = _main.call("current_map")
	var visitors: Array = farm.get("_visitors")
	_check(visitors.size() == FarmState.visitors_count(), "le dimanche, des habitants visitent la belle ferme (%d)" % visitors.size())
	FarmState.place_object(Vector2i(20, 20), "garden_bench")
	await get_tree().process_frame
	_check(farm.seats.has(Vector2i(20, 20)), "on peut s'asseoir sur le banc de jardin")
	# ---- Mode photo
	hud.call("open_photo_mode")
	await get_tree().process_frame
	_check(hud.get("_photo_layer") != null, "le mode photo s'ouvre")
	hud.call("close_photo_mode")
	_check(hud.get("_photo_layer") == null and hud.get("_hotbar").visible, "et l'interface revient en le quittant")
	# ---- Grotte cachée
	_main.call("_switch_to", "cave")
	await get_tree().process_frame
	await get_tree().process_frame
	var cave: CaveMap = _main.call("current_map")
	_check(cave is CaveMap, "on entre dans la grotte des lucioles")
	cave.call("_pull", "s")
	_check(cave.pulled.is_empty() and not CaveMap.solved(), "mauvais ordre : les leviers reviennent")
	gold = Inventory.gold
	cave.call("_open_chest")
	_check(Inventory.gold == gold, "la grille protège le coffre")
	for l: String in CaveMap.ORDER:
		cave.call("_pull", l)
	_check(CaveMap.solved(), "étoile, lune, soleil : l'énigme est résolue")
	cave.call("_open_chest")
	_check(Inventory.gold >= gold + 1500 and PlayerState.flags.has("cave_chest"), "le coffre de Firmin s'ouvre")
	_check(cave.call("_warp_for", Vector2i(8, 9)).get("map", "") == "forest", "la sortie ramène en forêt")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  ÉCHEC ") + label)
	if not ok:
		_failures += 1
