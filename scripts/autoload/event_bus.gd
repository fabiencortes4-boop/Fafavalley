extends Node
## Bus d'événements global : les systèmes communiquent sans se connaître.

signal toast_requested(text: String)
signal inventory_changed
signal gold_changed(amount: int)
signal energy_changed(value: int, max_value: int)
signal water_changed(value: int, max_value: int)
signal farm_tile_changed(cell: Vector2i)
signal passed_out
signal day_summary(report: Dictionary)
signal shop_requested
signal sleep_requested
signal before_save


func toast(text: String) -> void:
	toast_requested.emit(text)
