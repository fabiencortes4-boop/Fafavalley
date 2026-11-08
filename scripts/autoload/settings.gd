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
## Vibrations du téléphone (récolte, coups, récompenses)
var vibration: bool = true
## Accessibilité : qualité marquée par 1, 2 ou 3 points (pas seulement la
## couleur de l'étoile), et vitesse du texte des dialogues
var colorblind: bool = false
const TEXT_SPEEDS := ["lent", "normal", "rapide", "instantané"]
const TEXT_SPEED_FACTOR := [1.7, 1.0, 0.5, 0.0]
var text_speed: int = 1
## Taille du texte : index dans TEXT_SIZES (Normal, Grand, Très grand)
const TEXT_SIZES := [9, 11, 13]
const TEXT_NAMES := ["normal", "grand", "très grand"]
var text_size: int = 1
## Qualité graphique : 0 économie (petits téléphones), 1 normale, 2 élevée.
## Par défaut : normale sur téléphone, élevée sur ordinateur.
const QUALITY_NAMES := ["économie", "normale", "élevée"]
var quality: int = -1


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		# Clé v2 : le nouveau zoom par défaut s'applique à tout le monde.
		zoom = float(cfg.get_value("affichage", "zoom_v2", DEFAULT_ZOOM))
		sound = bool(cfg.get_value("son", "actif", true))
		view_3d = bool(cfg.get_value("affichage", "vue_3d", true))
		music = bool(cfg.get_value("son", "musique", true))
		vibration = bool(cfg.get_value("son", "vibrations", true))
		colorblind = bool(cfg.get_value("accessibilite", "formes", false))
		text_speed = clampi(int(cfg.get_value("accessibilite", "vitesse_texte", 1)), 0, 3)
		text_size = clampi(int(cfg.get_value("affichage", "texte", 1)), 0, TEXT_SIZES.size() - 1)
		quality = int(cfg.get_value("affichage", "qualite", -1))
	if quality < 0 or quality > 2:
		quality = auto_quality()
	if not zoom in ZOOM_LEVELS:
		zoom = DEFAULT_ZOOM
	apply_quality.call_deferred()


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


## Qualité conseillée pour cet appareil.
static func auto_quality() -> int:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return 1
	return 2


func cycle_quality() -> void:
	quality = (quality + 2) % 3  # élevée -> normale -> économie -> élevée
	_save()
	apply_quality()
	changed.emit()
	view_changed.emit()  # la vue 3D se reconstruit avec la nouvelle qualité


## Applique la qualité : images par seconde (batterie), résolution 3D,
## lissage des bords.
func apply_quality() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Engine.max_fps = [30, 30, 60][quality]
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	vp.scaling_3d_scale = [0.65, 0.85, 1.0][quality]


func toggle_music() -> void:
	music = not music
	_save()
	changed.emit()


func toggle_colorblind() -> void:
	colorblind = not colorblind
	GameData.clear_quality_icons()
	_save()
	changed.emit()


func cycle_text_speed() -> void:
	text_speed = (text_speed + 1) % TEXT_SPEEDS.size()
	_save()
	changed.emit()


func toggle_vibration() -> void:
	vibration = not vibration
	_save()
	changed.emit()
	vibrate(40)


## Petite vibration (téléphone uniquement). Les vibrations rapprochées sont
## fusionnées pour ne pas « bourdonner ».
var _last_vibration: int = -1000


func vibrate(ms: int) -> void:
	if not vibration or DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec()
	if now - _last_vibration < 60:
		return
	_last_vibration = now
	Input.vibrate_handheld(ms)


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
	cfg.set_value("son", "vibrations", vibration)
	cfg.set_value("accessibilite", "formes", colorblind)
	cfg.set_value("accessibilite", "vitesse_texte", text_speed)
	cfg.set_value("affichage", "texte", text_size)
	cfg.set_value("affichage", "qualite", quality)
	cfg.save(PATH)
