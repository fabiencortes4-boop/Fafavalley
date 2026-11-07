extends Node
## Tutoriel guidé des premières minutes : une consigne à la fois dans un
## bandeau ; l'étape passe toute seule dès que le joueur a fait l'action
## (ou si c'est déjà fait). On peut le passer, et le relancer depuis le menu.

signal changed

const STEPS := [
	["move", "Bienvenue à la ferme ! Fais glisser ton doigt sur la moitié gauche de l'écran pour marcher."],
	["mail", "Une lettre t'attend ! Va jusqu'à la boîte aux lettres (le « ! » près de la maison) et touche-la."],
	["till", "Choisis la houe (1re case en bas), puis touche une case d'herbe juste à côté de toi pour labourer."],
	["seed", "Choisis les graines de carotte (3e case) et touche la terre labourée pour semer."],
	["water", "Prends l'arrosoir (2e case) et arrose ta graine : elle pousse chaque jour où elle est arrosée."],
	["story", "Touche le bouton « Histoire » en haut à gauche : il t'indique ta mission."],
	["village", "Va au village : suis le chemin vers l'est, tout à droite de la ferme."],
	["talk", "Touche un habitant pour lui parler. Offre-lui un légume pour gagner son amitié !"],
	["sleep", "Le soir, rentre chez toi et touche ton lit pour dormir. La journée est alors sauvegardée."],
]

var step: int = -1  # étape en cours, -1 = tutoriel inactif
var world: WorldMap  # carte affichée (pour suivre le joueur)
var _events: Dictionary = {}
var _start_cell := Vector2i(-99, -99)
var _start_day: int = 1
var _timer: float = 0.0


func active() -> bool:
	return step >= 0


func start() -> void:
	step = 0
	_events.clear()
	_start_cell = Vector2i(-99, -99)
	_start_day = TimeManager.day
	changed.emit()


func restart() -> void:
	start()


func skip() -> void:
	step = -1
	changed.emit()


## Une action que l'on ne peut pas lire dans l'état du jeu (ouvrir le journal...).
func notify(event: String) -> void:
	_events[event] = true


func text() -> String:
	return "" if step < 0 else str(STEPS[step][1])


func _done(id: String) -> bool:
	match id:
		"move":
			if world == null or not is_instance_valid(world) or world.player == null:
				return false
			var cell := world.player_cell()
			if _start_cell == Vector2i(-99, -99):
				_start_cell = cell
			return absi(cell.x - _start_cell.x) + absi(cell.y - _start_cell.y) >= 3
		"mail":
			return Mail.received.has("welcome") and not Mail.pending.has("welcome")
		"till":
			return not FarmState.tiles.is_empty()
		"seed":
			for c: Vector2i in FarmState.tiles:
				if FarmState.get_crop(c) != "":
					return true
			return false
		"water":
			for c: Vector2i in FarmState.tiles:
				if FarmState.get_crop(c) != "" and FarmState.is_watered(c):
					return true
			return false
		"story":
			return _events.has("story")
		"village":
			return PlayerState.map == "village" or PlayerState.map.begins_with("in:")
		"talk":
			return not Relations.met.is_empty()
		"sleep":
			return TimeManager.day != _start_day
	return true


func _process(delta: float) -> void:
	if step < 0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.4
	var advanced := false
	while step >= 0 and step < STEPS.size() and _done(str(STEPS[step][0])):
		step += 1
		advanced = true
	if not advanced:
		return
	if step >= STEPS.size():
		step = -1
		Sfx.play("levelup")
		EventBus.toast("Tutoriel terminé ! Bonne vie à Valfleur.")
	else:
		Sfx.play("select")
	changed.emit()


func to_dict() -> Dictionary:
	return {"step": step, "start_day": _start_day, "events": _events.keys()}


func from_dict(data: Dictionary) -> void:
	# Ancienne sauvegarde sans tutoriel : on ne l'impose pas
	step = int(data.get("step", -1))
	_start_day = int(data.get("start_day", TimeManager.day))
	_events.clear()
	for e: Variant in data.get("events", []):
		_events[str(e)] = true
	changed.emit()
