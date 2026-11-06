extends Node
## Sauvegarde JSON dans user://. Sauvegarde aussi automatiquement quand
## l'application passe en arrière-plan (indispensable sur mobile).

const SAVE_PATH := "user://fafavalley_save_v2.json"  # v2 : objets Kenney
const SAVE_VERSION := 2
## Sur le web (iPhone), le navigateur peut fermer le jeu sans prévenir :
## on sauvegarde aussi régulièrement.
const WEB_AUTOSAVE_SECONDS := 45.0

var _autosave_timer: float = 0.0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


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
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Sauvegarde impossible : %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
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
