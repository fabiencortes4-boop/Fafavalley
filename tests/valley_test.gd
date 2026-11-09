extends Node
## Test automatique de la vallée vivante : rénovations visibles (chantier
## de 3 jours, pont praticable), habitant malade, mariage de Jules et Nina,
## nouvelle meunière, nuits spéciales (météorite, lucioles), saisons
## (flaques, arc-en-ciel, neige), astuces et ferme parfaite.
##   godot --headless res://tests/valley_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	Tutorial.skip()
	var hud: Node = _main.get("_hud")
	# ---- Astuces : chaque nouveauté a son explication
	for id: String in ["weather", "scarecrow", "hybrid", "bees", "challenge", "rumor", "projects", "fossil", "pet", "garden", "photo", "cave", "meteor", "perfection"]:
		_check(Tips.tips.has(id), "astuce « %s »" % id)
	# ---- Rénovations : chantier puis bâtiment
	Inventory.add_gold(30000)
	for e: Array in [["wood", 370], ["stone", 140], ["hardwood", 10], ["copper_ore", 10], ["iron_ore", 10]]:
		Inventory.add_item(e[0], e[1])
	_check(Projects.state("bridge") == "ruin", "le vieux pont est en ruine")
	var bridge: Vector2i = Projects.SITES.bridge.position + Vector2i(3, 0)
	_main.call("_switch_to", "village")
	await get_tree().process_frame
	var v: Village = _main.call("current_map")
	_check(not v.is_walkable(bridge) and v.is_water(bridge), "on ne traverse pas l'étang sans pont")
	_check(not v.is_walkable(Projects.SITES.mill.position), "les ruines du moulin occupent leurs cases")
	for id: String in Projects.PROJECTS:
		Projects.fund(id)
	_check(Projects.state("bridge") == "works" and Projects.days_left("bridge") == Projects.WORK_DAYS, "les travaux durent %d jours" % Projects.WORK_DAYS)
	_main.call("_switch_to", "farm")
	await get_tree().process_frame
	for i in Projects.WORK_DAYS:
		GameFlow.end_day()
		await get_tree().process_frame
	_check(Projects.done.size() == 3, "les trois chantiers sont terminés")
	_main.call("_switch_to", "village")
	await get_tree().process_frame
	v = _main.call("current_map")
	_check(v.is_walkable(bridge) and not v.is_water(bridge), "le pont réparé se traverse")
	_check(v.is_water(bridge + Vector2i.UP), "et l'on pêche de part et d'autre")
	# ---- La nouvelle meunière arrive deux jours après le moulin
	_check(VillageLife.arrival_day > 0 and not VillageLife.arrived, "une meunière est annoncée")
	_main.call("_switch_to", "farm")
	await get_tree().process_frame
	for i in 2:
		GameFlow.end_day()
		await get_tree().process_frame
	_check(VillageLife.arrived and GameData.npcs.has("pauline"), "Pauline s'installe à Valfleur")
	_main.call("_switch_to", "village")
	await get_tree().process_frame
	v = _main.call("current_map")
	var pauline := v.npcs.filter(func(n: Npc) -> bool: return n.id == "pauline")
	_check(pauline.size() == 1, "elle vit au village")
	_check(pauline.size() == 1 and pauline[0].home_cell == Vector2i(49, 5), "et rentre le soir au moulin")
	_check(ResourceLoader.exists("res://assets/sprites/portraits/pauline.png"), "elle a son portrait")
	var saved := VillageLife.to_dict()
	VillageLife.reset()
	_check(not GameData.npcs.has("pauline"), "nouvelle partie : pas encore de meunière")
	VillageLife.from_dict(saved)
	_check(GameData.npcs.has("pauline"), "la sauvegarde la garde")
	# ---- Un habitant malade
	VillageLife.fall_sick("lina")
	_check(Npc.is_home_at("lina", 12 * 60), "Lina garde le lit, même à midi")
	_check(VillageLife.talk("lina").contains("Atchoum"), "elle a attrapé froid")
	Inventory.add_item("vegetable_soup", 1)
	Inventory.select(Inventory.slots.find(Inventory.slots.filter(func(sl: Variant) -> bool: return sl != null and sl.id == "vegetable_soup")[0]))
	var pts := int(Relations.points.get("lina", 0))
	var thanks := VillageLife.talk("lina")
	_check(thanks.contains("soupe") or thanks.contains("plat"), "un plat chaud lui fait plaisir")
	_check(int(Relations.points.get("lina", 0)) >= pts + VillageLife.SICK_THANKS and Inventory.count_of("vegetable_soup") == 0, "et touche son cœur")
	GameFlow.end_day()
	await get_tree().process_frame
	_check(VillageLife.sick == "", "le lendemain, Lina est guérie")
	# ---- Le mariage de Jules et Nina
	Story.chapter = maxi(Story.chapter, 2)
	VillageLife.wedding_day = 0
	GameFlow.end_day()
	await get_tree().process_frame
	_check(VillageLife.wedding_day > Marriage.day_number(), "un mariage est annoncé (le %s)" % VillageLife.date_text(VillageLife.wedding_day))
	while Marriage.day_number() < VillageLife.wedding_day:
		GameFlow.end_day()
		await get_tree().process_frame
	TimeManager.minutes = 11 * 60
	var fest := Events.festival_today()
	_check(str(fest.get("activity", "")) == "wedding" and Events.gathering_now(), "le jour J, tout le village est sur la place")
	_main.call("_switch_to", "village")
	await get_tree().process_frame
	v = _main.call("current_map")
	_check(v.npcs.any(func(n: Npc) -> bool: return n.id == "nina"), "Nina vient du port pour l'occasion")
	pts = int(Relations.points.get("jules", 0))
	Inventory.add_item("emerald", 2)
	_check(VillageLife.give_wedding_gift("emerald") and int(Relations.points.get("jules", 0)) > pts, "un cadeau aux mariés")
	_check(not VillageLife.give_wedding_gift("emerald"), "un seul cadeau")
	GameFlow.end_day()
	await get_tree().process_frame
	_check(VillageLife.wedded, "Jules et Nina sont mariés")
	# ---- Nuits spéciales
	_main.call("_switch_to", "farm")
	await get_tree().process_frame
	var before := FarmState.debris.size()
	NightSky.meteor_night = true
	GameFlow.end_day()
	await get_tree().process_frame
	var rock := Vector2i(-1, -1)
	for c: Vector2i in FarmState.debris:
		if FarmState.debris[c].type == "meteorite":
			rock = c
	_check(rock != Vector2i(-1, -1) and FarmState.debris.size() >= before, "une météorite est tombée à la ferme")
	_main.call("_switch_to", "farm")
	await get_tree().process_frame
	var farm: Farm = _main.call("current_map")
	Inventory.remove_item("wood", Inventory.count_of("wood"))
	Inventory.add_item("pickaxe", 1)
	Inventory.select(Inventory.slots.find(Inventory.slots.filter(func(sl: Variant) -> bool: return sl != null and sl.id == "pickaxe")[0]))
	PlayerState.energy = 200
	for i in 8:
		farm.call("_hit_debris", rock, "pickaxe", 0)
	_check(not FarmState.debris.has(rock), "elle se casse à la pioche")
	TimeManager.season = 1
	TimeManager.day = 7
	TimeManager.weather = "sunny"
	NightSky.plan_tonight()
	TimeManager.minutes = 21 * 60
	_check(NightSky.firefly_night and NightSky.fireflies_now(), "en été, une nuit de lucioles")
	TimeManager.minutes = 12 * 60
	_check(not NightSky.fireflies_now(), "elles ne sortent que la nuit")
	# ---- Saisons : flaques, arc-en-ciel, neige
	TimeManager.rain_yesterday = true
	TimeManager.minutes = 9 * 60
	_check(TimeManager.puddles_now() and TimeManager.rainbow_now(), "le soleil après la pluie : flaques et arc-en-ciel")
	TimeManager.minutes = 15 * 60
	_check(not TimeManager.puddles_now() and not TimeManager.rainbow_now(), "l'après-midi, tout a séché")
	TimeManager.season = 3
	TimeManager.day = 1
	var first := View3D.snow_cover()
	TimeManager.day = 10
	var middle := View3D.snow_cover()
	TimeManager.day = 28
	var last := View3D.snow_cover()
	_check(first < middle and last < middle and middle == 1.0, "la neige tient peu à peu, puis fond (%.2f, %.2f, %.2f)" % [first, middle, last])
	TimeManager.season = 1
	# ---- Mini-carte en temps réel
	_main.call("_switch_to", "farm")
	await get_tree().process_frame
	var mm: Minimap = hud.get("_minimap")
	var spot := Vector2i(14, 14)
	FarmState.debris.erase(spot)
	FarmState.objects.erase(spot)
	FarmState.tiles.erase(spot)
	mm.refresh()
	FarmState.till(spot)
	mm.refresh()
	_check(_near(mm._image.get_pixelv(spot), Farm.MAP_COLORS.soil), "mini-carte : le sillon apparaît aussitôt")
	FarmState.plant(spot, "parsnip" if GameData.crops.has("parsnip") else GameData.crops.keys()[0])
	mm.refresh()
	_check(_near(mm._image.get_pixelv(spot), Farm.MAP_COLORS.crop), "puis la culture plantée")
	FarmState.tiles.erase(spot)
	FarmState.place_object(spot, "garden_fountain")
	mm.refresh()
	_check(_near(mm._image.get_pixelv(spot), Farm.MAP_COLORS.decor), "un décor posé se voit sur le plan")
	FarmState.objects.erase(spot)
	FarmState.add_fence(FarmState.edge_between(spot, spot + Vector2i.RIGHT))
	_check(not (_main.call("current_map") as WorldMap).minimap_lines().is_empty(), "les clôtures sont tracées sur la mini-carte")
	_main.call("_switch_to", "village")
	await get_tree().process_frame
	mm.refresh()
	_check(_near(mm._image.get_pixelv(Projects.SITES.bridge.position + Vector2i(2, 0)), Color(0.62, 0.44, 0.27)), "le pont rénové se voit au-dessus de l'étang")
	# ---- La ferme parfaite
	_check(Perfection.percent() < 100 and not Perfection.check(), "la ferme n'est pas encore parfaite (%d %%)" % Perfection.percent())
	for id: String in Collections._category_of:
		Collections.found[id] = true
	for id: String in GameData.npcs:
		Relations.points[id] = Relations.POINTS_PER_HEART * 8
	Story.chapter = Story.chapters.size()
	for p: String in Museum.PIECES:
		Museum.donated[p] = true
	for s: String in Skills.NAMES:
		Skills.xp[s] = 99999
	PlayerState.flags["cave_chest"] = true
	YearReview.history.append([1, 5])
	_check(Perfection.percent() == 100, "tous les domaines à 100 %")
	_check(Perfection.check() and PlayerState.flags.has("perfection"), "la ferme parfaite !")
	_check(Mail.custom.has("perfection"), "le village envoie la statue dorée")
	hud.call("open_perfection")
	await get_tree().process_frame
	hud.call("close_modal")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


## Couleurs de la mini-carte (stockées sur 8 bits) : à peu près égales.
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  ÉCHEC ") + label)
	if not ok:
		_failures += 1
