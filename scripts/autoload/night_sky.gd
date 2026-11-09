extends Node
## Nuits spéciales :
## - pluie d'étoiles filantes (après 21h) : le lendemain matin, une météorite
##   est souvent tombée dans un coin de la ferme (à casser à la pioche) ;
## - nuit des lucioles (été, après 20h) : elles dansent au-dessus de l'eau.

signal changed

const METEOR_CHANCE := 0.05
const FIREFLY_CHANCE := 0.2
const METEORITE_CHANCE := 0.7
const METEOR_HOURS := [21, 26]  # de 21h à 2h du matin
const FIREFLY_HOURS := [20, 25]

var meteor_night: bool = false  # ce soir
var firefly_night: bool = false
## Pas de hasard pendant les tests automatiques
var random_events: bool = DisplayServer.get_name() != "headless"


func reset() -> void:
	meteor_night = false
	firefly_night = false


## Le matin : la nuit passée a-t-elle laissé une météorite ? Puis on
## décide de la nuit qui vient (selon le temps du jour).
func new_day() -> void:
	if meteor_night and (not random_events or randf() < METEORITE_CHANCE):
		land_meteorite()
	plan_tonight()


func plan_tonight() -> void:
	var clear := not TimeManager.is_raining() and not TimeManager.is_snowing()
	var s := TimeManager.season
	var d := TimeManager.day
	# La première pluie d'étoiles est garantie (été, jour 14 de la 1re année)
	meteor_night = clear and ((s == 1 and d == 14 and TimeManager.year == 1) or (random_events and randf() < METEOR_CHANCE))
	firefly_night = clear and s == 1 and not meteor_night and (d in [7, 21] or (random_events and randf() < FIREFLY_CHANCE))
	changed.emit()


## Une météorite dans un coin d'herbe libre de la ferme.
func land_meteorite() -> Vector2i:
	var wild: Array = FarmState._wild_cells()
	var free: Array = wild.filter(func(c: Vector2i) -> bool: return FarmState._is_free_wild(c, wild))
	if free.is_empty():
		return Vector2i(-1, -1)
	var cell: Vector2i = free[randi() % free.size()]
	FarmState.debris[cell] = {"type": "meteorite", "hp": int(FarmState.DEBRIS.meteorite.hp)}
	FarmState.last_night["meteorite"] = 1
	return cell


func _in(hours: Array) -> bool:
	var h := TimeManager.minutes / 60.0
	return h >= float(hours[0]) and h < float(hours[1])


## Étoiles filantes visibles en ce moment ?
func meteors_now() -> bool:
	return meteor_night and _in(METEOR_HOURS)


func fireflies_now() -> bool:
	return firefly_night and _in(FIREFLY_HOURS)


func to_dict() -> Dictionary:
	return {"meteor": meteor_night, "firefly": firefly_night}


func from_dict(data: Dictionary) -> void:
	reset()
	meteor_night = bool(data.get("meteor", false))
	firefly_night = bool(data.get("firefly", false))
