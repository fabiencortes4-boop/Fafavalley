extends Node
## Réglages du joueur (enregistrés à part de la partie) : zoom de la caméra.

const PATH := "user://settings.cfg"
## Zoom : 2 montre environ 15 cases de large, vue rapprochée sur le personnage.
const ZOOM_LEVELS := [1.25, 1.5, 2.0, 2.5]
const DEFAULT_ZOOM := 2.0

signal changed
signal view_changed

var zoom: float = DEFAULT_ZOOM
var sound: bool = true
var view_3d: bool = true


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		# Clé v2 : le nouveau zoom par défaut s'applique à tout le monde.
		zoom = float(cfg.get_value("affichage", "zoom_v2", DEFAULT_ZOOM))
		sound = bool(cfg.get_value("son", "actif", true))
		view_3d = bool(cfg.get_value("affichage", "vue_3d", true))
	if not zoom in ZOOM_LEVELS:
		zoom = DEFAULT_ZOOM


func cycle_zoom() -> void:
	var index := ZOOM_LEVELS.find(zoom)
	zoom = ZOOM_LEVELS[(index + 1) % ZOOM_LEVELS.size()]
	_save()
	changed.emit()


func toggle_view() -> void:
	view_3d = not view_3d
	_save()
	view_changed.emit()


func toggle_sound() -> void:
	sound = not sound
	_save()
	changed.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("affichage", "zoom_v2", zoom)
	cfg.set_value("son", "actif", sound)
	cfg.set_value("affichage", "vue_3d", view_3d)
	cfg.save(PATH)
