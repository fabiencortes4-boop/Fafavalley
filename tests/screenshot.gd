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
		main.call("_start", false)
		if "--debris" not in args:
			FarmState.debris.clear()
			main.call("current_map").call("_refresh_all")
		_setup_demo()
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
			farm.fishing.set("_timer", 100.0 if "--bite" in args else 0.0)
			await get_tree().process_frame
			if "--bite" not in args:
				farm.fishing.on_action()
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
	var delay := 1.0
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
