extends Node
## Sauvegarde JSON dans user://. Sauvegarde aussi automatiquement quand
## l'application passe en arrière-plan (indispensable sur mobile).

const SAVE_PATH := "user://fafavalley_save_v2.json"  # v2 : objets Kenney
const SAVE_VERSION := 2


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
	return true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if GameFlow.in_game:
				save_game()
