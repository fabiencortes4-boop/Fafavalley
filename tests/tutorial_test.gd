extends Node
## Test automatique du tutoriel guidé, de la musique d'ambiance et de la
## taille du texte.
##   godot --headless res://tests/tutorial_test.tscn

var _failures := 0
var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.call("_start", false)
	await get_tree().process_frame
	var hud: Hud = _main.get("_hud")
	var farm: Farm = _main.call("current_map")
	# ---- Tutoriel
	_check(Tutorial.step == 0, "une nouvelle partie commence par le tutoriel")
	_check(hud.get("_tutorial_panel").visible, "la consigne s'affiche dans un bandeau")
	await _wait()
	farm.player.position += Vector2(4 * 16, 0)
	await _wait()
	_check(Tutorial.step == 1, "marcher valide la 1re étape")
	Mail.check()
	while Mail.has_mail():
		Mail.open_next()
	await _wait()
	_check(Tutorial.step == 2, "lire la lettre valide l'étape du courrier")
	var cell := Vector2i(12, 14)
	FarmState.till(cell)
	await _wait()
	_check(Tutorial.step == 3, "labourer valide l'étape de la houe")
	FarmState.plant(cell, "carrot")
	FarmState.water(cell)
	await _wait()
	_check(Tutorial.step == 5, "semer puis arroser valident deux étapes d'un coup")
	hud.open_story()
	hud.close_modal()
	await _wait()
	_check(Tutorial.step == 6, "ouvrir le journal de l'histoire")
	# ---- Musique selon le lieu
	_check(Music.current() == "farm", "musique de la ferme (%s)" % Music.current())
	EventBus.map_change_requested.emit("village", Vector2i(2, 19))
	await _frames(3)
	await _wait()
	_check(Tutorial.step == 7, "arriver au village")
	_check(Music.current() == "village", "musique du village")
	Relations.talk("rosalie")
	await _wait()
	_check(Tutorial.step == 8, "parler à un habitant")
	GameFlow.end_day(false)
	hud.close_modal()
	await _wait()
	_check(not Tutorial.active() and not hud.get("_tutorial_panel").visible, "dormir termine le tutoriel")
	await _frames(3)
	_check(Music.current() == "home", "musique de la maison au réveil")
	EventBus.map_change_requested.emit("mine:1", Vector2i.ZERO)
	await _frames(3)
	_check(Music.current() == "mine", "musique de la mine")
	TimeManager.minutes = 21 * 60
	EventBus.map_change_requested.emit("farm", Vector2i(10, 12))
	await _frames(3)
	_check(Music.current() == "night", "musique de nuit le soir")
	Settings.music = true
	Settings.toggle_music()
	_check(Music.current() == "", "on peut couper la musique")
	Settings.toggle_music()
	_check(Music.current() == "night", "et la remettre")
	# ---- Tutoriel relançable, passable
	Tutorial.restart()
	_check(Tutorial.step == 0, "le tutoriel peut être relancé depuis le menu")
	Tutorial.skip()
	_check(not Tutorial.active(), "et passé")
	# ---- Taille du texte
	var before := Settings.font_size()
	Settings.cycle_text_size()
	_check(Settings.font_size() != before and hud.get("_root").theme.default_font_size == Settings.font_size(), "la taille du texte change à la volée")
	while Settings.text_size != 1:
		Settings.cycle_text_size()
	_check(Settings.font_size() > UiTheme.FONT_SIZE, "texte plus grand par défaut (%d au lieu de %d)" % [Settings.font_size(), UiTheme.FONT_SIZE])
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _wait() -> void:
	await get_tree().create_timer(0.5).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
