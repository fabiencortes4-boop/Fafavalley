extends Node
## Capture d'écran automatique d'une partie (pour vérifier le rendu).
##   xvfb-run godot --rendering-driver opengl3 res://tests/screenshot.tscn -- out.png

func _ready() -> void:
	var out := "user://screenshot.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	if "--title" not in args:
		Story.play_arrival = "--arrival" in args
		main.call("_start", false)
		if "--debris" not in args:
			FarmState.debris.clear()
			if main.call("current_map") is Farm:
				main.call("current_map").call("_refresh_all")
		_setup_demo()
		if "--notuto" in args:
			Tutorial.skip()
		for a in args:
			if a.begins_with("--zoom="):
				Settings.zoom = float(a.trim_prefix("--zoom="))
				Settings.changed.emit()
		if "--settings" in args:
			main.get("_hud").open_settings()
		for a in args:
			if a.begins_with("--day="):
				TimeManager.day = int(a.trim_prefix("--day="))
			if a.begins_with("--season="):
				TimeManager.season = int(a.trim_prefix("--season="))
			if a.begins_with("--time="):
				TimeManager.minutes = int(a.trim_prefix("--time=")) * 60
			if a.begins_with("--interior="):
				TimeManager.minutes = maxi(TimeManager.minutes, 10 * 60)
				var rows: Array = InteriorMap.LAYOUTS[a.trim_prefix("--interior=")].rows
				PlayerState.position = Vector2(String(rows[rows.size() - 1]).find("D") * 16 + 8, (rows.size() - 2) * 16 + 12)
				PlayerState.has_position = true
				main.call("_switch_to", "in:" + a.trim_prefix("--interior="))
				await get_tree().process_frame
		for a in args:
			if a.begins_with("--chapter="):
				# Histoire avancée jusqu'au chapitre donné (5 = fin, fête au village)
				for i in mini(int(a.trim_prefix("--chapter=")), Story.chapters.size()):
					PlayerState.flags["story_" + str(Story.chapters[i].id)] = true
					Story.chapter = i + 1
				Story.bump("harvest", 9)
		if "--shop" in args:
			EventBus.shop_requested.emit()
		if "--village" in args:
			if not " ".join(args).contains("--time="):
				TimeManager.minutes = 13 * 60 + 30
			PlayerState.position = Vector2(19 * 16 + 8, 17 * 16 + 12)
			PlayerState.has_position = true
			main.call("_switch_to", "village")
			await get_tree().process_frame
			if "--dialogue" in args:
				var v: Village = main.call("current_map")
				Relations.add_points("odette", 800)
				EventBus.dialogue_requested.emit("odette", str(GameData.npc("odette").dialogue.friend[0]))
		if "--ranch" in args or "--care" in args:
			for id in ["coop", "barn"]:
				Animals.buildings[id].built = true
			for t in ["chicken", "chicken", "bunny", "cow", "pig"]:
				Inventory.add_gold(5000)
				Animals.buy(t)
			Animals.buildings.coop.hay = 12
			Animals.animals[0].ready = true
			TimeManager.minutes = 10 * 60
			PlayerState.position = Vector2(31 * 16 + 8, 8 * 16 + 12)
			PlayerState.has_position = true
			main.call("_switch_to", "farm")
			await get_tree().process_frame
			if "--care" in args:
				main.get("_hud").open_animals("coop")
		if "--home" in args:
			PlayerState.position = Vector2(5 * 16 + 8, 4 * 16 + 12)
			PlayerState.has_position = true
			main.call("_switch_to", "home")
			await get_tree().process_frame
		for a in args:
			if a.begins_with("--hour="):
				TimeManager.minutes = int(a.trim_prefix("--hour=")) * 60
				TimeManager.time_changed.emit(TimeManager.minutes / 60, 0)
			if a.begins_with("--at="):
				var xy := a.trim_prefix("--at=").split(",")
				var m: WorldMap = main.call("current_map")
				m.player.position = m.cell_center(Vector2i(int(xy[0]), int(xy[1])))
			if a.begins_with("--shopid="):
				main.get("_hud").open_shop(a.trim_prefix("--shopid="))
		if "--pause" in args:
			main.get("_hud").open_pause_menu()
		for a in args:
			if a.begins_with("--text="):
				Settings.text_size = int(a.trim_prefix("--text="))
				Settings.changed.emit()
		if "--orchard" in args:
			var k := 0
			for t: String in FarmState.tree_data:
				for stage in 3:
					var c := Vector2i(20 + k * 3, 14 + stage * 2)
					FarmState.tiles.erase(c)
					if not FarmState.plant_tree(c, t):
						continue
					FarmState.trees[c].age = [0, 6, 12][stage]
					FarmState.trees[c].fruits = 3 if stage == 2 else 0
				k += 1
			main.call("current_map").call("_refresh_all")
			main.call("_switch_to", "farm")
			await get_tree().process_frame
		if "--greenhouse" in args:
			Animals.buildings.greenhouse.built = true
			var k := 0
			for crop: String in ["tomato", "pumpkin", "melon", "strawberry", "sunflower", "blueberry", "eggplant", "cauliflower"]:
				var c := Vector2i(4 + k % 6, 21 + (k / 6) * 2)
				FarmState.till(c)
				FarmState.plant(c, crop)
				FarmState.tiles[c].age = 30
				k += 1
			main.call("_switch_to", "farm")
			await get_tree().process_frame
		for a in args:
			if a.begins_with("--married="):
				Marriage.spouse = a.trim_prefix("--married=")
				TimeManager.minutes = 14 * 60
				main.call("_switch_to", "farm")
				await get_tree().process_frame
			if a.begins_with("--wedding="):
				Marriage.spouse = a.trim_prefix("--wedding=")
				Marriage.wedding_pending = true
		if "--garden" in args:
			# Potager de démonstration : toutes les cultures, mûres
			var k := 0
			for crop: String in GameData.crops:
				var cell := Vector2i(8 + (k % 8) * 2, 12 + (k / 8) * 2)
				FarmState.till(cell)
				FarmState.plant(cell, crop)
				var total := 0
				for d: Variant in GameData.crop(crop).stage_days:
					total += int(d)
				FarmState.tiles[cell].age = total
				FarmState.water(cell)
				k += 1
			main.call("current_map").call("_refresh_all")
		if "--neglect" in args:
			# Un champ planté puis oublié 6 nuits
			for x in range(12, 20):
				for y in range(15, 18):
					FarmState.till(Vector2i(x, y))
					if x % 2 == 0:
						FarmState.plant(Vector2i(x, y), "cabbage")
			for i in 6:
				FarmState.advance_day(0, false)
			main.call("_switch_to", "farm")
			await get_tree().process_frame
		if "--lit" in args:
			PlayerState.flags["story_port"] = true
		if "--port" in args:
			main.call("_switch_to", "port")
			await get_tree().process_frame
		if "--tavern" in args:
			TimeManager.minutes = 21 * 60
			main.call("_switch_to", "in:taverne")
			await get_tree().process_frame
		if "--forest" in args:
			main.call("_switch_to", "forest")
			await get_tree().process_frame
			for a in args:
				if a.begins_with("--fat="):
					var xy := a.trim_prefix("--fat=").split(",")
					var fm: WorldMap = main.call("current_map")
					fm.player.position = fm.cell_center(Vector2i(int(xy[0]), int(xy[1])))
		if "--board" in args:
			Quests.accept(0)
			main.get("_hud").open_board()
		if "--relations" in args:
			for id: String in GameData.npcs:
				Relations.met[id] = true
				Relations.add_points(id, randi_range(0, 1500))
			main.get("_hud").open_relations()
		for a in args:
			if a.begins_with("--heart="):
				var who := a.trim_prefix("--heart=")
				Relations.met[who] = true
				Relations.add_points(who, 600)
				EventBus.heart_scene_requested.emit(who, HeartEvents.pending(who))
		if "--journal" in args:
			main.get("_hud").open_story()
		if "--recipes" in args:
			main.get("_hud").open_crafting("craft")
		if "--bigmap" in args:
			var mm: Minimap = main.get("_hud").get("_minimap")
			mm.big = true
			mm.call("_layout")
		if "--fishing" in args:
			var farm: WorldMap = main.call("current_map")
			Inventory.add_item("fishing_rod", 1)
			Inventory.select(3)
			farm.player.position = farm.cell_center(Vector2i(25, 18))
			farm.player.facing = Vector2i.RIGHT
			farm.act_on(Vector2i(26, 18))
			farm.fishing.set("_timer", 100.0 if ("--bite" in args or "--line" in args or "--catch" in args) else 0.0)
			await get_tree().process_frame
			if "--bite" not in args and "--line" not in args:
				farm.fishing.on_action()
			if "--catch" in args:
				await get_tree().create_timer(0.8).timeout
				farm.fishing.call("_on_minigame_finished", true)
				await get_tree().create_timer(0.25).timeout
				Engine.time_scale = 0.03
		for a in args:
			if a.begins_with("--mine="):
				var lvl := int(a.trim_prefix("--mine="))
				Inventory.add_item("rusty_sword", 1)
				Inventory.select(3)
				main.call("_switch_to", "mine:%d" % lvl)
				await get_tree().process_frame
				var m: MineLevel = main.call("current_map")
				m.player.facing = Vector2i.RIGHT
				m.player.swing(GameData.item_icon("rusty_sword"), 2.0)
				main.get("_hud").close_modal()
				if "--fight" in args:
					# Un monstre juste devant : on le frappe pour voir les effets
					for mo in get_tree().get_nodes_in_group("monsters"):
						mo.queue_free()
					await get_tree().process_frame
					var foe := Monster.new()
					foe.kind = "cave_rat"
					foe.level = lvl
					foe.target = m.player
					foe.position = m.player.position + Vector2(16, 0)
					foe.add_to_group("monsters")
					m.get("_entities").add_child(foe)
					foe.set_physics_process(false)
					await get_tree().create_timer(0.5).timeout
					m.player.set("_swing_cooldown", 0.0)
					m.player.locked = false
					m.player.facing = Vector2i.RIGHT
					m.act_on(m.player_cell() + Vector2i.RIGHT)
					Engine.time_scale = 0.03  # ralenti : l'effet reste visible pour la capture
				if "--reveal" in args:
					# Escalier qui descend dégagé, joueur posté à côté
					var lad: Vector2i = m.get("_ladder_cell")
					m.get("_rock_data").erase(lad)
					m.call("_reveal_ladder", lad)
					for d: Vector2i in [Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(1, 1)]:
						if m.is_walkable(lad + d):
							m.player.position = m.cell_center(lad + d)
							break
		if "--craft" in args or "--forge" in args:
			for pair in [["copper_ore", 6], ["iron_ore", 3], ["slime", 2], ["coal", 3], ["carrot", 2], ["turnip", 1], ["cabbage", 1], ["pickaxe", 1]]:
				Inventory.add_item(pair[0], pair[1])
			FarmState.place_object(Vector2i(12, 13), "sprinkler")
			FarmState.place_object(Vector2i(18, 13), "quality_sprinkler")
			if "--forge" in args:
				EventBus.forge_requested.emit()
			else:
				EventBus.emit_signal("relations_changed")
				main.get("_hud").open_crafting("craft")
		if "--bag" in args or "--chest" in args or "--shop2" in args:
			Inventory.gold = 3000
			Inventory.set_capacity(24)
			for id in ["stone", "coal", "copper_ore", "iron_ore", "quartz", "slime", "carrot", "roach", "carp", "fishing_rod", "pickaxe", "rusty_sword", "amethyst"]:
				Inventory.add_item(id, 3)
			var hud: Hud = main.get("_hud")
			if "--bag" in args:
				hud.set("_picked", 13)
				hud.open_bag()
			elif "--chest" in args:
				FarmState.place_object(Vector2i(12, 13), "chest")
				FarmState.chests[Vector2i(12, 13)][0] = {"id": "gold_ore", "qty": 7}
				FarmState.chests[Vector2i(12, 13)][1] = {"id": "emerald", "qty": 1}
				hud.open_chest(Vector2i(12, 13))
			else:
				hud.open_shop()
		for a in args:
			if a.begins_with("--season="):
				TimeManager.season = int(a.trim_prefix("--season="))
				TimeManager.weather = "snow" if TimeManager.season == 3 else ("rain" if "--rain" in args else "sunny")
				TimeManager.day_started.emit(1, TimeManager.season, 1)
		if "--mail" in args:
			EventBus.mail_requested.emit()
		if "--skills" in args:
			Skills.add_xp("farming", 420)
			Skills.add_xp("mining", 120)
			Skills.add_xp("fishing", 40)
			main.get("_hud").open_skills()
		if "--summary" in args:
			FarmState.ship("carrot", 6)
			GameFlow.end_day(false)
	for a in args:
		if a.begins_with("--fat=") and not "--forest" in args:
			var xy := a.trim_prefix("--fat=").split(",")
			var fm: WorldMap = main.call("current_map")
			fm.player.position = fm.cell_center(Vector2i(int(xy[0]), int(xy[1])))
	# Capture fidèle : sans anticrénelage (sinon l'image lue peut dater)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	var delay := 1.0
	for a in args:
		if a.begins_with("--delay="):
			delay = float(a.trim_prefix("--delay="))
	if Engine.time_scale < 1.0:
		delay *= Engine.time_scale  # le minuteur suit le ralenti
	for a in args:
		if a.begins_with("--act="):
			delay = await _act(main, a.trim_prefix("--act="), args)
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	if "--debug" in args:
		var pl: Node2D = main.call("current_map").player
		for n in pl.find_children("*", "Node2D", true, false):
			print("DBG ", n.name, " ", n.get_class(), " rot=%.2f grot=%.2f vis=%s" % [n.rotation, n.global_rotation, n.visible], " tex=", (n.texture.resource_path if n is Sprite2D and n.texture else ""))
	get_viewport().get_texture().get_image().save_png(out)
	print("Capture : ", out)
	get_tree().quit()


