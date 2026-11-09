extends Node
## Test automatique de l'élevage et des lieux : maison, construction du
## poulailler par Mathis, achat d'animaux chez Léon, foin, production,
## traite, horaires des boutiques.
##   godot --headless res://tests/animals_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var hud: Hud = _main.get("_hud")
	# ---- Maison : la porte de la ferme mène à l'intérieur, et retour
	var farm: Farm = _main.call("current_map")
	var door: Vector2i = farm.get("_spawn_cell") + Vector2i.UP
	farm.act_on(door)
	await _frames(3)
	var home: WorldMap = _main.call("current_map")
	_check(home is HomeMap, "la porte de la ferme mène à la maison")
	var slept := [false]
	EventBus.sleep_requested.connect(func() -> void: slept[0] = true)
	home.act_on((home as HomeMap).bed_cell)
	_check(slept[0], "on dort dans le lit de la maison")
	var cooked := [false]
	EventBus.kitchen_requested.connect(func() -> void: cooked[0] = true)
	home.act_on(Vector2i(7, 1))
	_check(cooked[0], "la cuisinière ouvre la cuisine")
	hud.close_modal()
	home.player.position = home.cell_center(Vector2i(6, 7))
	await get_tree().physics_frame
	await _frames(3)
	_check(_main.call("current_map") is Farm, "le seuil de la maison ramène à la ferme")
	# ---- Plus d'animaux d'office : le terrain est vide
	_check(Animals.animals.is_empty() and not Animals.is_built("coop"), "au départ, ni bâtiment ni animal")
	_check(not Animals.buy("chicken"), "impossible d'acheter une poule sans poulailler")
	# ---- Construction du poulailler
	_check(not Animals.start_construction("coop"), "il faut l'or et les matériaux")
	Inventory.add_gold(10000)
	Inventory.add_item("wood", 100)
	Inventory.add_item("stone", 50)
	var gold := Inventory.gold
	_check(Animals.start_construction("coop"), "Mathis lance le chantier du poulailler")
	_check(Inventory.gold == gold - 3000 and Inventory.count_of("wood") == 0, "le chantier coûte 3000 or et les matériaux")
	_check(Animals.under_construction("coop"), "le poulailler est en chantier")
	for i in 2:
		GameFlow.end_day(false)
		hud.close_modal()
	_check(Animals.is_built("coop"), "deux jours plus tard, le poulailler est construit")
	# ---- Achat chez Léon
	_check(Animals.buy("chicken") and Animals.buy("chicken"), "on achète deux poules")
	_check(Animals.animals[0].name != Animals.animals[1].name, "chaque animal a son nom")
	_check(not Animals.buy("cow"), "une vache va dans une étable, pas au poulailler")
	# ---- Foin et production
	Inventory.add_item("hay", 5)
	_check(Animals.fill_feeder("coop") == 5 and Inventory.count_of("hay") == 0, "le foin remplit la mangeoire")
	_check(Animals.pet(0) and not Animals.pet(0), "on caresse une poule une fois par jour")
	var friendship := int(Animals.animals[0].friendship)
	GameFlow.end_day(false)
	hud.close_modal()
	_check(int(Animals.buildings.coop.hay) == 3, "chaque animal mange un foin par nuit")
	_check(int(Animals.animals[0].friendship) > friendship, "nourrie, la poule gagne de l'amitié")
	var got := Animals.collect("coop")
	_check(got.size() == 2 and (Inventory.count_of("egg") + Inventory.count_of("big_egg")) == 2, "on ramasse deux œufs (%s)" % [got])
	_check(Animals.collect("coop").is_empty(), "rien de plus à ramasser le même jour")
	Animals.buildings.coop.hay = 0
	friendship = int(Animals.animals[1].friendship)
	GameFlow.end_day(false)
	hud.close_modal()
	_check(int(Animals.animals[1].friendship) < friendship and Animals.collect("coop").is_empty(), "affamée, la poule perd de l'amitié et ne pond pas")
	# ---- Étable, vache et traite
	Inventory.add_gold(6000)
	Inventory.add_item("wood", 200)
	Inventory.add_item("stone", 100)
	Inventory.add_item("hardwood", 10)
	_check(Animals.start_construction("barn"), "on commande l'étable")
	for i in 2:
		GameFlow.end_day(false)
		hud.close_modal()
	_check(Animals.buy("cow"), "on achète une vache")
	var cow := Animals.animals.size() - 1
	Inventory.add_item("hay", 2)
	Animals.fill_feeder("barn")
	GameFlow.end_day(false)
	hud.close_modal()
	_check(Animals.milk(cow) == "", "pas de traite sans seau à lait")
	Inventory.add_item("milk_pail", 1)
	_check(GameData.base_id(Animals.milk(cow)) == "milk" and Inventory.count_of("milk") == 1, "avec le seau, on trait la vache")
	# ---- Le bâtiment apparaît sur la ferme
	await _go("farm", Vector2i(10, 12))
	farm = _main.call("current_map")
	var plot: Dictionary = farm.plots["coop"]
	_check(farm.get("_interactables").get(plot.door) == "animals:coop", "la porte du poulailler ouvre le soin des animaux")
	# ---- Sauvegarde
	var saved := Animals.to_dict()
	Animals.reset()
	Animals.from_dict(saved)
	_check(Animals.animals.size() == 3 and Animals.is_built("barn"), "l'élevage est sauvegardé")
	# ---- Boutiques : marchands différents, horaires
	_check(Shops.items("cooperative").has("hay") and Shops.items("cooperative").has("milk_pail"), "Margot vend le foin et le seau")
	_check(not Shops.items("store").has("hay"), "Rosalie ne vend pas de foin")
	TimeManager.minutes = 10 * 60
	_check(Shops.is_open("ranch") and Shops.is_open("cooperative"), "le ranch et la coopérative ouvrent le matin")
	TimeManager.minutes = 16 * 60 + 30
	_check(not Shops.is_open("ranch") and not Shops.is_open("cooperative"), "ils ferment l'après-midi")
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
