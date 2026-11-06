extends Node
## Test automatique de la pêche : achat de la canne, lancer, touche,
## mini-jeu gagné et perdu, carnet de pêche, cadeau d'un poisson.
##   godot --headless res://tests/fishing_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var farm: WorldMap = _main.call("current_map")
	# Ferme sans débris aléatoires : tests reproductibles
	FarmState.debris.clear()
	farm.call("_refresh_all")
	var hud: Hud = _main.get("_hud")
	# Acheter la canne à l'épicerie
	var gold := Inventory.gold
	hud.call("_buy", "fishing_rod")
	hud.close_modal()
	_check(Inventory.count_of("fishing_rod") == 1, "on achète une canne à pêche")
	_check(Inventory.gold == gold - 250, "elle coûte 250 or")
	for i in Inventory.SIZE:
		if Inventory.slots[i] != null and Inventory.slots[i].id == "fishing_rod":
			Inventory.select(i)
	# Pas d'eau devant : pas de lancer
	farm.act_on(farm.player_cell() + Vector2i.DOWN)
	_check(not farm.fishing.busy(), "pas de lancer loin de l'eau")
	# Au bord de l'étang (eau à l'est)
	farm.player.position = farm.cell_center(Vector2i(25, 18))
	farm.player.facing = Vector2i.RIGHT
	farm.act_on(Vector2i(26, 18))
	_check(farm.fishing.state == Fishing.State.WAITING, "on lance la ligne face à l'eau")
	_check(farm.player.locked, "le joueur ne bouge plus pendant la pêche")
	# Ferrer trop tôt
	farm.act_on(Vector2i(26, 18))
	_check(not farm.fishing.busy(), "ferrer trop tôt fait rater")
	# Touche puis mini-jeu gagné
	var fish_before := _fish_count()
	await _cast_and_hook(farm)
	var game: FishingMinigame = _find_minigame(hud)
	_check(game != null, "la touche ouvre le mini-jeu")
	game.progress = 0.995
	_hold(true)
	for i in 30:
		await get_tree().process_frame
		if not is_instance_valid(game) or game.progress >= 1.0:
			break
	_hold(false)
	await get_tree().process_frame
	_check(_fish_count() == fish_before + 1, "le poisson arrive dans l'inventaire")
	_check(FishLog.caught.size() == 1, "il est noté dans le carnet de pêche")
	_check(not farm.player.locked, "on peut rebouger après la prise")
	# Mini-jeu perdu
	await _cast_and_hook(farm)
	game = _find_minigame(hud)
	game.progress = 0.001
	game.set("_fish_pos", 0.99)
	game.set("_net_pos", 0.0)
	for i in 30:
		await get_tree().process_frame
		if not is_instance_valid(game):
			break
	await get_tree().process_frame
	_check(_fish_count() == fish_before + 1, "un poisson perdu ne compte pas")
	_check(not get_tree().paused, "le jeu reprend après le mini-jeu")
	# Laisser filer la touche
	farm.fishing.try_cast(0)
	farm.fishing.set("_timer", 0.0)
	await get_tree().process_frame
	_check(farm.fishing.state == Fishing.State.BITE, "le poisson mord")
	await get_tree().create_timer(1.3).timeout
	_check(not farm.fishing.busy(), "sans réaction, le poisson s'échappe")
	# Tirages : les poissons de pluie ne sortent que sous la pluie
	TimeManager.weather = "sunny"
	var seen := {}
	for i in 300:
		seen[GameData.pick_fish("farm")] = true
	_check(not seen.has("eel") and not seen.has("catfish"), "pas d'anguille ni de poisson-chat au soleil")
	_check(not seen.has("pike"), "pas de brochet dans l'étang de la ferme")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _cast_and_hook(farm: WorldMap) -> void:
	farm.fishing.try_cast(0)
	farm.fishing.set("_timer", 0.0)
	await get_tree().process_frame
	farm.fishing.on_action()
	await get_tree().process_frame


func _find_minigame(hud: Hud) -> FishingMinigame:
	var found := hud.find_children("*", "FishingMinigame", true, false)
	return found[0] if not found.is_empty() else null


func _hold(pressed: bool) -> void:
	if pressed:
		Input.action_press("use_tool")
	else:
		Input.action_release("use_tool")


func _fish_count() -> int:
	var total := 0
	for id: String in GameData.fishes:
		total += Inventory.count_of(id)
	return total


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
