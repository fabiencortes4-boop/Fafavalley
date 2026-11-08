extends Node
## Test automatique : machines de transformation (qualité conservée), plats
## de qualité, concours de la fête, appâts, casiers, sortie en mer et
## poissons légendaires.
##   godot --headless res://tests/crafts_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var farm: Farm = _main.call("current_map")
	# ---- Produits artisanaux
	var jam := GameData.item("jam:melon")
	_check(str(jam.name) == "Confiture de melon" and int(jam.sell) == int(round(GameData.item("melon").sell * 1.6 + 30)), "« Confiture de melon » vaut 1,6 x le melon + 30 (%d or)" % int(jam.sell))
	_check(str(GameData.item("jam:orange").name) == "Confiture d'orange", "élision : confiture d'orange")
	_check(int(GameData.item("jam:melon@2").sell) == int(round(int(jam.sell) * 1.5)), "la qualité s'applique au produit")
	_check(Machines.category("melon@1") == "fruit" and Machines.category("carrot") == "vegetable" and Machines.category("sardine") == "fish", "fruits, légumes, poissons reconnus")
	# ---- Poser un bocal, y mettre un melon or, attendre 2 nuits
	var cell := Vector2i(30, 12)
	FarmState.place_object(cell, "preserves_jar")
	Inventory.add_item("melon@2", 1)
	for i in Inventory.SIZE:
		if Inventory.slots[i] != null and Inventory.slots[i].id == "melon@2":
			Inventory.select(i)
	farm.player.position = farm.cell_center(cell + Vector2i.DOWN)
	await get_tree().physics_frame
	_check(farm.action_hint(cell) == "Déposer", "le bouton Action propose de déposer")
	farm.act_on(cell)
	_check(Machines.busy(cell) and Inventory.count_of("melon") == 0, "le melon est dans le bocal")
	_check(Machines.recipe("smoker", "melon").is_empty(), "le fumoir refuse les fruits")
	Machines.new_day()
	_check(Machines.busy(cell), "après une nuit, pas encore prêt")
	Machines.new_day()
	Machines.new_day()
	_check(Machines.ready(cell) and farm.action_hint(cell) == "Récupérer", "après trois nuits : prêt à récupérer")
	farm.act_on(cell)
	_check(Inventory.count_of("jam:melon@2") == 1, "on récupère une confiture de melon ★ or")
	# ---- Presse à fromage : lait -> fromage, en gardant la qualité
	_check(Machines.recipe("cheese_press", "milk@1") == ["cheese@1", 3], "lait argent -> fromage argent (3 nuits)")
	_check(Machines.recipe("cask", "cheese@1") == ["cheese@2", 7], "le tonneau fait vieillir le fromage : argent -> or en 7 jours")
	_check(Machines.recipe("cask", "jam:melon@3").is_empty() and Machines.recipe("cask", "carrot").is_empty(), "pas au-delà du cristal, ni pour les légumes crus")
	FarmState.place_object(Vector2i(32, 12), "beehive")
	Machines.start_auto(Vector2i(32, 12), "beehive")
	_check(Machines.busy(Vector2i(32, 12)) and GameData.base_id(str(Machines.state[Vector2i(32, 12)].output)) == "honey", "la ruche produit du miel toute seule")
	# ---- Cuisine : le plat prend la qualité de ses ingrédients
	Inventory.add_item("egg@2", 2)
	PlayerState.flags["story_ch2"] = true
	if Crafting.recipes.has("omelette"):
		var ing: Dictionary = Crafting.recipes.omelette.ingredients
		for k: String in ing:
			if k != "egg":
				Inventory.add_item(GameData.with_quality(k, 2) if GameData.has_quality(k) else k, int(ing[k]))
		Crafting.craft("omelette")
		_check(Inventory.count_of("omelette@2") == 1, "une omelette ★ or avec des œufs or")
	# ---- Concours : la qualité compte
	_check(Events.contest_score("pumpkin@3") > Events.contest_score("pumpkin") + 10, "le jury préfère une citrouille cristal (%d contre %d)" % [Events.contest_score("pumpkin@3"), Events.contest_score("pumpkin")])
	_check(Events.rivals().size() == 3 and Events.rivals() == Events.rivals(), "trois concurrents, les mêmes toute la journée")
	# ---- Appâts
	Inventory.add_item("fishing_rod", 1)
	Inventory.add_item("bait", 3)
	for i in Inventory.SIZE:
		if Inventory.slots[i] != null and Inventory.slots[i].id == "fishing_rod":
			Inventory.select(i)
	farm.player.position = farm.cell_center(Vector2i(31, 15))
	farm.player.face_towards(Vector2i.RIGHT)
	await get_tree().physics_frame
	var cast := false
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		farm.player.face_towards(d)
		if farm.fishing.try_cast(0) and farm.fishing.busy():
			cast = true
			break
	if cast:
		_check(Inventory.count_of("bait") == 2, "un appât est utilisé au lancer")
	# ---- Casiers
	_main.call("_switch_to", "port")
	await _frames(3)
	var port: PortMap = _main.call("current_map")
	var water := Vector2i(30, 20)
	_check(port.is_water(water), "de l'eau au port")
	Inventory.add_item("crab_pot", 1)
	for i in Inventory.SIZE:
		if Inventory.slots[i] != null and Inventory.slots[i].id == "crab_pot":
			Inventory.select(i)
	port.player.position = port.cell_center(water + Vector2i.LEFT)
	await get_tree().physics_frame
	port.act_on(water)
	_check(Machines.has_pot("port", water), "on pose un casier dans l'eau")
	Machines.new_day()
	var got := Machines.pot_catch("port", water)
	_check(GameData.base_id(got) in ["crab", "shrimp", "mussel", "oyster"], "la nuit, il attrape un fruit de mer (%s)" % got)
	port.act_on(water)
	_check(Inventory.count_of(GameData.base_id(got)) >= 1 and Machines.pot_catch("port", water) == "", "on vide le casier")
	# ---- Sortie en mer
	_check(port.get("_interactables").get(PortMap.BOAT_CELLS[0]) == "boat", "la barque de Basile au bout de la jetée")
	_main.call("_switch_to", "sea")
	await _frames(3)
	var sea: WorldMap = _main.call("current_map")
	_check(sea is SeaMap and sea.is_walkable(sea.player_cell()), "au large, sur le pont de la barque")
	var deep := {}
	TimeManager.season = 1
	TimeManager.minutes = 11 * 60
	TimeManager.weather = "sunny"
	for i in 300:
		deep[GameData.pick_fish("sea")] = true
	_check(deep.has("tuna") and not GameData.fish("tuna").places.has("port"), "le thon ne se pêche qu'au large")
	# ---- Poissons légendaires : un seul, et il faut être bon pêcheur
	_check(not deep.has("blue_shark"), "pas de requin légendaire pour un débutant")
	Skills.xp["fishing"] = 99999
	var seen := false
	for i in 400:
		if GameData.pick_fish("sea") == "blue_shark":
			seen = true
	_check(seen, "un pêcheur expert peut croiser le Grand requin bleu")
	FishLog.record("blue_shark", 300)
	var again := false
	for i in 400:
		if GameData.pick_fish("sea") == "blue_shark":
			again = true
	_check(not again, "un légendaire ne se pêche qu'une fois")
	# ---- Sauvegarde
	SaveManager.save_game()
	Machines.reset()
	SaveManager.load_game()
	_check(Machines.pots.size() == 1 and Machines.is_machine("preserves_jar"), "casiers et machines se rechargent")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
