extends Node
## Banc d'essai des performances : charge un lieu, attend, puis mesure
## sur 120 images les appels de dessin, objets, primitives et temps CPU.
##   xvfb-run godot --rendering-driver opengl3 res://tools/benchmark.tscn -- village 21

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var place := args[0] if args.size() > 0 else "village"
	var hour := int(args[1]) if args.size() > 1 else 12
	if args.size() > 2:
		Settings.quality = int(args[2])
		Settings.apply_quality()
		Engine.max_fps = 0  # mesure sans limite
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	Story.play_arrival = false
	main.call("_start", false)
	Tutorial.skip()
	TimeManager.minutes = hour * 60
	if place != "farm":
		main.call("_switch_to", place)
	await get_tree().create_timer(2.0).timeout
	var draws := 0.0
	var objects := 0.0
	var prims := 0.0
	var process := 0.0
	var frames := 120
	var t0 := Time.get_ticks_usec()
	for i in frames:
		await RenderingServer.frame_post_draw
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		process += Performance.get_monitor(Performance.TIME_PROCESS)
	var wall := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	print("BENCH %s %dh : appels %.0f, objets %.0f, primitives %.0fk, process %.2f ms, image %.1f ms, nœuds %d" % [
		place, hour, draws / frames, objects / frames, prims / frames / 1000.0, process / frames * 1000.0, wall,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	get_tree().quit()
