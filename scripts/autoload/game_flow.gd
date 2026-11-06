extends Node
## Orchestration : nouvelle partie, chargement, fin de journée.

const STARTING_GOLD := 500
const STARTING_ITEMS := [["hoe", 1], ["watering_can", 1], ["seed_radish", 15]]

var in_game: bool = false


func _ready() -> void:
	EventBus.passed_out.connect(_on_passed_out)


func new_game() -> void:
	TimeManager.reset()
	Inventory.reset()
	FarmState.reset()
	PlayerState.reset()
	for entry: Array in STARTING_ITEMS:
		Inventory.add_item(entry[0], entry[1])
	Inventory.add_gold(STARTING_GOLD)


func continue_game() -> bool:
	return SaveManager.load_game()


func begin() -> void:
	in_game = true
	TimeManager.start_day()


## Fin de journée : vente, nuit, nouveau jour, sauvegarde, bilan.
func end_day(passed_out: bool = false) -> void:
	TimeManager.running = false
	var report := {"passed_out": passed_out, "date": TimeManager.date_string()}
	var earned := FarmState.sell_shipping(report)
	if earned > 0:
		Inventory.add_gold(earned)
	TimeManager.advance_day()
	FarmState.advance_day(TimeManager.season, TimeManager.is_raining())
	PlayerState.restore(passed_out)
	TimeManager.start_day()
	SaveManager.save_game()
	EventBus.day_summary.emit(report)


func _on_passed_out() -> void:
	EventBus.toast("Tu t'es endormi·e de fatigue...")
	end_day(true)
