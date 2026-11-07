extends Node
## Test automatique de l'album (collections) et des succès.
##   godot --headless res://tests/collections_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var hud: Hud = _main.get("_hud")
	_check(Collections.total_found() == 0, "nouvelle partie : l'album est vide (outils et graines n'y comptent pas)")
	_check(Collections.items_of("fish").size() == GameData.fishes.size(), "tous les poissons sont dans l'album")
	_check(Collections.items_of("mine").has("emerald") and Collections.items_of("mine").has("slime"), "minerais et butin dans « Trésors de la mine »")
	var seen := [""]
	Collections.discovered.connect(func(id: String, _c: String) -> void: seen[0] = id)
	Inventory.add_item("carrot", 2)
	_check(Collections.found.has("carrot") and seen[0] == "carrot", "une récolte entre dans l'album")
	seen[0] = ""
	Inventory.add_item("carrot", 1)
	_check(seen[0] == "", "un objet déjà connu ne se redécouvre pas")
	# Palier : la moitié de la cueillette rapporte de l'or
	var forage := Collections.items_of("forage")
	var gold := Inventory.gold
	for i in ceili(forage.size() / 2.0):
		Inventory.add_item(forage[i], 1)
	_check(Collections.rewarded.has("forage_half") and Inventory.gold >= gold + 150, "la moitié de la cueillette : récompense")
	for id: String in forage:
		Inventory.add_item(id, 1)
	_check(Collections.rewarded.has("forage_full"), "la cueillette complète : récompense")
	# Succès
	var got := [""]
	Achievements.unlocked.connect(func(id: String) -> void: got[0] = id)
	_check(not Achievements.done.has("harvest_100"), "le succès « Main verte » n'est pas encore obtenu")
	gold = Inventory.gold
	Story.bump("harvest", 100)
	_check(Achievements.done.has("first_harvest") and Achievements.done.has("harvest_100"), "100 récoltes : deux succès")
	_check(Inventory.gold >= gold + 350, "les succès rapportent leur or")
	_check(Achievements.progress(Achievements.get_achievement("harvest_500")) > 0.19, "la progression des succès se calcule")
	PlayerState.flags["mine_deepest"] = 10
	Achievements.check()
	_check(Achievements.done.has("mine_10"), "atteindre le niveau 10 : succès")
	# Menus
	hud.open_collections("forage")
	_check(hud.get("_modal") != null, "l'album s'ouvre")
	hud.open_achievements()
	_check(hud.get("_modal") != null, "la liste des succès s'ouvre")
	hud.close_modal()
	# Sauvegarde
	SaveManager.save_game()
	Collections.reset()
	Achievements.reset()
	SaveManager.load_game()
	_check(Collections.found.has("carrot") and Collections.rewarded.has("forage_full"), "l'album se recharge")
	_check(Achievements.done.has("harvest_100"), "les succès se rechargent")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
