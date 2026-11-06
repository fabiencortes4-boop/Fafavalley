extends SceneTree
## Simulation d'équilibrage : un « joueur » avec 0,2 s de réaction joue
## 40 parties par poisson. godot --headless -s res://tests/fishing_balance.gd

func _initialize() -> void:
	var fishes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fish.json"))
	for id: String in fishes:
		var wins := 0
		var total_time := 0.0
		for run in 40:
			var game: FishingMinigame = load("res://scripts/ui/fishing_minigame.gd").new()
			game.difficulty = float(fishes[id].difficulty) / 100.0
			game.behavior = fishes[id].behavior
			game._ready()
			var t := 0.0
			var delayed: Array = []
			var result := [null]
			game.finished.connect(func(ok: bool) -> void: result[0] = ok)
			while result[0] == null and t < 60.0:
				var dt := 1.0 / 60.0
				# Le joueur voit l'état avec 0,2 s de retard.
				var center: float = game._net_pos + game._net_width / 2.0
				delayed.append(game._fish_pos > center - game._net_vel * 0.25)
				var hold: bool = delayed[0] if delayed.size() > 12 else false
				if delayed.size() > 12:
					delayed.pop_front()
				game._touches = {0: true} if hold else {}
				game._process(dt)
				t += dt
			if result[0]:
				wins += 1
			total_time += t
			game.free()
		print("%-12s difficulté %3d : %2d/40 réussies, %.1f s en moyenne" % [id, fishes[id].difficulty, wins, total_time / 40.0])
	quit()
