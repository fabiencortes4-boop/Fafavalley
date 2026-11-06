extends Node
## Réglages du joueur (enregistrés à part de la partie) : zoom de la caméra.

const PATH := "user://settings.cfg"
## Zoom : 1.5 montre environ 20 cases de large, comme les jeux de ferme sur mobile.
const ZOOM_LEVELS := [1.0, 1.25, 1.5, 2.0]
const DEFAULT_ZOOM := 1.5

signal changed

var zoom: float = DEFAULT_ZOOM


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		zoom = float(cfg.get_value("affichage", "zoom", DEFAULT_ZOOM))


func cycle_zoom() -> void:
	var index := ZOOM_LEVELS.find(zoom)
	zoom = ZOOM_LEVELS[(index + 1) % ZOOM_LEVELS.size()]
	_save()
	changed.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("affichage", "zoom", zoom)
	cfg.save(PATH)
