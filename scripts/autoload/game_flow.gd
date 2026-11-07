extends Node
## Orchestration : nouvelle partie, chargement, fin de journée.

const STARTING_GOLD := 500
const STARTING_ITEMS := [["hoe", 1], ["watering_can", 1], ["seed_carrot", 15]]
# La hache et la faux arrivent par la lettre de bienvenue du maire.

var in_game: bool = false


func _ready() -> void:
	EventBus.passed_out.connect(_on_passed_out)
	EventBus.player_fainted.connect(_on_player_fainted)


func new_game() -> void:
	TimeManager.reset()
	Inventory.reset()
	FarmState.reset()
	PlayerState.reset()
	Relations.reset()
	FishLog.reset()
	Skills.reset()
	Mail.reset()
	Forage.reset()
	Animals.reset()
	Story.reset()
	Events.reset()
	Tutorial.start()
	for entry: Array in STARTING_ITEMS:
		Inventory.add_item(entry[0], entry[1])
	Inventory.add_gold(STARTING_GOLD)


func continue_game() -> bool:
	return SaveManager.load_game()


func begin() -> void:
	in_game = true
	Mail.check()  # la lettre de bienvenue (y compris pour les anciennes parties)
	TimeManager.start_day()


## Fin de journée : vente, nuit, nouveau jour, sauvegarde, bilan.
func end_day(passed_out: bool = false) -> void:
	TimeManager.running = false
	var report := {"passed_out": passed_out, "date": TimeManager.date_string()}
	var earned := FarmState.sell_shipping(report)
	if earned > 0:
		Inventory.add_gold(earned)
		Story.bump("earned", earned)
	var shipped := 0
	for line: Dictionary in report.get("sold", []):
		shipped += int(line.qty)
	Story.bump("shipped", shipped)
	TimeManager.advance_day()
	FarmState.advance_day(TimeManager.season, TimeManager.is_raining())
	PlayerState.restore(passed_out)
	Relations.new_day()
	Forage.new_day()
	var ranch := Animals.new_day(TimeManager.season)
	report["animals"] = ranch
	Mail.check()
	TimeManager.start_day()
	SaveManager.save_game()
	EventBus.day_summary.emit(report)


func _on_passed_out() -> void:
	EventBus.toast("Tu t'es endormi·e de fatigue...")
	end_day(true)


## Vie à zéro dans la mine : on se réveille au village, soigné mais délesté.
func _on_player_fainted() -> void:
	var lost := mini(Inventory.gold / 10, 300)
	Inventory.spend_gold(lost)
	PlayerState.health = PlayerState.max_health() / 4
	PlayerState.energy = maxi(PlayerState.energy, 20)
	EventBus.health_changed.emit(PlayerState.health, PlayerState.max_health())
	EventBus.map_change_requested.emit("village", MineLevel.VILLAGE_EXIT)
	EventBus.message_requested.emit("Évanouissement", "Tu t'es évanoui·e dans la mine... Gaston t'a ramené·e à la surface. Les soins t'ont coûté %d or." % lost)
