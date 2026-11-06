extends Node
## Test automatique de l'histoire : 5 chapitres, plusieurs voies pour
## avancer, recettes débloquées, lettres, sauvegarde.
##   godot --headless res://tests/story_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var hud: Hud = _main.get("_hud")
	_check(Story.chapters.size() == 5 and Story.chapter == 0, "l'histoire commence au chapitre 1 (sur 5)")
	_check(Crafting.is_unlocked("chest") and Crafting.is_unlocked("hay"), "coffre et foin sont disponibles dès le début")
	Inventory.add_item("slime", 4)
	Inventory.add_item("coal", 2)
	_check(not Crafting.is_unlocked("fertilizer") and not Crafting.can_craft("fertilizer"), "l'engrais est verrouillé au départ")
	hud.open_story()
	_check(hud.get("_modal") != null, "le journal de l'histoire s'ouvre")
	hud.close_modal()
	# ---- Chapitre 1 par la voie des récoltes
	var advanced := [""]
	EventBus.story_advanced.connect(func(id: String, _p: String) -> void: advanced[0] = id)
	Story.bump("harvest", 14)
	_check(Story.chapter == 0, "14 récoltes : pas encore")
	Story.bump("harvest", 1)
	_check(Story.chapter == 1 and advanced[0] == "ch1", "15 récoltes terminent le chapitre 1")
	_check(Crafting.can_craft("fertilizer"), "l'engrais est débloqué")
	_check(Mail.pending.has("story_ch1"), "Bertrand envoie une lettre")
	var gold := Inventory.gold
	while Mail.has_mail():
		Mail.open_next()
	_check(Inventory.gold >= gold + 250, "la lettre contient la récompense")
	# ---- Chapitre 2 : les compteurs repartent de zéro, autre voie (cadeaux)
	Story.bump("harvest", 50)
	_check(Story.chapter == 1, "les récoltes ne font pas avancer le chapitre 2")
	_check(Story.value("gifts") == 0, "le compteur de cadeaux part de zéro")
	for id: String in ["rosalie", "gaston", "odette", "lina", "bertrand", "mathis"]:
		Relations.give_gift(id, "carrot")
	_check(Story.chapter == 2, "6 cadeaux terminent le chapitre 2")
	_check(Crafting.is_unlocked("omelette"), "l'omelette est débloquée")
	# ---- Chapitre 3 par la profondeur de la mine (état du monde)
	PlayerState.flags["mine_deepest"] = 5
	Story.check()
	_check(Story.chapter == 3, "atteindre le niveau 5 de la mine termine le chapitre 3")
	_check(Crafting.is_unlocked("sprinkler") and Crafting.is_unlocked("copper_can"), "arroseur et arrosoir en cuivre débloqués")
	# ---- Chapitre 4 par la cuisine
	Inventory.add_item("carrot", 6)
	Inventory.add_item("turnip", 6)
	Inventory.add_item("cabbage", 6)
	for i in 6:
		Crafting.craft("vegetable_soup")
	_check(Story.chapter == 4, "cuisiner 6 plats termine le chapitre 4")
	_check(Crafting.is_unlocked("cheese"), "le fromage est débloqué")
	# ---- Sauvegarde au milieu du dernier chapitre
	Story.bump("shipped", 40)
	var saved := Story.to_dict()
	Story.reset()
	Story.from_dict(saved)
	_check(Story.chapter == 4 and Story.value("shipped") == 40, "l'histoire est sauvegardée")
	# ---- Chapitre 5 par l'amitié
	for id: String in GameData.npcs:
		Relations.add_points(id, 2 * Relations.POINTS_PER_HEART)
	Story.check()
	_check(Story.finished(), "20 cœurs au total : Valfleur est en fête, l'histoire est finie")
	_check(Mail.pending.has("story_ch5"), "la lettre de Firmin arrive")
	hud.open_story()
	hud.close_modal()
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
