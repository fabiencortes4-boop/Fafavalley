extends Node
## Test automatique de la « vie à la ferme » : zoom, débris et outils,
## courrier, cueillette, compétences, saisons, neige, sauvegarde.
##   godot --headless res://tests/life_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var farm: Farm = _main.call("current_map")
	var hud: Hud = _main.get("_hud")
	# Zoom
	_check(is_equal_approx(farm.get("_camera").zoom.x, Settings.zoom), "la caméra applique le zoom réglé (x%s)" % Settings.zoom)
	var before := Settings.zoom
	Settings.cycle_zoom()
	_check(not is_equal_approx(farm.get("_camera").zoom.x, before), "le réglage du zoom change la vue")
	while not is_equal_approx(Settings.zoom, before):
		Settings.cycle_zoom()
	# Jours de la semaine
	_check(TimeManager.weekday() == "Lun.", "le jour 1 est un lundi")
	# Débris
	_check(FarmState.debris.size() >= 100, "la ferme est couverte de débris au départ (%d)" % FarmState.debris.size())
	# Courrier : la lettre de bienvenue apporte hache et faux
	_check(Mail.has_mail(), "une lettre attend dans la boîte")
	hud.open_mail()
	_check(Inventory.count_of("axe") == 1 and Inventory.count_of("scythe") == 1, "la lettre du maire donne la hache et la faux")
	hud.close_modal()
	_check(not Mail.has_mail(), "la boîte est vide après lecture")
	# Défrichage
	var spot := Vector2i(15, 14)
	farm.player.position = farm.cell_center(spot + Vector2i.LEFT)
	farm.player.facing = Vector2i.RIGHT
	for pair in [["weed", "scythe"], ["twig", "axe"], ["stone", "pickaxe"], ["stump", "axe"]]:
		FarmState.debris[spot] = {"type": pair[0], "hp": int(FarmState.DEBRIS[pair[0]].hp)}
		farm.call("_refresh_object", spot)
		_check(not farm.is_walkable(spot), "%s : bloque le passage" % pair[0])
		if Inventory.count_of(pair[1]) == 0:
			Inventory.add_item(pair[1], 1)
		_select(pair[1])
		var energy := PlayerState.energy
		for i in 6:
			if FarmState.debris.has(spot):
				farm.act_on(spot)
		_check(not FarmState.debris.has(spot), "%s : enlevé avec %s" % [pair[0], GameData.item_name(pair[1])])
		if pair[1] == "scythe":
			_check(PlayerState.energy == energy, "la faux ne fatigue pas")
	await get_tree().create_timer(1.5).timeout
	_check(Inventory.count_of("wood") >= 8, "les branches et l'arbre mort donnent du bois (%d)" % Inventory.count_of("wood"))
	_check(Skills.xp.get("foraging", 0) > 0, "défricher fait progresser la cueillette")
	# Hoe refusée sur un débris
	FarmState.debris[spot] = {"type": "stone", "hp": 1}
	_select("hoe")
	farm.act_on(spot)
	_check(not FarmState.is_tilled(spot) and FarmState.debris.has(spot), "on ne laboure pas une case encombrée")
	FarmState.debris.erase(spot)
	# Cueillette
	var forage: Dictionary = farm.get("_forage_sprites")
	_check(forage.size() > 0, "des plantes sauvages poussent à la ferme (%d)" % forage.size())
	var cell: Vector2i = forage.keys()[0]
	var item: String = Forage.spots["farm"]["%d,%d" % [cell.x, cell.y]]
	_check(GameData.item(item).get("type") == "forage" and 0.0 in GameData.item(item).seasons, "elles sont de saison (%s)" % item)
	var count := Inventory.count_of(item)
	farm.act_on(cell)
	_check(Inventory.count_of(item) > count, "on ramasse une plante sauvage")
	# Compétences
	Skills.add_xp("combat", 300)
	_check(Skills.level("combat") == 2 and PlayerState.max_health() == 110, "le combat augmente la vie max (+5 par niveau)")
	# Saisons et neige
	TimeManager.season = 3
	TimeManager.weather = "snow"
	TimeManager.day_started.emit(1, 3, 1)
	await get_tree().process_frame
	var tex: Texture2D = (farm.get("_ground").tile_set.get_source(0) as TileSetAtlasSource).texture
	_check(tex.resource_path.ends_with("world_winter.png"), "l'hiver couvre la ferme de neige")
	_check(farm.get("_weather") != null, "la neige tombe")
	TimeManager.season = 0
	TimeManager.weather = "sunny"
	TimeManager.day_started.emit(1, 0, 1)
	# Sauvegarde
	SaveManager.save_game()
	var debris_count := FarmState.debris.size()
	Skills.reset()
	Mail.reset()
	FarmState.reset()
	SaveManager.load_game()
	_check(Skills.level("combat") == 2, "les compétences sont sauvegardées")
	_check(Mail.received.has("welcome"), "le courrier lu est sauvegardé")
	_check(FarmState.debris.size() == debris_count, "les débris sont sauvegardés")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _select(id: String) -> void:
	for i in Inventory.slots.size():
		if Inventory.slots[i] != null and Inventory.slots[i].id == id:
			if i >= Inventory.HOTBAR:
				Inventory.swap(i, Inventory.HOTBAR - 1)
				i = Inventory.HOTBAR - 1
			Inventory.select(i)
			return


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
