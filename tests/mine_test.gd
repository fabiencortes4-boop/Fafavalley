extends Node
## Test automatique de la mine : kit de Firmin, niveaux générés, rochers,
## échelle, combat, butin, ascenseur, évanouissement, manger.
##   godot --headless res://tests/mine_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var hud: Hud = _main.get("_hud")
	await _go("village", Vector2i(36, 5))
	var village: Village = _main.call("current_map")
	village.player.facing = Vector2i.UP
	village.act_on(Vector2i(36, 4))
	_check(Inventory.count_of("pickaxe") == 1 and Inventory.count_of("rusty_sword") == 1, "le coffre de Firmin donne pioche et épée")
	hud.close_modal()
	village.act_on(Vector2i(36, 4))
	await _frames(3)
	var mine: MineLevel = _main.call("current_map")
	_check(mine is MineLevel and mine.level == 1, "la porte mène au niveau 1")
	_check(hud.get("_location_label").text == "Mine - niveau 1", "le HUD affiche le lieu")
	var rock_data: Dictionary = mine.get("_rock_data")
	_check(rock_data.size() > 10, "le niveau contient des rochers (%d)" % rock_data.size())
	_check(get_tree().get_nodes_in_group("monsters").size() >= 2, "le niveau contient des monstres")
	_check(mine.is_walkable(mine.player_cell()), "on arrive sur une case libre")
	# Pioche : casser le rocher de l'échelle
	_select("pickaxe")
	var ladder: Vector2i = mine.get("_ladder_cell")
	var energy_before := PlayerState.energy
	for i in 5:
		if rock_data.has(ladder):
			mine.act_on(ladder)
	_check(not rock_data.has(ladder), "la pioche casse le rocher")
	_check(PlayerState.energy < energy_before, "piocher fatigue")
	_check(mine.get("_ladder_found"), "l'échelle apparaît sous le rocher")
	await _frames(40)  # laisser les objets tomber puis être attirés
	mine.player.position = mine.cell_center(ladder)
	await get_tree().create_timer(1.0).timeout
	_check(Inventory.count_of("stone") + Inventory.count_of("coal") + Inventory.count_of("copper_ore") + Inventory.count_of("quartz") > 0, "les débris sont ramassés")
	mine.act_on(ladder)
	await _frames(3)
	mine = _main.call("current_map")
	_check(mine.level == 2, "l'échelle mène au niveau 2")
	# Même jour, même niveau : génération reproductible
	var a: Array = mine.call("_map_rows").duplicate()
	var again := MineLevel.new()
	again.setup(2)
	_check(again.call("_map_rows") == a, "un niveau garde sa forme pour la journée")
	again.free()
	# Combat
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	await _frames(2)
	var slime := Monster.new()
	slime.kind = "slime"
	slime.level = 2
	slime.target = mine.player
	mine.player.facing = Vector2i.RIGHT
	slime.position = mine.player.position + Vector2(14, 0)
	slime.add_to_group("monsters")
	mine.get("_entities").add_child(slime)
	slime.set_physics_process(false)
	_select("rusty_sword")
	var hp := slime.hp
	mine.act_on(mine.player_cell() + Vector2i.RIGHT)
	_check(slime.hp < hp, "l'épée blesse le monstre")
	for i in 10:
		await get_tree().create_timer(0.45).timeout
		if not is_instance_valid(slime) or slime.hp <= 0:
			break
		mine.act_on(mine.player_cell() + Vector2i.RIGHT)
	_check(not is_instance_valid(slime) or slime.hp <= 0, "le monstre est vaincu")
	# Dégâts reçus
	var health := PlayerState.health
	mine.player.take_damage(10, mine.player.position + Vector2(10, 0))
	_check(PlayerState.health == health - 10, "les monstres font perdre de la vie")
	mine.player.take_damage(10, mine.player.position)
	_check(PlayerState.health == health - 10, "invulnérable juste après un coup")
	# Manger
	Inventory.add_item("carrot", 1)
	_select("carrot")
	var opened := [""]
	EventBus.eat_requested.connect(func(id: String) -> void: opened[0] = id)
	mine.act_on(mine.player_cell() + Vector2i.LEFT)
	_check(opened[0] == "carrot", "avec un légume en main, on propose de le manger")
	hud.close_modal()
	# Évanouissement
	PlayerState.flags["mine_deepest"] = 12
	var gold := Inventory.gold
	await get_tree().create_timer(1.1).timeout
	mine.player.take_damage(999, mine.player.position)
	await _frames(3)
	_check(_main.call("current_map") is Village, "évanoui·e : on se réveille au village")
	_check(Inventory.gold < gold and PlayerState.health > 0, "les soins coûtent de l'or et rendent de la vie")
	hud.close_modal()
	# Ascenseur
	var levels := [[]]
	EventBus.elevator_requested.connect(func(l: Array) -> void: levels[0] = l)
	(_main.call("current_map") as Village).act_on(Vector2i(36, 4))
	_check(levels[0] == [1, 5, 10], "l'ascenseur propose les paliers atteints (%s)" % [levels[0]])
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _go(map_id: String, cell: Vector2i) -> void:
	EventBus.map_change_requested.emit(map_id, cell)
	await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _select(id: String) -> void:
	for i in Inventory.SIZE:
		if Inventory.slots[i] != null and Inventory.slots[i].id == id:
			Inventory.select(i)


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
