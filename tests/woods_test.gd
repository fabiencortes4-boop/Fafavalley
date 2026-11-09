extends Node
## Test automatique des arbres à bois de la forêt : abattage, souche,
## graines, replantation, pousse, rejet des souches, sauvegarde.
##   godot --headless res://tests/woods_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	Tutorial.skip()
	_main.call("_switch_to", "forest")
	await get_tree().process_frame
	await get_tree().process_frame
	var forest: ForestMap = _main.call("current_map")
	_check(forest is ForestMap, "on est dans la forêt")
	var spots := ForestMap.lumber_spots()
	_check(spots.size() >= 20 and Woods.trees.size() == spots.size(), "la clairière est plantée (%d arbres)" % Woods.trees.size())
	var kinds := {}
	for s: Array in spots:
		kinds[s[1]] = true
	_check(kinds.has("pine") and kinds.has("plane") and kinds.has("oak"), "pins, platanes et chênes")
	var pine := Vector2i(-1, -1)
	for s: Array in spots:
		if s[1] == "pine":
			pine = s[0]
			break
	_check(Woods.stage(pine) == 3 and not forest.is_walkable(pine), "un pin adulte bloque le passage")
	# Abattage : plusieurs coups de hache
	var drops: Array = []
	var hits := 0
	while hits < 40:
		hits += 1
		var r := Woods.chop(pine, 1, pine + Vector2i.DOWN)
		drops.append_array(r.drops)
		if r.done:
			break
	_check(hits == int(Woods.TYPES.pine.hp), "le pin tombe en %d coups de hache simple" % hits)
	_check(drops.count("wood") >= 10 and drops.count("pine_cone") >= 1, "un pin donne beaucoup de bois (%d) et des pommes de pin" % drops.count("wood"))
	_check(Woods.is_stump(pine) and not forest.is_walkable(pine), "il reste une souche")
	drops.clear()
	for i in Woods.STUMP_HP:
		drops.append_array(Woods.chop(pine, 1, pine + Vector2i.DOWN).drops)
	_check(not Woods.trees.has(pine) and drops.count("wood") >= 3, "la souche s'arrache et donne encore du bois")
	await get_tree().process_frame
	_check(forest.is_walkable(pine), "la case est libre")
	# Un chêne donne du bois dur
	var oak: Vector2i = spots.filter(func(s: Array) -> bool: return s[1] == "oak")[0][0]
	drops.clear()
	for i in 40:
		var r2 := Woods.chop(oak, 3, oak + Vector2i.DOWN)
		drops.append_array(r2.drops)
		if r2.done:
			break
	_check(drops.count("hardwood") >= 2 and drops.count("acorn") >= 1, "un chêne donne du bois dur et des glands")
	_check(Woods.is_stump(oak), "le chêne a laissé une souche")
	# Replanter une pomme de pin
	forest.player.position = forest.cell_center(pine + Vector2i.DOWN)
	Inventory.add_item("pine_cone", 1)
	Inventory.select(_slot_of(func(id: String) -> bool: return id == "pine_cone"))
	_check(forest.action_hint(pine) == "Planter", "indice « Planter » sur l'herbe libre")
	forest.act_on(pine)
	await get_tree().process_frame
	_check(Woods.trees.has(pine) and Woods.stage(pine) == 0 and Inventory.count_of("pine_cone") == 0, "la pomme de pin est plantée")
	_check(not forest.is_walkable(pine), "la pousse occupe la case")
	for d in int(Woods.TYPES.pine.grow):
		Woods.new_day()
	_check(Woods.stage(pine) == 3, "le pin replanté est adulte en %d jours" % int(Woods.TYPES.pine.grow))
	# Une souche oubliée rejette (les jours de pousse du pin ont déjà passé)
	_check(Woods.trees.has(oak) and not Woods.is_stump(oak), "la souche oubliée a rejeté")
	# Sauvegarde
	var saved := Woods.to_dict()
	var count := Woods.trees.size()
	Woods.reset()
	Woods.from_dict(saved)
	_check(Woods.trees.size() == count and Woods.seeded and Woods.stage(pine) == 3, "les arbres sont sauvegardés")
	# Indice de hache et coupe par le joueur
	Inventory.add_item("axe", 1)
	var axe_slot := _slot_of(func(id: String) -> bool: return GameData.item(id).get("tool") == "axe")
	Inventory.select(axe_slot)
	_check(forest.action_hint(pine) == "Couper", "indice « Couper » avec la hache")
	var energy := PlayerState.energy
	forest.act_on(pine)
	await get_tree().create_timer(0.6).timeout
	_check(PlayerState.energy < energy and int(Woods.trees[pine].hp) < int(Woods.TYPES.pine.hp), "un coup de hache du joueur entame l'arbre")
	# Le bois dur dans les recettes
	var uses := []
	for rid: String in Crafting.recipes:
		if Crafting.recipes[rid].get("ingredients", {}).has("hardwood"):
			uses.append(rid)
	_check(uses.size() >= 5, "le bois dur sert dans %d recettes" % uses.size())
	Inventory.add_item("hardwood", 30)
	Inventory.add_item("wood", 60)
	Inventory.add_item("iron_ore", 17)
	Inventory.add_item("fiber", 10)
	_check(Crafting.craft("oak_cask") and Inventory.count_of("oak_cask") == 1, "fabriquer un fût de chêne")
	_check(Machines.recipe("oak_cask", "cheese") == [GameData.with_quality("cheese", 1), 4], "le fût fait vieillir en 4 nuits (tonneau : 7)")
	_check(Crafting.craft("oak_armchair") and Crafting.craft("oak_wardrobe"), "fabriquer un fauteuil et une armoire")
	PlayerState.flags["story_ch3"] = true
	Inventory.add_gold(500)
	var had_axe := Inventory.count_of("axe")
	_check(Crafting.missing("steel_axe").is_empty(), "la hache renforcée : 12 minerais de fer, 5 bois dur, 500 or")
	_check(Crafting.craft("steel_axe") and Inventory.count_of("steel_axe") == 1 and Inventory.count_of("axe") == had_axe - 1, "la hache renforcée remplace la hache")
	# ---- À la ferme : arbres à bois, clôtures et chemins
	_main.call("_switch_to", "farm")
	await get_tree().process_frame
	await get_tree().process_frame
	var farm: Farm = _main.call("current_map")
	FarmState.debris.clear()
	var spot := Vector2i(20, 14)
	farm.player.position = farm.cell_center(spot + Vector2i.DOWN)
	Inventory.add_item("acorn", 1)
	Inventory.select(_slot_of(func(id: String) -> bool: return id == "acorn"))
	farm.act_on(spot)
	await get_tree().create_timer(0.6).timeout
	_check(FarmState.objects.get(spot) == "wood_tree" and Woods.farm.has(spot) and not farm.is_walkable(spot), "un gland se plante à la ferme")
	for d in int(Woods.TYPES.oak.grow):
		Woods.new_day()
	_check(Woods.stage(spot, "farm") == 3, "le chêne de la ferme pousse")
	var got: Array = []
	for i in 40:
		var r3 := Woods.chop(spot, 3, spot + Vector2i.DOWN, "farm")
		got.append_array(r3.drops)
		if r3.done and not Woods.farm.has(spot):
			break
	_check(got.count("wood") >= 15 and got.count("hardwood") >= 2, "abattu puis dessouché à la ferme : bois et bois dur")
	FarmState.remove_object(spot)
	_check(farm.is_walkable(spot), "la case de la ferme est libre")
	Inventory.add_item("stone", 3)
	Inventory.add_item("wood", 5)
	_check(Crafting.craft("fence") and Inventory.count_of("fence") == 2, "fabriquer des clôtures (par 2)")
	_check(Crafting.craft("path_stone") and Inventory.count_of("path_stone") == 4, "fabriquer des pavés (par 4)")
	FarmState.place_object(spot, "path_stone")
	await get_tree().process_frame
	_check(farm.is_walkable(spot), "on marche sur le chemin")
	# Clôture posée sur le bord entre le joueur et la case visée (pas au milieu)
	farm.player.position = farm.cell_center(spot)
	Inventory.select(_slot_of(func(id: String) -> bool: return id == "fence"))
	farm.act_on(spot + Vector2i.RIGHT)
	await get_tree().create_timer(0.6).timeout
	_check(FarmState.fences.has("v:%d,%d" % [spot.x + 1, spot.y]) and farm.is_walkable(spot + Vector2i.RIGHT), "la clôture se pose sur le bord de la case, la case reste libre")
	# Le joueur ne la traverse pas
	farm.player.position = farm.cell_center(spot)
	for i in 40:
		farm.player.velocity = Vector2(80, 0)
		farm.player.move_and_slide()
	_check(farm.player.position.x < (spot.x + 1) * 16, "on ne traverse pas la clôture (x = %.1f)" % farm.player.position.x)
	var saved_fences := FarmState.to_dict()
	FarmState.from_dict(saved_fences)
	_check(FarmState.fences.size() == 1, "les clôtures sont sauvegardées")
	_check(Animals.data.buildings.barn.materials.has("hardwood"), "l'étable demande du bois dur")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _slot_of(test: Callable) -> int:
	for i in Inventory.slots.size():
		var s: Variant = Inventory.slots[i]
		if s != null and test.call(str(s.id)):
			return i
	return -1


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  ÉCHEC ") + label)
	if not ok:
		_failures += 1
