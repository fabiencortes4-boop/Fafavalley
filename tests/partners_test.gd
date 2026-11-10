extends Node
## Test automatique des partenariats avec les nouveaux venus : propositions
## selon la balance, fournisseur du Bocal, ferme pilote, ferme vitrine,
## label de la mairie, rupture, fin de contrat et sauvegarde.
##   godot --headless res://tests/partners_test.tscn

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
	_check(Tips.tips.has("partners"), "astuce « partners »")
	# ---- Rien n'est proposé tant que la balance ne penche pas vers eux
	Soul.arrive()
	_night(hud)
	_check(Partners.known().is_empty(), "balance à l'équilibre : aucune proposition")
	Soul.lean(-40.0)
	_night(hud)
	_check(Partners.known().is_empty(), "côté artisans : aucune proposition")
	Soul.tilt = 16.0
	_night(hud)
	_check(Partners.offered.has("bocal") and not Partners.offered.has("neo") and Mail.custom.has("partner_offer_bocal"), "Capucine propose de fournir le Bocal")
	Soul.tilt = 26.0
	_night(hud)
	_check(Partners.offered.has("neo") and Partners.offered.has("lin") and not Partners.offered.has("label"), "Hugo et Élise proposent à leur tour ; le label attend la nouvelle maire")
	# ---- Fournisseur du Bocal
	TimeManager.season = 0
	TimeManager.day = 2
	_check(Partners.can_sign("bocal") and Partners.sign("bocal"), "on signe avec le Bocal")
	_check(not Partners.order.is_empty() and int(Partners.order.qty) == Partners.ORDER_QTY, "une commande de qualité arrive")
	var item := str(Partners.order.item)
	Inventory.add_item(item, Partners.ORDER_QTY)
	_check(not Partners.can_deliver(), "la qualité normale ne suffit pas")
	Inventory.add_item(GameData.with_quality(item, 1), Partners.ORDER_QTY)
	var gold := Inventory.gold
	var tilt := Soul.tilt
	var friends := int(Relations.points.get("capucine", 0))
	_check(Partners.can_deliver() and Partners.deliver(), "on livre le panier")
	_check(Inventory.gold == gold + int(Partners.order.gold) and int(Partners.order.gold) > int(GameData.item(item).sell) * Partners.ORDER_QTY * 2, "payé bien plus cher que le marché")
	_check(Soul.tilt > tilt and int(Relations.points.get("capucine", 0)) > friends, "la balance et l'amitié suivent")
	_check(Inventory.count_of(item) == Partners.ORDER_QTY, "seuls les beaux produits sont partis")
	TimeManager.day = 7
	_night(hud)  # lundi
	_check(not bool(Partners.order.done) and Partners.misses == 0, "lundi : nouvelle commande")
	TimeManager.day = 14
	_night(hud)
	_check(Partners.misses == 1 and Partners.is_signed("bocal"), "une commande manquée : Capucine est déçue")
	TimeManager.day = 21
	_night(hud)
	_check(not Partners.is_signed("bocal") and Partners.cooldown("bocal") > 0, "deux d'affilée : le contrat tombe")
	# ---- Ferme pilote de l'Atelier Néo
	var price := Shops.price("outils", "pump_can")
	_check(Partners.sign("neo"), "on signe la ferme pilote")
	_check(Shops.price("outils", "pump_can") == int(round(price * Partners.NEO_DISCOUNT)), "l'Atelier Néo à -25 %")
	_check(Mail.custom.keys().any(func(k: String) -> bool: return k.begins_with("partner_neo_gift")), "un arroseur connecté offert")
	Soul.tilt = 26.0
	_check(Partners.take_fee(1000) == 50 and Soul.tilt > 26.0, "Hugo prélève 5 % des ventes, et la balance penche")
	FarmState.ship("carrot", 10)
	gold = Inventory.gold
	var worth := int(GameData.item("carrot").sell) * 10
	_night(hud)
	_check(Inventory.gold == gold + worth - int(worth * Partners.NEO_FEE), "la part de Hugo est retirée des ventes de la nuit")
	# ---- Ferme vitrine du Studio Lin
	_check(Partners.sign("lin"), "on signe la ferme vitrine")
	TimeManager.day = 28  # dimanche
	_check(Partners.showroom_day(), "le dimanche, la ferme est aux touristes")
	gold = Inventory.gold
	_night(hud)
	_check(Inventory.gold == gold and Partners.note.contains("pas assez belle"), "ferme trop peu décorée : aucun visiteur")
	for i in 4:
		FarmState.place_object(Vector2i(20 + i, 20), "garden_fountain")
	var beauty := FarmState.beauty()
	TimeManager.day = 7
	gold = Inventory.gold
	_night(hud)
	_check(beauty >= Partners.SHOW_BEAUTY and Inventory.gold == gold + mini(beauty * Partners.SHOW_GOLD, Partners.SHOW_MAX), "ferme belle : les entrées du dimanche (%d or)" % (Inventory.gold - gold))
	# ---- Rupture
	friends = int(Relations.points.get("elise", 0))
	Relations.points["elise"] = friends + 500
	Partners.cancel("lin")
	_check(not Partners.is_signed("lin") and int(Relations.points.elise) == friends + 500 + Partners.BREAK_POINTS and not Partners.can_sign("lin"), "rompre fâche Élise et ferme la porte une saison")
	# ---- Sauvegarde
	var saved := Partners.to_dict()
	Partners.reset()
	_check(Partners.known().is_empty(), "nouvelle partie : plus de partenariat")
	Partners.from_dict(saved)
	_check(Partners.is_signed("neo") and Partners.cooldown("lin") > 0 and Partners.offered.has("bocal"), "la sauvegarde retrouve les contrats")
	# ---- Label de la mairie
	Soul.modern_tier = 3
	Soul._apply()
	_night(hud)
	_check(Partners.offered.has("label") and Partners.sign("label"), "la nouvelle maire propose le label")
	_check(Partners.sell_factor() == Partners.LABEL_BONUS, "tout se vend 10 % plus cher")
	Inventory.spend_gold(Inventory.gold)
	TimeManager.day = 28
	_night(hud)
	_check(not Partners.label_paid and Partners.sell_factor() == 1.0, "licence impayée : label suspendu")
	Inventory.add_gold(5000)
	TimeManager.day = 28
	_night(hud)
	_check(Partners.label_paid and Inventory.gold <= 5000 - Partners.LABEL_FEE, "licence réglée à la saison suivante")
	hud.call("open_partners")
	await get_tree().process_frame
	hud.call("close_modal")
	# ---- Le partenaire s'en va : le contrat tombe
	Soul.reset()
	Soul.arrive()
	Soul.tilt = 30.0
	Soul.artisan_tier = 3
	Soul._apply()
	_night(hud)
	_check(not Partners.is_signed("neo") and not Partners.is_signed("label") and not Partners.available("neo"), "Hugo parti, plus de mairie nouvelle : les contrats prennent fin")
	Soul.reset()
	Partners.reset()
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _night(hud: Node) -> void:
	GameFlow.end_day()
	hud.call("close_modal")
	get_tree().paused = false


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  ÉCHEC ") + label)
	if not ok:
		_failures += 1
