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
		_setup_demo()
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
		if "--summary" in args:
			FarmState.ship("carrot", 6)
			GameFlow.end_day(false)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
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
