extends Node
## Test automatique du décor du village et du port : place dallée, bancs et
## chaises où l'on s'assoit (repos), infos des graines à la boutique.
##   godot --headless res://tests/decor_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	TimeManager.minutes = 11 * 60
	_main.call("_switch_to", "village")
	await _frames(3)
	var v: Village = _main.call("current_map")
	# La place : dallée autour de la fontaine, bancs tournés vers elle
	_check(v.seats.size() >= 10, "des bancs au village (%d)" % v.seats.size())
	_check(v.seats.get(Vector2i(28, 26)) == Vector2i.RIGHT and v.seats.get(Vector2i(33, 26)) == Vector2i.LEFT, "sur la place, les bancs regardent la fontaine")
	_check(v.seats.get(Vector2i(30, 29)) == Vector2i.UP, "le banc du sud regarde aussi la fontaine")
	var lamps := 0
	for row: String in Village.MAP:
		lamps += row.count("n")
	_check(lamps >= 30, "des lampadaires le long des routes (%d)" % lamps)
	_check(v.action_hint(Vector2i(28, 26)) == "S'asseoir", "le bouton Action propose de s'asseoir")
	# S'asseoir : l'énergie remonte doucement, jusqu'à 80 %
	v.player.position = v.cell_center(Vector2i(29, 26))
	await get_tree().physics_frame
	PlayerState.energy = 40
	PlayerState.heal(0, 0)
	v.act_on(Vector2i(28, 26))
	_check(v.player.seated, "on s'assoit sur le banc")
	_check(v.player.facing == Vector2i.RIGHT, "assis, on regarde la fontaine")
	_check(v.action_hint(Vector2i(29, 26)) == "Se lever", "assis, le bouton Action sert à se lever")
	await get_tree().create_timer(4.0).timeout
	_check(PlayerState.energy > 40, "assis, l'énergie remonte (%d)" % PlayerState.energy)
	PlayerState.energy = int(PlayerState.MAX_ENERGY * 0.8)
	await get_tree().create_timer(2.0).timeout
	_check(PlayerState.energy == int(PlayerState.MAX_ENERGY * 0.8), "le repos ne dépasse pas 80 % (ça ne remplace pas le sommeil)")
	# Bouger relève le joueur, à côté du banc
	Input.action_press("move_right")
	await _frames(3)
	Input.action_release("move_right")
	_check(not v.player.seated, "bouger fait se lever")
	_check(v.is_walkable(v.player_cell()), "debout, on est sur une case libre")
	# Le port : bancs face à la mer, nouveaux décors
	_main.call("_switch_to", "port")
	await _frames(3)
	var port: PortMap = _main.call("current_map")
	_check(port.seats.get(Vector2i(28, 18)) == Vector2i.RIGHT and port.seats.get(Vector2i(4, 24)) == Vector2i.DOWN, "au port, les bancs regardent la mer")
	# La taverne : des chaises autour des tables
	_main.call("_switch_to", "in:taverne")
	await _frames(3)
	var tavern: InteriorMap = _main.call("current_map")
	_check(tavern.seats.size() >= 6 and tavern.seats.get(Vector2i(2, 3)) == Vector2i.DOWN, "des chaises à la taverne, tournées vers les tables")
	# Boutique : temps de pousse affiché, bouton « Acheter x1 »
	var hud: Hud = _main.get("_hud")
	hud.open_shop("store")
	var texts: Array = []
	for n in hud.get("_modal").find_children("*", "", true, false):
		if n is Label:
			texts.append((n as Label).text)
		elif n is Button:
			texts.append((n as Button).text)
	var joined := " | ".join(texts)
	_check(joined.contains("Récolte en 4 jours"), "la boutique indique le temps de pousse des graines")
	_check(joined.contains("tous les"), "et la repousse quand il y en a une")
	_check(joined.contains("Acheter x1") and joined.contains("x5"), "les boutons disent x1 et x5")
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
