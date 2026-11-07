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
var music: bool = true
## Taille du texte : index dans TEXT_SIZES (Normal, Grand, Très grand)
const TEXT_SIZES := [9, 11, 13]
const TEXT_NAMES := ["normal", "grand", "très grand"]
var text_size: int = 1


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		# Clé v2 : le nouveau zoom par défaut s'applique à tout le monde.
		zoom = float(cfg.get_value("affichage", "zoom_v2", DEFAULT_ZOOM))
		sound = bool(cfg.get_value("son", "actif", true))
		view_3d = bool(cfg.get_value("affichage", "vue_3d", true))
		music = bool(cfg.get_value("son", "musique", true))
		text_size = clampi(int(cfg.get_value("affichage", "texte", 1)), 0, TEXT_SIZES.size() - 1)
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


func toggle_music() -> void:
	music = not music
	_save()
	changed.emit()


func cycle_text_size() -> void:
	text_size = (text_size + 1) % TEXT_SIZES.size()
	_save()
	changed.emit()


func font_size() -> int:
	return TEXT_SIZES[text_size]


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("affichage", "zoom_v2", zoom)
	cfg.set_value("son", "actif", sound)
	cfg.set_value("affichage", "vue_3d", view_3d)
	cfg.set_value("son", "musique", music)
	cfg.set_value("affichage", "texte", text_size)
	cfg.save(PATH)
