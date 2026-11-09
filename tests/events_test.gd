extends Node
## Test automatique des événements du village et des intérieurs :
## fête de saison (rassemblement, concours, boutiques fermées), marché du
## samedi, animations de la semaine, lettre d'annonce, intérieurs.
##   godot --headless res://tests/events_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	_check(TimeManager.REAL_SECONDS_PER_TICK >= 5.0 and TimeManager.REAL_SECONDS_PER_TICK <= 6.0, "une journée dure environ 11 minutes (10 min toutes les %.1f s)" % TimeManager.REAL_SECONDS_PER_TICK)
	# ---- Lettre la veille de la Fête des semis
	TimeManager.day = 12
	Mail.check()
	_check(Mail.pending.has("event_spring_fair"), "Bertrand annonce la fête par lettre la veille")
	# ---- Jour de fête
	TimeManager.day = 13
	TimeManager.minutes = 10 * 60
	_check(Events.festival_today().get("id", "") == "spring_fair", "le 13 du printemps, c'est la Fête des semis")
	_check(Events.gathering_now() and not Shops.is_open("store"), "pendant la fête, les boutiques ferment")
	await _go("village", Vector2i(2, 19))
	var v: Village = _main.call("current_map")
	_check(v.npcs.all(func(n: Npc) -> bool: return not n.is_inside()), "tout le village est dehors")
	var on_plaza := v.npcs.filter(func(n: Npc) -> bool: return Rect2i(22, 21, 18, 12).has_point(n.cell()))
	_check(on_plaza.size() == v.npcs.size(), "tout le monde est sur la place (%d/%d)" % [on_plaza.size(), v.npcs.size()])
	_check(v.get("_interactables").get(Events.BOOTH) == "booth", "un stand est installé sur la place")
	_check(Events.booth_activity() == "contest", "le stand propose le concours")
	Inventory.add_item("truffle", 1)
	var gold := Inventory.gold
	var result := Events.enter_contest("truffle")
	_check(result.get("title", "") == "Premier prix" and Inventory.gold == gold + 1000, "une truffe remporte le premier prix (+1000 or)")
	_check(Events.enter_contest("truffle").is_empty(), "un seul passage au concours")
	v.act_on(Vector2i(26, 17))
	await _frames(3)
	_check(_main.call("current_map") == v, "l'épicerie est fermée pendant la fête")
	_main.get("_hud").close_modal()
	# ---- Après la fête, la vie reprend
	TimeManager.minutes = 16 * 60
	_check(not Events.gathering_now(), "la fête se termine à 15h")
	# ---- Marché du samedi
	TimeManager.day = 6
	TimeManager.minutes = 10 * 60
	_check(Events.booth_activity() == "market" and Events.booth_open(), "le samedi matin, marché sur la place")
	_check(Shops.price("market", "iron_ore") == 160 and Shops.items("market").has("truffle"), "le colporteur a ses prix et ses produits rares")
	# ---- Animation de la semaine : pétanque le lundi après-midi
	TimeManager.day = 1
	TimeManager.minutes = 15 * 60
	_check(not Events.place_for("gaston").is_empty() and Events.place_for("rosalie").is_empty(), "lundi 15h : Gaston joue à la pétanque, pas Rosalie")
	await _go("village", Vector2i(2, 19))
	v = _main.call("current_map")
	var gaston: Npc = v.npcs.filter(func(n: Npc) -> bool: return n.id == "gaston")[0]
	_check(gaston.cell().distance_to(Vector2i(33, 24)) < 4.0, "Gaston est au terrain de pétanque (%s)" % gaston.cell())
	# ---- Intérieurs : chaque bâtiment a le sien
	for id: String in InteriorMap.LAYOUTS:
		var m := InteriorMap.new()
		m.setup(id)
		var rows: Array = m.call("_map_rows")
		var width := String(rows[0]).length()
		_check(rows.all(func(r: String) -> bool: return r.length() == width) and String(rows[rows.size() - 1]).contains("D"), "intérieur « %s » bien formé" % id)
		m.free()
	TimeManager.minutes = 11 * 60
	v.act_on(Vector2i(31, 17))
	v.act_on(Vector2i(35, 17))
	await _frames(3)
	var mairie: WorldMap = _main.call("current_map")
	_check(mairie is InteriorMap and mairie.map_id == "in:mairie", "on entre dans la mairie")
	_check((mairie as InteriorMap).residents.any(func(n: Npc) -> bool: return n.id == "bertrand") == false, "Bertrand n'est pas là : il est en ville")
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
