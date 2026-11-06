extends Node
## Horloge du jeu : heures, jours, saisons, années et météo.

signal time_changed(hour: int, minute: int)
signal day_started(day: int, season: int, year: int)

const SEASONS := ["Printemps", "Été", "Automne", "Hiver"]
const DAYS_PER_SEASON := 28
const START_MINUTES := 6 * 60
const PASS_OUT_MINUTES := 26 * 60  # 2h du matin
const MINUTES_PER_TICK := 10
const REAL_SECONDS_PER_TICK := 7.0
const RAIN_CHANCE := 0.2

var minutes: int = START_MINUTES
var day: int = 1
var season: int = 0
var year: int = 1
var weather: String = "sunny"
var running: bool = false

var _accumulator: float = 0.0


func reset() -> void:
	minutes = START_MINUTES
	day = 1
	season = 0
	year = 1
	weather = "sunny"
	_accumulator = 0.0


func _process(delta: float) -> void:
	if not running:
		return
	_accumulator += delta
	while _accumulator >= REAL_SECONDS_PER_TICK:
		_accumulator -= REAL_SECONDS_PER_TICK
		minutes += MINUTES_PER_TICK
		time_changed.emit(get_hour(), get_minute())
		if minutes >= PASS_OUT_MINUTES:
			running = false
			EventBus.passed_out.emit()
			return


func get_hour() -> int:
	return int(minutes / 60.0) % 24


func get_minute() -> int:
	return minutes % 60


func time_string() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]


func date_string() -> String:
	return "%s %d - An %d" % [SEASONS[season], day, year]


func weather_string() -> String:
	return "Pluie" if weather == "rain" else "Soleil"


func is_raining() -> bool:
	return weather == "rain"


## Passe au jour suivant (sans émettre de signal : GameFlow s'en charge
## une fois que tous les systèmes ont traité la nuit).
func advance_day() -> void:
	day += 1
	if day > DAYS_PER_SEASON:
		day = 1
		season = (season + 1) % SEASONS.size()
		if season == 0:
			year += 1
	minutes = START_MINUTES
	_accumulator = 0.0
	# Hiver : pas de pluie (la neige viendra plus tard).
	weather = "rain" if season != 3 and randf() < RAIN_CHANCE else "sunny"


func start_day() -> void:
	running = true
	day_started.emit(day, season, year)
	time_changed.emit(get_hour(), get_minute())


func to_dict() -> Dictionary:
	return {"minutes": minutes, "day": day, "season": season, "year": year, "weather": weather}


func from_dict(data: Dictionary) -> void:
	minutes = int(data.get("minutes", START_MINUTES))
	day = int(data.get("day", 1))
	season = int(data.get("season", 0))
	year = int(data.get("year", 1))
	weather = str(data.get("weather", "sunny"))
	_accumulator = 0.0
