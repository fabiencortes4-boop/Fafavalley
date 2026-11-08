extends Node
## Sauvegarde JSON dans user://. Sauvegarde aussi automatiquement quand
## l'application passe en arrière-plan (indispensable sur mobile).

const SAVE_PATH := "user://fafavalley_save_v2.json"  # v2 : objets Kenney
const SAVE_VERSION := 2
## Sur le web (iPhone), le navigateur peut fermer le jeu sans prévenir :
## on sauvegarde aussi régulièrement.
const WEB_AUTOSAVE_SECONDS := 45.0

var _autosave_timer: float = 0.0


## Emplacement de sauvegarde (0 à 2). Le 0 garde le fichier historique.
const SLOTS := 3
var slot: int = 0


static func slot_path(s: int) -> String:
	return SAVE_PATH if s == 0 else "user://fafavalley_save_v2_s%d.json" % s


func has_save(s: int = -1) -> bool:
	return FileAccess.file_exists(slot_path(slot if s < 0 else s))


## Résumé d'une sauvegarde pour l'écran titre : {} si l'emplacement est vide.
func summary(s: int) -> Dictionary:
	if not has_save(s):
		return {}
	var file := FileAccess.open(slot_path(s), FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return {}
	var p: Dictionary = data.get("player", {})
	var t: Dictionary = data.get("time", {})
	var seasons := ["printemps", "été", "automne", "hiver"]
	return {
		"name": str(p.get("name", "Fermier")), "farm": str(p.get("farm_name", "La ferme")),
		"date": "%s %d, année %d" % [seasons[int(t.get("season", 0)) % 4], int(t.get("day", 1)), int(t.get("year", 1))],
		"gold": int(data.get("inventory", {}).get("gold", 0)),
	}


## Export : la sauvegarde en texte (compressée, base64), à copier ailleurs.
func export_text() -> String:
	save_game()
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return ""
	var raw := file.get_as_text().to_utf8_buffer()
	return "FAFA1:" + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP)) + ":" + str(raw.size())


## Import : écrit la partie dans l'emplacement `s`. Renvoie true si valide.
func import_text(text: String, s: int) -> bool:
	text = text.strip_edges()
	var parts := text.split(":")
	if parts.size() != 3 or parts[0] != "FAFA1":
		return false
	var packed := Marshalls.base64_to_raw(parts[1])
	var raw := packed.decompress(int(parts[2]), FileAccess.COMPRESSION_GZIP)
	var data: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not data is Dictionary or not data.has("time") or not data.has("player"):
		return false
	var file := FileAccess.open(slot_path(s), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(raw.get_string_from_utf8())
	return true


func save_game() -> void:
	EventBus.before_save.emit()
	var data := {
		"version": SAVE_VERSION,
		"time": TimeManager.to_dict(),
		"inventory": Inventory.to_dict(),
		"farm": FarmState.to_dict(),
		"player": PlayerState.to_dict(),
		"relations": Relations.to_dict(),
		"fish_log": FishLog.to_dict(),
		"skills": Skills.to_dict(),
		"mail": Mail.to_dict(),
		"forage": Forage.to_dict(),
		"animals": Animals.to_dict(),
		"story": Story.to_dict(),
		"events": Events.to_dict(),
		"tutorial": Tutorial.to_dict(),
		"quests": Quests.to_dict(),
		"hearts_seen": HeartEvents.to_dict(),
		"marriage": Marriage.to_dict(),
		"port_story": PortStory.to_dict(),
		"collections": Collections.to_dict(),
		"machines": Machines.to_dict(),
		"tips": Tips.to_dict(),
		"achievements": Achievements.to_dict(),
	}
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Sauvegarde impossible : %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_error("Sauvegarde corrompue")
		return false
	TimeManager.from_dict(data.get("time", {}))
	Inventory.from_dict(data.get("inventory", {}))
	FarmState.from_dict(data.get("farm", {}))
	PlayerState.from_dict(data.get("player", {}))
	Relations.from_dict(data.get("relations", {}))
	FishLog.from_dict(data.get("fish_log", {}))
	Skills.from_dict(data.get("skills", {}))
	Mail.from_dict(data.get("mail", {}))
	Forage.from_dict(data.get("forage", {}))
	Animals.from_dict(data.get("animals", {}))
	Story.from_dict(data.get("story", {}))
	Events.from_dict(data.get("events", {}))
	Tutorial.from_dict(data.get("tutorial", {}))
	Quests.from_dict(data.get("quests", {}))
	Collections.from_dict(data.get("collections", {}))
	if not data.has("collections"):
		# Ancienne partie : l'album part de ce que le joueur possède déjà
		for slot: Variant in Inventory.slots:
			if slot != null:
				Collections.discover(str(slot.id))
		for id: String in FishLog.caught:
			Collections.discover(id)
	Achievements.from_dict(data.get("achievements", {}))
	Machines.from_dict(data.get("machines", {}))
	Tips.from_dict(data.get("tips", {}))
	HeartEvents.from_dict(data.get("hearts_seen", {}))
	Marriage.from_dict(data.get("marriage", {}))
	PortStory.from_dict(data.get("port_story", {}))
	return true


func _process(delta: float) -> void:
	if not OS.has_feature("web") or not GameFlow.in_game or get_tree().paused:
		return
	_autosave_timer += delta
	if _autosave_timer >= WEB_AUTOSAVE_SECONDS:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if GameFlow.in_game:
				save_game()
