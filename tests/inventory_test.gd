extends Node
## Test automatique du sac et des coffres.
##   godot --headless res://tests/inventory_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var farm: Farm = _main.call("current_map")
	# Ferme sans débris aléatoires : tests reproductibles
	FarmState.debris.clear()
	farm.call("_refresh_all")
	var hud: Hud = _main.get("_hud")
	# Sac
	_check(Inventory.capacity == 12, "le sac commence à 12 places")
	Inventory.gold = 10000
	hud.call("_buy", "backpack_36")
	_check(Inventory.capacity == 12, "le sac de voyageur demande le grand sac d'abord")
	hud.call("_buy", "backpack_24")
	_check(Inventory.capacity == 24 and Inventory.gold == 9000, "le grand sac passe à 24 places (1000 or)")
	hud.call("_buy", "backpack_36")
	_check(Inventory.capacity == 36, "puis le sac de voyageur à 36 places")
	hud.close_modal()
	var ids := ["stone", "coal", "copper_ore", "iron_ore", "gold_ore", "quartz", "amethyst", "slime", "bat_wing", "silk", "fang", "carrot"]
	for id in ids:
		Inventory.add_item(id, 5)
	_check(Inventory.count_of("carrot") == 5, "quand la barre est pleine, les objets vont dans le sac")
	var bag_index := _index_of("carrot")
	_check(bag_index >= Inventory.HOTBAR, "la carotte est rangée hors de la barre rapide")
	Inventory.swap(bag_index, 0)
	_check(Inventory.slots[0].id == "carrot", "on échange une case du sac avec la barre rapide")
	Inventory.select(30)
	_check(Inventory.selected == Inventory.HOTBAR - 1, "on ne peut tenir en main qu'un objet de la barre rapide")
	Inventory.add_item("stone", 3)
	var s := _index_of("stone")
	Inventory.slots[30] = {"id": "stone", "qty": 2}
	Inventory.swap(30, s)
	_check(Inventory.slots[30] == null and Inventory.count_of("stone") == 10, "échanger deux piles identiques les fusionne")
	# Écran du sac : choisir puis poser
	hud.open_bag()
	hud.call("_on_bag_slot", 0)
	hud.call("_on_bag_slot", 35)
	_check(Inventory.slots[35] != null and Inventory.slots[35].id == "carrot", "l'écran du sac déplace un objet en deux touchers")
	hud.close_modal()
	# Coffre
	Inventory.add_item("chest", 1)
	var cell := Vector2i(12, 14)
	farm.player.position = farm.cell_center(cell + Vector2i(0, -2))
	Inventory.swap(_index_of("chest"), 1)
	Inventory.select(1)
	farm.act_on(cell)
	_check(FarmState.objects.get(cell) == "chest", "on pose un coffre à la ferme")
	var opened := [false]
	EventBus.chest_requested.connect(func(_c: Vector2i) -> void: opened[0] = true)
	Inventory.select(2)
	farm.act_on(cell)
	_check(opened[0], "toucher le coffre l'ouvre")
	var chest: Array = FarmState.chests[cell]
	_check(chest.size() == 36, "le coffre a 36 places")
	Inventory.transfer(Inventory.slots, _index_of("coal"), chest)
	_check(Inventory.count_of("coal") == 0 and chest[0].id == "coal", "on range une pile dans le coffre")
	Inventory.transfer(chest, 0, Inventory.slots)
	_check(Inventory.count_of("coal") == 5, "et on la reprend")
	Inventory.transfer(Inventory.slots, _index_of("coal"), chest)
	Inventory.add_item("coal", 4)
	var coal_slot := _index_of("coal")
	if coal_slot < Inventory.HOTBAR:
		Inventory.swap(coal_slot, 34)
	hud.call("_stack_into", chest)
	_check(Inventory.count_of("coal") == 0 and chest[0].qty == 9, "« Ranger les piles » complète les piles du coffre")
	hud.close_modal()
	# Pioche : pas de ramassage si plein
	Inventory.add_item("pickaxe", 1)
	Inventory.swap(_index_of("pickaxe"), 3)
	Inventory.select(3)
	farm.act_on(cell)
	_check(FarmState.objects.get(cell) == "chest", "on ne ramasse pas un coffre plein")
	# Sauvegarde
	SaveManager.save_game()
	FarmState.reset()
	Inventory.reset()
	SaveManager.load_game()
	_check(Inventory.capacity == 36, "la taille du sac est sauvegardée")
	_check(FarmState.chests.has(cell) and FarmState.chests[cell][0].qty == 9, "le contenu du coffre est sauvegardé")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _index_of(id: String) -> int:
	for i in Inventory.slots.size():
		if Inventory.slots[i] != null and Inventory.slots[i].id == id:
			return i
	return -1


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
