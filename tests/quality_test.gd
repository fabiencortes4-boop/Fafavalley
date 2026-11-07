extends Node
## Test automatique de la qualité (normale, argent, or, cristal) des
## récoltes, poissons, cueillettes et produits, des demandes qui l'exigent,
## et des poissons de lac et de mer.
##   godot --headless res://tests/quality_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	# ---- Objets de qualité
	var gold_carrot := GameData.item("carrot@2")
	_check(int(gold_carrot.sell) == int(round(GameData.item("carrot").sell * 1.5)), "une carotte ★ or vaut 1,5 fois le prix (%d or)" % int(gold_carrot.sell))
	_check(str(gold_carrot.name).contains("or") and GameData.quality_of("carrot@2") == 2 and GameData.base_id("carrot@2") == "carrot", "nom et qualité lisibles")
	_check(int(GameData.item("roach@3").edible[0]) > int(GameData.item("roach").edible[0]), "un poisson ★ cristal nourrit davantage")
	_check(GameData.item_icon("carrot@1") != null, "l'icône porte une étoile")
	_check(GameData.has_quality("carrot") and GameData.has_quality("egg") and not GameData.has_quality("hoe"), "cultures et produits ont une qualité, pas les outils")
	# ---- Inventaire : les qualités ne s'empilent pas ensemble, mais se comptent ensemble
	Inventory.add_item("carrot", 3)
	Inventory.add_item("carrot@1", 2)
	Inventory.add_item("carrot@2", 1)
	_check(Inventory.count_of("carrot") == 6 and Inventory.count_of("carrot@1") == 2, "count_of compte toutes les qualités (ou une seule)")
	_check(Inventory.count_min_quality("carrot", 1) == 3, "3 carottes argent ou mieux")
	Inventory.remove_item("carrot", 4)
	_check(Inventory.count_of("carrot@2") == 1 and Inventory.count_of("carrot@1") == 1 and Inventory.count_of("carrot") == 2, "les recettes prennent d'abord la qualité la plus basse")
	Inventory.remove_item("carrot", 2)
	# ---- Tirage : compétence et bonus améliorent la qualité
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	var high := 0.0
	for i in 2000:
		low += GameData.roll_quality(0, 0.0, rng)
		high += GameData.roll_quality(10, 0.5, rng)
	_check(high > low * 2.0, "compétence et engrais donnent de bien meilleures récoltes (%.2f contre %.2f)" % [high / 2000.0, low / 2000.0])
	var crystal := 0
	for i in 2000:
		if GameData.roll_quality(0, 0.0, rng) == 3:
			crystal += 1
	_check(crystal == 0, "pas de cristal pour un débutant sans aide")
	# ---- Cadeaux : un beau cadeau fait plus plaisir
	var id := "rosalie"
	var before := int(Relations.points.get(id, 0))
	Relations.give_gift(id, "daffodil@2")
	var gained := int(Relations.points.get(id, 0)) - before
	Relations.gifted_today.clear()
	before = int(Relations.points.get(id, 0))
	Relations.give_gift(id, "daffodil")
	var gained_plain := int(Relations.points.get(id, 0)) - before
	_check(gained > gained_plain and Relations.taste(id, "daffodil@2") == Relations.taste(id, "daffodil"), "même goût, mais plus d'amitié avec un objet ★ or (%d contre %d)" % [gained, gained_plain])
	# ---- Demandes qui exigent une qualité
	var with_quality := 0
	var normal_reward := 0.0
	var quality_reward := 0.0
	for day in 40:
		TimeManager.day = day % 28 + 1
		TimeManager.season = (day / 28) % 2
		for q: Dictionary in Quests.offers():
			if int(q.quality) > 0:
				with_quality += 1
				quality_reward += float(q.gold) / maxf(1.0, float(q.qty) * float(GameData.item(str(q.item)).get("sell", 10)))
				_check(str(q.text).contains("qualité"), "le texte de la demande précise la qualité") if with_quality == 1 else null
			elif GameData.has_quality(str(q.item)):
				normal_reward += float(q.gold) / maxf(1.0, float(q.qty) * float(GameData.item(str(q.item)).get("sell", 10)))
	_check(with_quality >= 10, "des demandes exigent argent ou or (%d sur 120)" % with_quality)
	Quests.active.clear()
	var quest := {"npc": "rosalie", "item": "carrot", "qty": 2, "quality": 2, "gold": 300, "points": 200, "days_left": 3, "text": ""}
	Quests.active.append(quest)
	Inventory.add_item("carrot@1", 3)
	_check(Quests.deliverable("rosalie") == -1, "des carottes argent ne suffisent pas pour une demande « or »")
	Inventory.add_item("carrot@3", 1)
	Inventory.add_item("carrot@2", 1)
	_check(Quests.deliverable("rosalie") == 0, "or et cristal conviennent")
	Quests.deliver(0)
	_check(Inventory.count_of("carrot@2") == 0 and Inventory.count_of("carrot@3") == 0 and Inventory.count_of("carrot@1") == 3, "on livre les bonnes, on garde les autres")
	# ---- Poissons : lac et mer
	var lake := 0
	var sea := 0
	for f: Dictionary in GameData.fishes.values():
		if f.get("water") == "mer":
			sea += 1
			_check(false, "%s : poisson de mer, pêché au port ou au large" % f.name) if not f.places.all(func(p: String) -> bool: return p in ["port", "sea"]) else null
		else:
			lake += 1
			_check(not "port" in f.places, "%s : poisson d'eau douce" % f.name) if "port" in f.places else null
	_check(GameData.fishes.size() >= 20 and lake >= 10 and sea >= 10, "%d poissons : %d de lac, %d de mer" % [GameData.fishes.size(), lake, sea])
	TimeManager.season = 0
	TimeManager.minutes = 9 * 60
	var port_catch := {}
	var lake_catch := {}
	for i in 300:
		port_catch[GameData.pick_fish("port")] = true
		lake_catch[GameData.pick_fish("forest")] = true
	_check(port_catch.keys().all(func(k: String) -> bool: return GameData.fish(k).water == "mer"), "au port, on ne pêche que des poissons de mer (%s)" % ", ".join(port_catch.keys()))
	_check(lake_catch.keys().all(func(k: String) -> bool: return GameData.fish(k).water == "lac"), "au lac de la forêt, que des poissons d'eau douce")
	# ---- Pêche : une prise parfaite d'un gros poisson donne souvent de la qualité
	var good := 0
	for i in 200:
		if GameData.roll_quality(Skills.level("fishing"), 1.0) > 0:
			good += 1
	_check(good > 60, "gros poisson + prise parfaite : souvent argent ou mieux (%d/200)" % good)
	# ---- Vente : le prix suit la qualité
	FarmState.shipping.clear()
	FarmState.ship("carrot@2", 2)
	var report := {}
	var earned := FarmState.sell_shipping(report)
	_check(earned == int(gold_carrot.sell) * 2, "l'expédition paie la qualité (%d or)" % earned)
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
