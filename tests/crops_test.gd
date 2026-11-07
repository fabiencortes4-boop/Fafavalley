extends Node
## Test automatique des cultures : chacune a ses graines, sa récolte, ses
## images, pousse jusqu'à maturité, repousse si prévu, et s'affiche en 3D.
##   godot --headless res://tests/crops_test.tscn

var _failures := 0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.call("_start", false)
	await get_tree().process_frame
	_check(GameData.crops.size() >= 24, "%d cultures (au moins 24)" % GameData.crops.size())
	var icons := (load("res://assets/sprites/icons.png") as Texture2D).get_width() / 16
	var rows := (load("res://assets/sprites/crops.png") as Texture2D).get_height() / 16
	var per_season := [0, 0, 0, 0]
	var problems: Array = []
	for crop: String in GameData.crops:
		var c := GameData.crop(crop)
		var seed := ""
		for id: String in GameData.items:
			if GameData.item(id).get("crop") == crop:
				seed = id
		var harvest := str(c.get("harvest", ""))
		if seed == "" or not GameData.items.has(harvest):
			problems.append("%s : graines ou récolte manquantes" % crop)
			continue
		if int(GameData.item(seed).icon) >= icons or int(GameData.item(harvest).icon) >= icons:
			problems.append("%s : icône hors de l'image" % crop)
		if int(c.sprite_row) >= rows:
			problems.append("%s : pas d'image de croissance" % crop)
		if int(GameData.item(harvest).get("sell", 0)) <= int(GameData.item(seed).get("buy", 0)) / 2:
			problems.append("%s : la récolte ne rapporte rien" % crop)
		for sn: Variant in c.seasons:
			per_season[int(sn)] += 1
		# Pousse jusqu'à maturité (arrosée chaque jour, dans sa saison)
		var cell := Vector2i(5, 20)
		FarmState.tiles.clear()
		FarmState.till(cell)
		FarmState.plant(cell, crop)
		var season := int(c.seasons[0])
		var days := 0
		while not FarmState.is_mature(cell) and days < 20:
			FarmState.water(cell)
			FarmState.advance_day(season, false)
			days += 1
		var total := 0
		for d: Variant in c.stage_days:
			total += int(d)
		if not FarmState.is_mature(cell) or days != total:
			problems.append("%s : mûre en %d jours au lieu de %d" % [crop, days, total])
			continue
		# Rendu 3D à chaque stade
		if View3D.current != null:
			for stage in 4:
				var node: Node3D = View3D.current.call("_crop_model", crop, stage)
				if node == null:
					problems.append("%s : pas de modèle 3D au stade %d" % [crop, stage])
				else:
					node.free()
		var got := FarmState.harvest(cell)
		if got != harvest:
			problems.append("%s : récolte « %s »" % [crop, got])
		if int(c.get("regrow", 0)) > 0 and FarmState.get_crop(cell) != crop:
			problems.append("%s : devrait repousser" % crop)
	for p: String in problems:
		print("     ", p)
	_check(problems.is_empty(), "toutes les cultures poussent, se récoltent et s'affichent")
	_check(per_season.all(func(n: int) -> bool: return n >= 2), "des cultures en toute saison, hiver compris (%s)" % [per_season])
	var shop: Array = Shops.items("store")
	_check(GameData.crop_in_season(str(GameData.item(shop[0]).crop), TimeManager.season), "l'épicerie présente d'abord les graines de saison")
	_check(Crafting.recipes.has("ratatouille") and Crafting.recipes.has("pumpkin_soup"), "de nouvelles recettes avec les nouvelles cultures")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
