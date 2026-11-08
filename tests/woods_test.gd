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
