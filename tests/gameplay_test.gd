extends Node
## Test automatique d'une boucle de jeu complète :
## labourer, semer, arroser, dormir, récolter, vendre.
##   godot --headless res://tests/gameplay_test.tscn

var _failures := 0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.call("_start", false)
	await get_tree().process_frame
	var farm: Farm = main.get_children().filter(func(c: Node) -> bool: return c is Farm)[0]
	var cell := Vector2i(12, 14)
	Inventory.select(0)  # houe
	farm.call("_act_on", cell)
	_check(FarmState.is_tilled(cell), "la houe laboure l'herbe")
	_check(PlayerState.energy == PlayerState.MAX_ENERGY - 2, "labourer coûte de l'énergie")
	Inventory.select(2)  # graines de carotte
	farm.call("_act_on", cell)
	_check(FarmState.get_crop(cell) == "carrot", "on peut semer")
	_check(Inventory.slots[2].qty == 14, "une graine est consommée")
	Inventory.select(1)  # arrosoir
	farm.call("_act_on", cell)
	_check(FarmState.is_watered(cell), "l'arrosoir arrose")
	_check(PlayerState.water == PlayerState.MAX_WATER - 1, "l'arrosoir se vide")
	farm.call("_act_on", Vector2i(30, 18))  # étang
	_check(PlayerState.water == PlayerState.MAX_WATER, "l'arrosoir se remplit à l'étang")
	farm.call("_act_on", Vector2i(18, 5))  # rocher : rien ne doit se passer
	Inventory.select(0)
	farm.call("_act_on", Vector2i(8, 9))  # chemin : pas de labour
	_check(not FarmState.is_tilled(Vector2i(8, 9)), "on ne laboure pas le chemin")
	# 4 nuits arrosées -> carotte mûre
	for i in 4:
		FarmState.water(cell)
		GameFlow.end_day(false)
		farm.hud.close_modal()
	_check(FarmState.is_mature(cell), "la carotte pousse en 4 jours arrosés")
	farm.call("_act_on", cell)
	_check(Inventory.count_of("carrot") == 1, "la récolte arrive dans l'inventaire")
	var gold_before := Inventory.gold
	for i in Inventory.SIZE:
		if Inventory.slots[i] != null and Inventory.slots[i].id == "carrot":
			Inventory.select(i)
	farm.call("_act_on", Vector2i(10, 6))  # coffre d'expédition
	GameFlow.end_day(false)
	farm.hud.close_modal()
	_check(Inventory.gold == gold_before + 35, "la carotte est vendue la nuit (+35 or)")
	SaveManager.save_game()
	_check(SaveManager.load_game(), "la sauvegarde se recharge")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
