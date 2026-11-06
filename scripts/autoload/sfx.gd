extends Node
## Bruitages : Sfx.play("dig") joue un son de assets/audio/ (les variantes
## dig_0, dig_1... sont tirées au hasard), avec une légère variation de
## hauteur pour éviter l'effet « machine ». Plusieurs sons en même temps.

const DIR := "res://assets/audio/"
const VOICES := 14
## Volume relatif de chaque son (dB) : les pas et l'eau restent discrets.
const VOLUME := {
	"step": -14.0, "step_stone": -12.0, "water": -6.0, "whoosh": -8.0, "swish": -6.0,
	"click": -6.0, "select": -8.0, "pickup": -6.0, "coins": -4.0, "levelup": -3.0,
	"catch": -3.0, "sleep": -4.0, "cloth": -10.0, "plant": -4.0,
}

var _streams: Dictionary = {}  # nom -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for file in dir.get_files():
		# Dans un export, les fichiers apparaissent en .ogg.import
		var name := file.trim_suffix(".import")
		if not name.ends_with(".ogg"):
			continue
		var stream: AudioStream = load(DIR + name)
		var base := name.trim_suffix(".ogg")
		var parts := base.split("_")
		if parts.size() > 1 and parts[-1].is_valid_int():
			base = "_".join(parts.slice(0, parts.size() - 1))
		if not _streams.has(base):
			_streams[base] = []
		if not stream in _streams[base]:
			_streams[base].append(stream)
	print("[sfx] %d sons chargés" % _streams.size())


func play(name: String, volume_db: float = 0.0, pitch_spread: float = 0.08) -> void:
	if not Settings.sound or not _streams.has(name):
		return
	var variants: Array = _streams[name]
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = variants[randi() % variants.size()]
	p.volume_db = float(VOLUME.get(name, 0.0)) + volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	p.play()


func has(name: String) -> bool:
	return _streams.has(name)
