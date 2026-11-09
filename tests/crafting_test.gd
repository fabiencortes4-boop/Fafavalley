extends Node
## Test automatique de la fabrication : arroseurs, engrais, cuisine,
## améliorations de la forge, filons reconnaissables.
##   godot --headless res://tests/crafting_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var farm: Farm = _main.call("current_map")
	# Ferme sans débris aléatoires : tests reproductibles
	FarmState.debris.clear()
	farm.call("_refresh_all")
	# Recettes débloquées par l'histoire (testée à part dans story_test)
	for c: Dictionary in Story.chapters:
		PlayerState.flags["story_" + str(c.id)] = true
	Story.chapter = Story.chapters.size()
	# Arroseur
	_check(not Crafting.can_craft("sprinkler"), "sans minerai, pas d'arroseur")
	Inventory.add_item("copper_ore", 9)
	Inventory.add_item("iron_ore", 6)
	_check(Crafting.craft("sprinkler"), "on fabrique un arroseur")
	_check(Inventory.count_of("copper_ore") == 5 and Inventory.count_of("iron_ore") == 5, "les ingrédients sont consommés")
	var center := Vector2i(14, 15)
	farm.player.position = farm.cell_center(center + Vector2i(0, -3))
	_select("sprinkler")
	farm.act_on(center)
	_check(FarmState.objects.get(center) == "sprinkler", "on pose l'arroseur sur la ferme")
	_check(not farm.is_walkable(center), "on ne traverse pas un arroseur")
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1)]:
		FarmState.till(center + offset)
	FarmState.plant(center + Vector2i.LEFT, "carrot")
	# Nuit sans pluie (la pluie arroserait tout, y compris les diagonales)
	FarmState.advance_day(0, false)
	_check(FarmState.is_watered(center + Vector2i.LEFT) and FarmState.is_watered(center + Vector2i.DOWN), "l'arroseur arrose les 4 cases voisines le matin")
	_check(not FarmState.is_watered(center + Vector2i(1, 1)), "mais pas les diagonales")
	# Ramasser l'arroseur avec la pioche
	Inventory.add_item("pickaxe", 1)
	_select("pickaxe")
	farm.act_on(center)
	_check(not FarmState.objects.has(center) and Inventory.count_of("sprinkler") == 1, "la pioche ramasse l'arroseur")
	# Engrais : pousse plus vite
	Inventory.add_item("slime", 2)
	Inventory.add_item("coal", 1)
	_check(Crafting.craft("fertilizer") and Inventory.count_of("fertilizer") == 5, "l'engrais se fabrique par 5")
	var a := center + Vector2i.UP
	var b := center + Vector2i.RIGHT
	FarmState.plant(a, "corn")
	FarmState.plant(b, "corn")
	_select("fertilizer")
	farm.act_on(a)
	_check(FarmState.is_fertilized(a), "on épand de l'engrais sur la terre labourée")
	for i in 6:
		FarmState.water(a)
		FarmState.water(b)
		FarmState.advance_day(1, false)
	_check(FarmState.tiles[a].age > FarmState.tiles[b].age, "la culture avec engrais pousse plus vite (%d contre %d)" % [FarmState.tiles[a].age, FarmState.tiles[b].age])
	# Cuisine
	for id in ["carrot", "turnip", "cabbage"]:
		Inventory.add_item(id, 1)
	_check(Crafting.craft("vegetable_soup"), "on cuisine une soupe")
	PlayerState.energy = 10
	PlayerState.heal(int(GameData.item("vegetable_soup").edible[0]), 0)
	_check(PlayerState.energy == 100, "la soupe redonne beaucoup d'énergie")
	# Forge : pioche et arrosoir
	Inventory.gold = 2000
	_check(Crafting.craft("steel_pickaxe"), "Gaston renforce la pioche")
	_check(Inventory.count_of("pickaxe") == 0 and Inventory.count_of("steel_pickaxe") == 1, "la pioche est remplacée dans la même case")
	Inventory.add_item("copper_ore", 5)
	_check(Crafting.craft("copper_can"), "Gaston forge l'arrosoir en cuivre")
	PlayerState.refill_water()
	_check(PlayerState.water == 60, "l'arrosoir en cuivre contient 60 doses")
	var row := [Vector2i(20, 14), Vector2i(21, 14), Vector2i(22, 14)]
	for c in row:
		FarmState.till(c)
		FarmState.tiles[c].watered = false
	farm.player.position = farm.cell_center(Vector2i(19, 14))
	farm.player.facing = Vector2i.RIGHT
	_select("copper_can")
	farm.act_on(row[0])
	_check(row.all(func(c: Vector2i) -> bool: return FarmState.is_watered(c)), "il arrose 3 cases d'un coup")
	# Pioche renforcée dans la mine : 2 dégâts par coup
	EventBus.map_change_requested.emit("mine:12", Vector2i.ZERO)
	# On attend que la mine soit vraiment chargée (machine chargée : parfois
	# plus de quelques images), au plus 3 secondes
	for i in 180:
		await get_tree().process_frame
		if _main.call("current_map") is MineLevel:
			break
	await get_tree().process_frame
	_main.get("_hud").close_modal()
	var mine: MineLevel = _main.call("current_map")
	var rocks: Dictionary = mine.get("_rock_data")
	var target: Vector2i = rocks.keys()[0]
	rocks[target].hp = 2
	_select("steel_pickaxe")
	mine.act_on(target)
	_check(not rocks.has(target), "la pioche renforcée casse un rocher dur en 1 coup")
	# Sauvegarde des objets posés
	FarmState.place_object(Vector2i(5, 20), "quality_sprinkler")
	SaveManager.save_game()
	FarmState.objects.clear()
	SaveManager.load_game()
	_check(FarmState.objects.get(Vector2i(5, 20)) == "quality_sprinkler", "les arroseurs sont sauvegardés")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _select(id: String) -> void:
	for i in Inventory.SIZE:
		if Inventory.slots[i] != null and Inventory.slots[i].id == id:
			Inventory.select(i)


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