## Prépare une ferme « de démo » pour la capture.
func _setup_demo() -> void:
	var crops := ["carrot", "turnip", "cabbage"]
	for x in range(9, 16):
		for y in range(12, 15):
			var cell := Vector2i(x, y)
			FarmState.till(cell)
			if x < 15:
				FarmState.plant(cell, crops[y % crops.size()])
				FarmState.tiles[cell].age = x - 9
			if y == 13:
				FarmState.water(cell)
	FarmState.till(Vector2i(18, 13))


## Déclenche une action d'outil pour photographier le geste en cours.
func _act(main: Node, tool: String, args: Array) -> float:
	var farm: WorldMap = main.call("current_map")
	await get_tree().create_timer(0.6).timeout
	var cell := farm.player_cell() + Vector2i(1, 2)
	farm.player.position = farm.cell_center(cell + Vector2i.LEFT)
	farm.player.facing = Vector2i.RIGHT
	await get_tree().create_timer(0.3).timeout
	match tool:
		"water":
			FarmState.till(cell)
		"axe":
			FarmState.debris[cell] = {"type": "stump", "hp": 5}
			farm.call("_refresh_cell", cell)
		"harvest":
			FarmState.till(cell)
			FarmState.plant(cell, "carrot")
			FarmState.tiles[cell].age = 10
			farm.call("_refresh_cell", cell)
	var item: String = {"hoe": "hoe", "water": "watering_can", "axe": "axe", "harvest": "hoe"}[tool]
	if Inventory.count_of(item) == 0:
		Inventory.add_item(item, 1)
	for i in Inventory.HOTBAR:
		if Inventory.slots[i] != null and Inventory.slots[i].id == item:
			Inventory.select(i)
	farm.act_on(cell)
	var delay := 0.13
	for a in args:
		if a.begins_with("--delay="):
			delay = float(a.trim_prefix("--delay="))
	return delay
