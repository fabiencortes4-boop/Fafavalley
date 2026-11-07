extends Node
## Test automatique du port du Héron : passage depuis le village, nouveaux
## villageois, soirées à la taverne (20h-23h30), boutiques, chapitre du phare.
##   godot --headless res://tests/port_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	Tutorial.skip()
	var hud: Hud = _main.get("_hud")
	# ---- Du village au port, par la route de l'est
	TimeManager.minutes = 10 * 60
	await _go("village", Vector2i(57, 19))
	var v: Village = _main.call("current_map")
	_check(not v.npcs.any(func(n: Npc) -> bool: return n.id in ["marius", "nina", "basile", "celeste"]), "les gens du port n'habitent pas au village")
	v.player.position = v.cell_center(Vector2i(59, 19))
	await get_tree().physics_frame
	await _frames(3)
	var port: WorldMap = _main.call("current_map")
	_check(port is PortMap, "la route de l'est mène au port du Héron")
	_check((port as PortMap).npcs.size() == 4, "4 nouveaux villageois au port")
	var nina: Npc = (port as PortMap).npcs.filter(func(n: Npc) -> bool: return n.id == "nina")[0]
	_check(not nina.is_inside(), "à 10h, Nina est dehors")
	# ---- Chapitre du phare : étape 1, Marius
	var said := [""]
	EventBus.dialogue_requested.connect(func(id: String, text: String) -> void: said[0] = id + ":" + text)
	var marius: Npc = (port as PortMap).npcs.filter(func(n: Npc) -> bool: return n.id == "marius")[0]
	port.talk_to_npc(marius)
	hud.close_modal()
	_check(PortStory.step == 1 and said[0].contains("Firmin"), "Marius raconte Firmin : le chapitre du phare commence")
	# Étape 2 : 40 bois à Nina
	port.talk_to_npc(nina)
	hud.close_modal()
	_check(PortStory.step == 1, "sans le bois, rien ne se passe")
	Inventory.add_item("wood", 40)
	port.talk_to_npc(nina)
	hud.close_modal()
	_check(PortStory.step == 2 and Inventory.count_of("wood") == 0, "Nina reçoit le bois pour l'escalier")
	Inventory.add_item("quartz", 3)
	Inventory.add_item("copper_ore", 5)
	Relations.talked_today.clear()
	port.talk_to_npc(nina)
	hud.close_modal()
	_check(PortStory.step == 3, "la lentille : quartz et cuivre")
	Story.bump("fish", 5)
	port.talk_to_npc(marius)
	hud.close_modal()
	_check(PortStory.step == 4 and Crafting.is_unlocked("fish_stew") == false, "5 poissons pour Marius ; il reste à allumer le phare")
	var lighthouse := PortMap.door_front("phare") + Vector2i.UP
	port.act_on(lighthouse)
	hud.close_modal()
	_check(PortStory.step == 4, "le phare ne s'allume que le soir")
	TimeManager.minutes = 21 * 60
	var gold := Inventory.gold
	port.act_on(lighthouse)
	hud.close_modal()
	_check(PortStory.finished() and PortStory.lighthouse_lit(), "après 20h, on rallume le phare !")
	_check(Inventory.gold == gold + 2000 and Crafting.is_unlocked("fish_stew"), "récompense : 2000 or et la soupe du marin")
	# ---- La taverne le soir
	_check(Npc.place_at("rosalie", 21 * 60) == "tavern" and Npc.place_at("rosalie", 23 * 60 + 40) == "", "Rosalie va à la taverne de 20h à 23h30")
	_check(Npc.place_at("odette", 21 * 60) == "", "Odette reste chez elle")
	await _go("in:taverne", Vector2i(6, 8))
	var tavern: InteriorMap = _main.call("current_map")
	var ids := tavern.residents.map(func(n: Npc) -> String: return n.id)
	_check(ids.has("marius") and ids.has("rosalie") and ids.has("gaston") and ids.has("celeste") and ids.has("nina"), "à 21h, la taverne est pleine (%d personnes)" % ids.size())
	_check(Music.current() == "festival", "musique de fête à la taverne le soir")
	var opened := [""]
	EventBus.shop_opened.connect(func(id: String) -> void: opened[0] = id)
	tavern.act_on(Vector2i(3, 2))
	hud.close_modal()
	_check(opened[0] == "tavern", "Marius sert au comptoir")
	# ---- Village : le soir, les habitants partent vers le port
	TimeManager.minutes = 19 * 60 + 50
	await _go("village", Vector2i(30, 19))
	v = _main.call("current_map")
	var gaston: Npc = v.npcs.filter(func(n: Npc) -> bool: return n.id == "gaston")[0]
	TimeManager.minutes = 20 * 60
	TimeManager.time_changed.emit(20, 0)
	await get_tree().create_timer(1.0).timeout
	_check(gaston.get("_going_home") and not gaston.get("_path").is_empty(), "à 20h, Gaston prend la route du port")
	_check(GameData.fishes.values().filter(func(f: Dictionary) -> bool: return "port" in f.places).size() >= 5, "on pêche au bout des pontons")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _go(map_id: String, cell: Vector2i) -> void:
	EventBus.map_change_requested.emit(map_id, cell)
	await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
