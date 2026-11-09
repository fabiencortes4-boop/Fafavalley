extends Node
## Test automatique de « L'âme de Valfleur » : arrivée des nouveaux venus,
## balance des achats, préavis, départs définitifs, paliers des deux voies,
## nouvelle maire, fêtes transformées, fins et sauvegarde.
##   godot --headless res://tests/soul_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	Tutorial.skip()
	Tips.enabled = false
	var hud: Node = _main.get("_hud")
	# ---- Avant l'arrivée : le pré est vide, rien ne compte
	_check(Tips.tips.has("soul"), "astuce « soul »")
	_check(not Soul.arrived and not GameData.npcs.has("capucine"), "les nouveaux venus ne sont pas encore là")
	await _go("village")
	var v: Village = _main.call("current_map")
	_check(v.is_walkable(Vector2i(24, 35)), "le pré du sud est encore libre")
	Soul.record("store", 4000)
	_check(Soul.tilt == 0.0, "avant leur arrivée, les achats ne pèsent pas")
	_check(not Shops.is_open("bocal"), "le Bocal n'existe pas encore")
	# ---- Chapitre 3 : annonce, puis installation deux jours plus tard
	Story.chapter = 3
	await _go("farm")
	_night(hud)
	_check(Soul.arrival_day > 0 and Mail.custom.has("soul_news"), "le maire annonce le lotissement")
	_night(hud)
	_night(hud)
	_check(Soul.arrived and Mail.custom.has("soul_arrived"), "les Hauts de Valfleur ouvrent")
	for id: String in ["capucine", "hugo", "elise"]:
		_check(GameData.npcs.has(id), "%s s'est installé·e" % GameData.npc(id).name)
	_check(not GameData.npcs.has("sacha"), "Sacha n'est pas encore là")
	await _go("village")
	v = _main.call("current_map")
	_check(not v.is_walkable(Vector2i(24, 35)) and v.is_walkable(Vector2i(24, 37)), "trois boutiques bordent la nouvelle rue")
	for b: String in ["bocal", "outils", "studio"]:
		_check(v._interactables.get(Village.door_front(b) + Vector2i.UP, "") == "door:" + b, "porte : " + b)
	for npc in v.npcs:
		for e: Dictionary in GameData.npc(npc.id).get("schedule", []):
			if e.has("cell") and npc.id in Soul.NEWCOMERS:
				_check(v.is_walkable(Vector2i(int(e.cell[0]), int(e.cell[1]))), "%s : lieu accessible %s" % [npc.id, e.cell])
	# ---- Boutiques : objets puissants, par palier
	TimeManager.minutes = 11 * 60
	TimeManager.day = 2  # un mardi : tout est ouvert
	_check(Shops.is_open("bocal") and Shops.is_open("outils") and Shops.is_open("studio"), "les trois boutiques sont ouvertes")
	_check("pump_can" in Shops.items("outils") and not "smart_sprinkler" in Shops.items("outils"), "l'arroseur connecté attend le palier 2")
	_check(int(GameData.item("pump_can").area) == 5 and int(GameData.item("jackhammer").power) == 4, "outils puissants")
	for id: String in Shops.items("bocal") + Shops.items("outils") + Shops.items("studio") + ["smart_sprinkler", "design_sculpture", "kombucha", "steel_hoe", "steel_can", "master_axe", "master_pickaxe"]:
		_check(not GameData.item(id).is_empty() and GameData.item_icon(id) != null, "objet : " + id)
	_check(FarmState.SPRINKLER_RANGE.smart_sprinkler.size() == 24, "l'arroseur connecté couvre 24 cases")
	# ---- La balance
	Inventory.add_gold(200000)
	_check(Soul.side_of("bocal") == "modern" and Soul.side_of("forge") == "artisan" and Soul.side_of("market") == "", "chaque boutique a son camp")
	Soul.record("store", 2000)
	_check(is_equal_approx(Soul.tilt, -10.0), "un achat chez les artisans fait pencher la balance (%.1f)" % Soul.tilt)
	Soul.record("outils", 2000)
	_check(is_equal_approx(Soul.tilt, 0.0), "un achat aux Hauts de Valfleur la ramène")
	var base_price := Shops.price("store", "seed_carrot")
	var forge_price := Crafting.gold_cost("steel_axe")
	# ---- Voie des nouveaux venus : inquiétude, préavis, sursis
	Soul.record("outils", 4400)  # 22 points : à moins de 10 du palier
	_night(hud)
	_check(Soul.warned.has("modern:0") and Soul.notice.is_empty(), "Rosalie s'inquiète avant le palier")
	Soul.record("outils", 2000)  # 32 points
	_night(hud)
	_check(str(Soul.notice.get("side", "")) == "modern" and Soul.threatened("modern") == "odette", "Odette donne son préavis")
	_check(Soul.notice_text() != "" and Soul.talk("odette") != "", "elle en parle")
	Soul.record("store", 2000)  # la balance revient sous le seuil
	_night(hud)
	_check(Soul.notice.is_empty() and Soul.modern_tier == 0 and GameData.npcs.has("odette"), "sursis : la balance est revenue, personne ne part")
	# ---- Palier 1 : Odette et Théo partent, Sacha arrive
	Soul.record("outils", 4000)
	for i in Soul.NOTICE_DAYS + 1:
		_night(hud)
	_check(Soul.modern_tier == 1, "premier palier des nouveaux venus")
	_check(not GameData.npcs.has("odette") and not GameData.npcs.has("theo"), "Odette et Théo sont partis")
	_check(GameData.npc("odette").get("name", "") == "Odette", "on se souvient d'Odette")
	_check(GameData.npcs.has("sacha") and Mail.custom.has("soul_bye_odette") and Mail.custom.has("soul_hello_sacha"), "Sacha reprend la maison")
	_check(Soul.house_taken("odette") and InteriorMap.name_of("odette") == "Chez Sacha", "la maison change de nom")
	_check(Shops.price("store", "seed_carrot") > base_price and Crafting.gold_cost("steel_axe") > forge_price, "les loyers montent : les artisans augmentent")
	_check("chainsaw" in Shops.items("outils"), "la tronçonneuse arrive à l'Atelier Néo")
	_check(Soul.sell_factor("jam") > 1.0 and Soul.sell_factor("carrot") == 1.0 and Soul.sell_factor("carrot@2") > 1.0, "les beaux produits se vendent plus cher")
	_check(Quests.offers().all(func(q: Dictionary) -> bool: return GameData.npcs.has(str(q.npc))), "plus de demandes d'habitants partis")
	await _go("village")
	v = _main.call("current_map")
	_check(v.npcs.all(func(n: Npc) -> bool: return n.id != "odette") and v.npcs.any(func(n: Npc) -> bool: return n.id == "sacha"), "au village : Sacha, plus Odette")
	# ---- Sauvegarde
	var saved := Soul.to_dict()
	Soul.reset()
	_check(GameData.npcs.has("odette") and not GameData.npcs.has("capucine") and Soul.modern_tier == 0, "nouvelle partie : tout le monde est revenu")
	Soul.from_dict(saved)
	_check(Soul.modern_tier == 1 and not GameData.npcs.has("odette") and GameData.npcs.has("sacha") and GameData.npcs.has("hugo"), "la sauvegarde retrouve le village changé")
	# ---- Retrouvailles : ils reviennent pour la Fête des récoltes
	TimeManager.season = int(Soul.REUNION[0])
	TimeManager.day = int(Soul.REUNION[1]) - 1
	_night(hud)
	_check(Soul.visiting and GameData.npcs.has("odette") and Soul.is_visitor("odette"), "Odette revient pour la Fête des récoltes")
	_night(hud)
	_check(not Soul.visiting and not GameData.npcs.has("odette"), "puis elle repart")
	# ---- Paliers 2 et 3 : Lina, Gaston, et la nouvelle maire
	for step in 2:
		Soul.record("outils", 8000)
		for i in Soul.NOTICE_DAYS + 2:
			_night(hud)
	_check(Soul.modern_tier == 3 and Soul.settled() and Soul.outcome() == "modern", "Valfleur nouvelle (3/0)")
	_check(not GameData.npcs.has("lina") and not GameData.npcs.has("gaston") and GameData.npcs.has("ines"), "Lina et Gaston sont partis, Inès est arrivée")
	_check(Soul.forge_taken() and Soul.side_of("forge") == "modern" and Crafting.gold_cost("steel_axe") > int(forge_price * 1.5), "la forge a changé de mains et coûte cher")
	_check(Soul.modern_mayor() and Soul.mayor_from().begins_with("Capucine") and str(GameData.npc("bertrand").title) == "l'ancien maire", "Capucine est élue maire")
	_check(Mail.custom.has("soul_election") and str(Mail.letters["event_spring_fair"].from).begins_with("Capucine"), "les annonces viennent de la nouvelle mairie")
	var fair: Dictionary = Events.festivals.filter(func(f: Dictionary) -> bool: return str(f.id) == "spring_fair")[0]
	_check(str(Soul.festival(fair).name) == "Marché des créateurs" and str(Soul.festival(fair).activity) == "market", "les fêtes changent de nom et de style")
	_check(Soul.prize_factor() == 2.0 and Soul.fete_factor() == 0.5, "concours mieux dotés, fêtes moins chaleureuses")
	_check(Soul.decor().filter(func(d: Array) -> bool: return str(d[1]) == "billboard").size() == 3, "trois affiches en ville")
	_check(not Soul.bubbles().is_empty() and Events.calendar_text().begins_with("Événements"), "le village en parle")
	_night(hud)
	_check(Soul.ended and str(PlayerState.flags.get("soul_ending", "")) == "modern" and Mail.custom.has("soul_ending"), "la fin : Valfleur nouvelle")
	var tilt_before := Soul.modern_tier
	Soul.record("store", 120000)
	for i in 5:
		_night(hud)
	_check(Soul.modern_tier == tilt_before and Soul.artisan_tier == 0, "le village ne change que trois fois")
	await _go("village")
	v = _main.call("current_map")
	_check(not v.is_walkable(Vector2i(33, 21)), "les affiches occupent leur case")
	hud.call("open_soul")
	await get_tree().process_frame
	hud.call("close_modal")
	# ---- Voie des artisans (nouvelle partie)
	Soul.reset()
	Mail.reset()
	PlayerState.flags.erase("soul_ending")
	Soul.arrive()
	_check(not Crafting.is_unlocked("steel_hoe"), "la houe d'acier demande le palier 1 des artisans")
	Soul.record("store", 6400)
	for i in Soul.NOTICE_DAYS + 2:
		_night(hud)
	_check(Soul.artisan_tier == 1 and not GameData.npcs.has("elise") and GameData.npcs.has("capucine"), "palier 1 des artisans : Élise ferme le Studio Lin")
	_check(not Shops.is_open("studio") and Soul.door_note("studio") != "" and Soul.door_note("bocal") == "", "le Studio Lin est à vendre")
	_check(Soul.recipe_unlocked(Crafting.recipes.steel_hoe) and not Soul.recipe_unlocked(Crafting.recipes.master_axe), "Gaston forge la houe d'acier")
	_check(Shops.price("store", "seed_carrot") <= base_price and Soul.price_factor("store") < 1.0, "les prix des artisans baissent")
	_check(Soul.bunting(), "des fanions au-dessus de la rue des artisans")
	Soul.record("store", 6666)
	for i in Soul.NOTICE_DAYS + 2:
		_night(hud)
	_check(Soul.artisan_tier == 2 and not GameData.npcs.has("capucine"), "palier 2 : Capucine ferme le Bocal")
	_check(Soul.request_factor() > 1.0 and Soul.decor().size() == 2, "demandes mieux payées, étals d'artisans")
	FarmState.till(Vector2i(15, 14))
	FarmState.plant(Vector2i(15, 14), "carrot")
	TimeManager.day = 6  # veille de dimanche
	_night(hud)
	_check(Mail.custom.keys().any(func(k: String) -> bool: return k.begins_with("soul_basket_")), "le panier des voisins, le dimanche")
	# ---- Fin partagée : le troisième changement va aux nouveaux venus
	Soul.record("outils", 40000)
	for i in Soul.NOTICE_DAYS + 3:
		_night(hud)
	_check(Soul.artisan_tier == 2 and Soul.modern_tier == 1 and Soul.outcome() == "shared", "Valfleur partagée (2 artisans, 1 nouveaux venus)")
	_check(not Soul.modern_mayor() and Soul.mayor_from().begins_with("Bertrand"), "Bertrand reste maire")
	_check(Soul.ended and str(PlayerState.flags.get("soul_ending", "")) == "shared", "la fin : Valfleur partagée")
	# ---- Mariage : l'époux·se ne part pas
	Soul.reset()
	Soul.arrive()
	Soul.modern_tier = 1
	Soul._apply()
	Marriage.spouse = "lina"
	Soul.record("outils", 20000)
	for i in Soul.NOTICE_DAYS + 2:
		_night(hud)
	_check(Soul.modern_tier == 2 and GameData.npcs.has("lina") and not GameData.npcs.has("ines"), "Lina, mariée au joueur, reste à Valfleur")
	Marriage.spouse = ""
	Soul.reset()
	_check(GameData.npcs.has("gaston") and GameData.npcs.has("odette") and GameData.npcs.has("lina") and not GameData.npcs.has("hugo"), "tout est remis à zéro")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


## Change de carte (en laissant finir un éventuel changement en cours).
func _go(map_id: String) -> void:
	for i in 3:
		await get_tree().process_frame
	_main.call("_switch_to", map_id)
	for i in 2:
		await get_tree().process_frame


## Une nuit passe (on referme le bilan du matin).
func _night(hud: Node) -> void:
	GameFlow.end_day()
	hud.call("close_modal")
	get_tree().paused = false


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  ÉCHEC ") + label)
	if not ok:
		_failures += 1
