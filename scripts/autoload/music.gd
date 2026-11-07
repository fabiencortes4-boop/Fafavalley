extends Node
## Musique d'ambiance (assets/music/, créations originales) : un morceau par
## lieu, la nuit au calme, la fête au village ; fondu enchaîné entre deux.

const VOLUME_DB := -10.0
const FADE := 1.5

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _track: String = ""
var _streams: Dictionary = {}
var _map_id: String = ""


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	Settings.changed.connect(_refresh)
	TimeManager.time_changed.connect(func(_h: int, _m: int) -> void: _refresh())


## Le lieu a changé (appelé à chaque chargement de carte).
func set_place(map_id: String) -> void:
	_map_id = map_id
	_refresh()


## Morceau qui convient au lieu, à l'heure et aux événements.
func track_for(map_id: String) -> String:
	var hour := TimeManager.minutes / 60
	if map_id.begins_with("mine:"):
		return "mine"
	if map_id == "in:taverne" and hour >= 18:
		return "festival"  # musique et chansons à la taverne le soir
	if map_id == "home" or map_id.begins_with("in:"):
		return "home"
	if map_id == "village" and Events.gathering_now():
		return "festival"
	if hour >= 20 or hour < 5:
		return "night"
	return "village" if map_id in ["village", "port"] else "farm"


func _refresh() -> void:
	if _map_id == "":
		return
	play(track_for(_map_id) if Settings.music else "")


func play(track: String) -> void:
	if track == _track:
		return
	_track = track
	var old := _players[_active]
	_fade(old, -80.0, true)
	if track == "":
		return
	_active = 1 - _active
	var p := _players[_active]
	p.stream = _stream(track)
	if p.stream == null:
		return
	p.volume_db = -40.0
	p.play()
	_fade(p, VOLUME_DB, false)


func current() -> String:
	return _track


func _fade(p: AudioStreamPlayer, to_db: float, stop_after: bool) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, FADE)
	if stop_after:
		tw.tween_callback(p.stop)


func _stream(track: String) -> AudioStream:
	if not _streams.has(track):
		var path := "res://assets/music/%s.ogg" % track
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_streams[track] = s
	return _streams[track]
