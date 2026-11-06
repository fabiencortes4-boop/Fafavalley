extends Node
## Simulation d'équilibrage du combat : un robot nettoie des niveaux de la
## mine avec l'arme disponible à cette profondeur.
##   godot --headless --fixed-fps 60 res://tests/combat_balance.tscn

const LEVELS := [1, 5, 10, 15, 20, 25, 30]
const RUNS := 4
const MAX_TIME := 90.0

var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	for level: int in LEVELS:
		var weapon := "rusty_sword" if level < 10 else ("iron_sword" if level < 20 else "war_axe")
		var hp_lost := 0.0
		var kills := 0
		var total := 0
		var time := 0.0
		var deaths := 0
		for run in RUNS:
			TimeManager.day = run + 1
			PlayerState.health = PlayerState.MAX_HEALTH
			PlayerState.energy = PlayerState.MAX_ENERGY
			Inventory.reset()
			Inventory.add_item(weapon, 1)
			Inventory.select(0)
			_main.call("_switch_to", "mine:%d" % level)
			await get_tree().process_frame
			_main.get("_hud").close_modal()
			var mine: MineLevel = _main.call("current_map")
			var start_count := get_tree().get_nodes_in_group("monsters").size()
			for m in get_tree().get_nodes_in_group("monsters"):
				m.position = Vector2(-1000, -1000)  # en attente hors de la carte
			total += start_count
			var result: Array = await _fight(mine)
			time += result[0]
			kills += start_count - get_tree().get_nodes_in_group("monsters").size()
			hp_lost += PlayerState.MAX_HEALTH - PlayerState.health if PlayerState.health > 0 else PlayerState.MAX_HEALTH
			if result[1]:
				deaths += 1
		print("niveau %2d (%s) : %4.1f/%4.1f monstres vaincus, %3d PV perdus, %4.1f s, %d mort(s) / %d" % [
			level, weapon, kills / float(RUNS), total / float(RUNS), int(hp_lost / RUNS), time / RUNS, deaths, RUNS])
	get_tree().quit()


func _fight(mine: MineLevel) -> Array:
	var t := 0.0
	var stuck := 0.0
	var last := mine.player.position
	var detour := Vector2.ZERO
	var died := [false]
	var on_faint := func() -> void: died[0] = true
	EventBus.player_fainted.connect(on_faint)
	# Les monstres arrivent par groupes de 2, près du joueur (pire cas réaliste).
	var waiting: Array = get_tree().get_nodes_in_group("monsters").duplicate()
	var free_cells: Array[Vector2i] = []
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var c := mine.player_cell() + Vector2i(dx, dy)
			if absi(dx) + absi(dy) >= 3 and mine.is_walkable(c) and not mine.get("_rock_data").has(c):
				free_cells.append(c)
	while t < MAX_TIME and not died[0]:
		var monsters := get_tree().get_nodes_in_group("monsters").filter(func(m: Node) -> bool: return is_instance_valid(m) and m.hp > 0 and not m in waiting)
		if monsters.is_empty():
			if waiting.is_empty():
				break
			for k in 2:
				if not waiting.is_empty() and not free_cells.is_empty():
					var m: Monster = waiting.pop_back()
					if is_instance_valid(m):
						m.position = mine.cell_center(free_cells[randi() % free_cells.size()])
			continue
		monsters.sort_custom(func(a: Node, b: Node) -> bool: return a.position.distance_to(mine.player.position) < b.position.distance_to(mine.player.position))
		var target: Monster = monsters[0]
		var to := target.position - mine.player.position
		var dir := to.normalized()
		if to.length() < 18.0:
			mine.player.face_towards(Vector2i(roundi(dir.x), roundi(dir.y)) if absf(dir.x) < 0.5 or absf(dir.y) < 0.5 else Vector2i(signi(int(dir.x * 10)), 0))
			_press(Vector2.ZERO)
			mine.call("_swing", Inventory.get_selected().id)
		else:
			if detour != Vector2.ZERO:
				dir = detour
			_press(dir)
		await get_tree().physics_frame
		t += 1.0 / 60.0
		# Coincé contre un rocher : petit détour
		stuck += 1.0 / 60.0
		if stuck > 0.6:
			detour = Vector2.ZERO if mine.player.position.distance_to(last) > 8.0 else Vector2.RIGHT.rotated(randf() * TAU)
			last = mine.player.position
			stuck = 0.0
	_press(Vector2.ZERO)
	EventBus.player_fainted.disconnect(on_faint)
	return [t, died[0]]


func _press(dir: Vector2) -> void:
	for pair in [["move_left", -dir.x], ["move_right", dir.x], ["move_up", -dir.y], ["move_down", dir.y]]:
		if pair[1] > 0.05:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])
