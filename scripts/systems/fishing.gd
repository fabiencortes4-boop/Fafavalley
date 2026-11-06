class_name Fishing
extends Node2D
## Pêche sur une carte : lancer de ligne, attente, touche, puis mini-jeu
## (FishingMinigame, affiché par le HUD). Le poisson est choisi selon le
## lieu, la saison, l'heure et la météo (data/fish.json).

enum State { IDLE, WAITING, BITE, REELING }

const CAST_RANGE := 3
const BITE_WINDOW := 1.0
const WAIT_MIN := 1.5
const WAIT_MAX := 6.0

var map: WorldMap
var state: State = State.IDLE

var _bobber: Sprite2D
var _line: Line2D
var _alert: Sprite2D
var _bobber_base: Vector2
var _timer: float = 0.0
var _time: float = 0.0
var _fish_id: String = ""


func _ready() -> void:
	z_index = 4
	_line = Line2D.new()
	_line.width = 1.0
	_line.default_color = Color(0.95, 0.95, 0.9, 0.8)
	add_child(_line)
	_bobber = Sprite2D.new()
	_bobber.texture = load("res://assets/sprites/bobber.png")
	add_child(_bobber)
	_alert = Sprite2D.new()
	_alert.texture = load("res://assets/sprites/ui_alert.png")
	add_child(_alert)
	_hide_all()


func busy() -> bool:
	return state != State.IDLE


## Case d'eau où lancer, dans la direction du joueur (la plus lointaine).
func _water_target() -> Vector2i:
	var origin := map.player_cell()
	var facing := map.player.facing
	for k in range(CAST_RANGE, 0, -1):
		var cell := origin + facing * k
		if map.is_water(cell):
			return cell
	return Vector2i(-1, -1)


## Lance la ligne. Renvoie false s'il n'y a pas d'eau devant le joueur.
func try_cast(energy: int) -> bool:
	var target := _water_target()
	if target == Vector2i(-1, -1):
		return false
	if not map.spend_energy(energy):
		return true
	_fish_id = GameData.pick_fish(map.map_id)
	state = State.WAITING
	_timer = randf_range(WAIT_MIN, WAIT_MAX)
	map.player.locked = true
	map.player.play_use()
	_bobber_base = Vector2(target * WorldMap.TILE) + Vector2(WorldMap.TILE, WorldMap.TILE) / 2.0
	_bobber.position = _bobber_base
	_bobber.visible = true
	_line.visible = true
	return true


## Bouton Action (ou toucher l'écran) pendant la pêche.
func on_action() -> void:
	match state:
		State.WAITING:
			EventBus.toast("Trop tôt ! Rien n'a mordu.")
			_reset()
		State.BITE:
			state = State.REELING
			_alert.visible = false
			map.hud.start_fishing(_fish_id, _on_minigame_finished)


func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	_time += delta
	var tip := map.player.position + Vector2(map.player.facing) * 6.0 + Vector2(0, -12)
	var dip := 2.0 if state == State.BITE else 0.0
	_bobber.position = _bobber_base + Vector2(0, sin(_time * 3.0) * 0.8 + dip)
	_line.points = PackedVector2Array([tip, (tip + _bobber.position) / 2.0 + Vector2(0, 6), _bobber.position])
	_alert.position = map.player.position + Vector2(0, -26)
	match state:
		State.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				state = State.BITE
				_timer = BITE_WINDOW
				_alert.visible = true
				Input.vibrate_handheld(150)
		State.BITE:
			_timer -= delta
			if _timer <= 0.0:
				EventBus.toast("Le poisson s'est échappé... Sois plus rapide !")
				_reset()


func _on_minigame_finished(success: bool) -> void:
	if success:
		var fish := GameData.fish(_fish_id)
		var sizes: Array = fish.get("size", [10, 30])
		var size := randi_range(int(sizes[0]), int(sizes[1]))
		if not Inventory.can_add(_fish_id):
			EventBus.toast("Inventaire plein : le poisson retourne à l'eau.")
		else:
			Inventory.add_item(_fish_id, 1)
			var result := FishLog.record(_fish_id, size)
			Skills.add_xp("fishing", 8 + int(fish.get("difficulty", 30)) / 6)
			var text := "Tu as pêché : %s (%d cm) !" % [fish.name, size]
			if result == "new":
				text += " Nouvelle espèce !"
			elif result == "record":
				text += " Nouveau record !"
			EventBus.toast(text)
	else:
		EventBus.toast("Le poisson s'est décroché...")
	_reset()


func _reset() -> void:
	state = State.IDLE
	_hide_all()
	if map != null and map.player != null:
		map.player.locked = false


func _hide_all() -> void:
	_bobber.visible = false
	_line.visible = false
	_alert.visible = false
