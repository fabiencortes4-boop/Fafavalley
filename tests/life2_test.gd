extends Node
## Test automatique : mine à thèmes et Gardien, maison agrandie et meubles,
## enfant, chèvres et moutons, ruche et tonneau, orages et fêtes, remarques
## des habitants, astuces et guide, emplacements de sauvegarde, export et
## import, accessibilité.
##   godot --headless res://tests/life2_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var hud: Hud = _main.get("_hud")
	# ---- Mine à thèmes
	_check(MineLevel.theme_for(5) == "earth" and MineLevel.theme_for(12) == "ice" and MineLevel.theme_for(25) == "lava" and MineLevel.theme_for(30) == "deep", "terre, glace, lave, puis le fond")
	_main.call("_switch_to", "mine:30")
	await _frames(3)
	var bosses := get_tree().get_nodes_in_group("monsters").filter(func(m: Node) -> bool: return m is Monster and (m as Monster).kind == "guardian")
	_check(bosses.size() == 1, "le Gardien de la source attend au niveau 30")
	hud.close_modal()
	if bosses.size() == 1:
		var boss: Monster = bosses[0]
		var gold := Inventory.gold
		boss.hit(99999, boss.position + Vector2(10, 0), 0.0)
		await _frames(3)
		_check(PlayerState.flags.has("mine_boss") and Inventory.gold >= gold + 5000, "vaincu : 5000 or et le drapeau de victoire")
		_check(Inventory.count_of("mountain_heart") == 1 or get_tree().get_nodes_in_group("monsters").is_empty(), "le Cœur de la montagne")
		hud.close_modal()
	_main.call("_switch_to", "mine:30")
	await _frames(3)
	_check(get_tree().get_nodes_in_group("monsters").filter(func(m: Node) -> bool: return m is Monster and (m as Monster).kind == "guardian").is_empty(), "le Gardien ne revient pas")
	# ---- Maison agrandie et meubles
	PlayerState.flags["house_big"] = true
	_main.call("_switch_to", "home")
	await _frames(3)
	var home: HomeMap = _main.call("current_map")
	_check(home.get("_map_size").x == 17, "la maison agrandie est plus large")
	Inventory.add_item("bookshelf", 1)
	for i in Inventory.SIZE:
		if Inventory.slots[i] != null and Inventory.slots[i].id == "bookshelf":
			Inventory.select(i)
	home.player.position = home.cell_center(Vector2i(13, 4))
	await get_tree().physics_frame
	home.act_on(Vector2i(14, 4))
	_check(Machines.furniture.get(Vector2i(14, 4)) == "bookshelf" and not home.is_walkable(Vector2i(14, 4)), "on pose une bibliothèque")
	Inventory.add_item("pickaxe", 1)
	for i in Inventory.SIZE:
		if Inventory.slots[i] != null and Inventory.slots[i].id == "pickaxe":
			Inventory.select(i)
	home.act_on(Vector2i(14, 4))
	_check(not Machines.furniture.has(Vector2i(14, 4)) and Inventory.count_of("bookshelf") == 1, "la pioche la reprend")
	# ---- Enfant
	Marriage.spouse = "lina"
	TimeManager.day = 20
	Marriage.wedding_day = 1
	for i in 60:
		if Marriage.child_name != "":
			break
		Marriage.new_day()
	_check(Marriage.child_name != "" and Marriage.child_stage() == "baby", "un bébé arrive quelques semaines après le mariage (%s)" % Marriage.child_name)
	_check(Marriage.play_with_child().contains(Marriage.child_name) and Marriage.play_with_child().contains("sieste"), "on joue avec lui une fois par jour")
	Marriage.birth_pending = false
	# ---- Élevage : chèvres et moutons
	_check(Animals.animal_info("goat").get("product") == "goat_milk" and Animals.animal_info("sheep").get("product") == "wool", "chèvres et moutons à l'étable")
	# ---- Météo et fêtes
	TimeManager.weather = "storm"
	_check(TimeManager.is_raining() and TimeManager.is_storm(), "l'orage arrose aussi")
	TimeManager.weather = "sunny"
	var ids: Array = Events.festivals.map(func(f: Dictionary) -> String: return str(f.id))
	_check(ids.has("fireworks") and ids.has("pumpkin_fair") and ids.has("ice_fishing"), "trois nouvelles fêtes")
	# ---- Remarques des habitants
	PlayerState.flags["mine_boss"] = true
	_check(Relations._remark_applies("boss") and Relations._remark_applies("married"), "les habitants savent ce que tu as accompli")
	# ---- Astuces et guide
	_check(Tips.guide.size() >= 6 and Tips.tips.has("quality"), "un guide et des astuces")
	Tips.enabled = true
	Tutorial.skip()
	Tips.show("quality")
	Tips.show("quality")
	_check(Tips.pop().size() == 2 and Tips.pop().is_empty(), "une astuce ne s'affiche qu'une fois")
	Tips.enabled = false
	# ---- Accessibilité
	Settings.colorblind = true
	GameData.clear_quality_icons()
	_check(GameData.item_icon("carrot@3") != null, "icônes de qualité avec des points")
	Settings.colorblind = false
	GameData.clear_quality_icons()
	# ---- Emplacements, export et import
	PlayerState.player_name = "Camille"
	PlayerState.farm_name = "Les Tournesols"
	SaveManager.slot = 1
	SaveManager.save_game()
	_check(SaveManager.summary(1).get("farm") == "Les Tournesols", "le résumé de l'emplacement 2")
	var text := SaveManager.export_text()
	_check(text.begins_with("FAFA1:"), "export en texte")
	_check(SaveManager.import_text(text, 2) and SaveManager.summary(2).get("name") == "Camille", "import dans l'emplacement 3")
	_check(not SaveManager.import_text("n'importe quoi", 2), "un texte invalide est refusé")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(1)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(2)))
	SaveManager.slot = 0
	_check(Hud.personalize("Bonjour {nom} !") == "Bonjour Camille !", "le prénom dans les dialogues")
	# ---- Éditeur de personnage
	var a := CharacterLook.default_look()
	var b := a.duplicate()
	b.hair_color = 4
	b.beard = 3
	var ia := CharacterLook.image(a)
	var ib := CharacterLook.image(b)
	_check(ia.get_size() == Vector2i(256, 256), "texture du personnage générée (256 px)")
	_check(ia.get_pixelv(CharacterLook.TOP + Vector2i(5, 5)) != ib.get_pixelv(CharacterLook.TOP + Vector2i(5, 5)), "la couleur des cheveux change le dessus de la tête")
	_check(ia.get_pixelv(CharacterLook.FRONT + Vector2i(5, 28)) != ib.get_pixelv(CharacterLook.FRONT + Vector2i(5, 28)), "la barbe se voit sur le menton")
	var bald := a.duplicate()
	bald.hair = CharacterLook.HAIR_STYLES.find("Chauve")
	_check(CharacterLook.image(bald).get_pixelv(CharacterLook.BACK + Vector2i(16, 4)) == CharacterLook.SKINS[a.skin], "chauve : le crâne est couleur peau")
	var woman := a.duplicate()
	woman.sex = 1
	woman.top = 1
	_check(CharacterLook.image(woman).get_pixel(60, 200) != ia.get_pixel(60, 200), "le corps change avec le sexe et le haut")
	_check(CharacterLook.texture(a) == CharacterLook.texture(a.duplicate()), "les textures sont mises en cache")
	PlayerState.appearance = b
	SaveManager.save_game()
	PlayerState.appearance = {}
	SaveManager.load_game()
	_check(int(PlayerState.appearance.get("beard", -1)) == 3, "l'apparence se sauvegarde")
	hud.open_appearance()
	_check(hud.get("_modal") != null, "on peut changer d'apparence en cours de partie")
	hud.close_modal()
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
