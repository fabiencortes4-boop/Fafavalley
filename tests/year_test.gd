extends Node
## Test automatique : bilan de l'année, cultures d'hiver, scènes de cœur,
## volumes séparés, sauvegarde sûre (copie de secours).
##   godot --headless res://tests/year_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	Tutorial.skip()
	# ---- Bilan de l'année
	var low := YearReview.evaluate()
	_check(int(low.stars) == 1, "début de partie : 1 étoile")
	Story.bump("earned", 50000)
	Story.bump("shipped", 1200)
	PlayerState.flags["story_ch1"] = true
	PlayerState.flags["story_ch2"] = true
	var mid := YearReview.evaluate()
	_check(int(mid.stars) > int(low.stars), "ventes et récoltes font monter la note (%d étoiles)" % int(mid.stars))
	var gold := Inventory.gold
	TimeManager.season = 3
	TimeManager.day = 28
	GameFlow.end_day(false)
	await get_tree().process_frame
	_main.get("_hud").close_modal()
	_check(TimeManager.season == 0 and TimeManager.day == 1 and TimeManager.year == 2, "nouvelle année")
	_check(Mail.pending.has("year_review_1"), "Bertrand envoie le bilan de l'année")
	if Mail.letters.has("year_review_1"):
		print(str(Mail.letters["year_review_1"].text).indent("      | "))
	while Mail.has_mail():
		Mail.open_next()
	_check(Inventory.count_of("valfleur_trophy") == 1 and Inventory.gold >= gold + int(mid.stars) * YearReview.GOLD_PER_STAR, "le bilan rapporte le trophée et de l'or")
	_check(YearReview.value("earned") == 0, "les ventes repartent de zéro pour la nouvelle année")
	var saved_mail := Mail.to_dict()
	Mail.from_dict(saved_mail)
	_check(Mail.letters.has("year_review_1"), "la lettre du bilan est sauvegardée")
	# ---- Cultures d'hiver
	TimeManager.season = 3
	var seeds := Shops.items("store")
	_check(seeds.has("seed_brussels_sprout") and seeds.has("seed_winter_leek"), "Rosalie vend des graines d'hiver")
	_check(GameData.crop_in_season("brussels_sprout", 3) and GameData.crop_in_season("winter_leek", 3), "choux de Bruxelles et poireaux poussent en hiver")
	_check(Collections.items_of("crops").has("brussels_sprout"), "les cultures d'hiver sont dans l'album")
	# ---- Fleurs semées et cultures mortes au changement de saison
	TimeManager.season = 0
	var bed := Vector2i(20, 16)
	FarmState.till(bed)
	_check(FarmState.plant(bed, "daffodil"), "on sème des bulbes de jonquille sur la terre labourée")
	for d in 5:
		FarmState.water(bed)
		FarmState.advance_day(0, false)
	_check(FarmState.is_mature(bed) and FarmState.harvest(bed) == "daffodil", "la jonquille pousse et se cueille")
	FarmState.till(bed)
	FarmState.plant(bed, "carrot")
	FarmState.water(bed)
	FarmState.advance_day(1, false)
	_check(FarmState.get_crop(bed) == "" and int(FarmState.last_night.season) == 1, "une culture morte au changement de saison est signalée")
	# ---- Scènes de cœur : au moins trois par habitant
	var few: Array = []
	for id: String in GameData.npcs:
		if HeartEvents.events.get(id, []).size() < 3:
			few.append(id)
	_check(few.is_empty(), "chaque habitant a trois scènes de cœur %s" % str(few))
	# ---- Bouton Fabrication en haut de l'écran : nombre de recettes faisables
	var hud: Node = _main.get("_hud")
	var badge: Label = hud.get("_craft_badge")
	Inventory.add_item("wood", 60)
	await get_tree().process_frame
	_check(hud.get("_craft_button") != null and badge.text != "" and int(badge.text) >= 1, "le bouton Fabrication indique les recettes faisables (%s)" % badge.text)
	hud.call("open_journal_menu")
	_check(hud.get("_modal").find_children("*", "Button", true, false).any(func(b: Button) -> bool: return b.text == "Album"), "le Journal regroupe l'album, les succès...")
	hud.call("open_settings", "sound")
	_check(hud.get("_modal").find_children("*", "Button", true, false).any(func(b: Button) -> bool: return b.text.begins_with("Musique")), "les réglages du son ont leur rubrique")
	hud.close_modal()
	# ---- Volumes séparés
	var mv := Settings.music_volume
	Settings.cycle_music_volume()
	_check(Settings.music_volume != mv, "le volume de la musique se règle")
	while Settings.music_volume != 0:
		Settings.cycle_music_volume()
	_check(not Settings.music and Music.current() == "", "à 0 %, la musique est coupée")
	Settings.cycle_music_volume()
	_check(Settings.music, "et elle revient")
	while Settings.music_volume != mv:  # on remet le réglage du joueur
		Settings.cycle_music_volume()
	# ---- Sauvegarde sûre
	SaveManager.save_game()
	SaveManager.save_game()
	var path := SaveManager.slot_path(SaveManager.slot)
	_check(FileAccess.file_exists(path + ".bak"), "une copie de secours est gardée")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{abîmé")
	f.close()
	_check(SaveManager.load_game() and SaveManager.recovered, "une sauvegarde abîmée est récupérée depuis la copie")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  ÉCHEC ") + label)
	if not ok:
		_failures += 1
