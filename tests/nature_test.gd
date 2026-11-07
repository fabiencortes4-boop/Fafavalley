extends Node
## Test automatique : la nature reprend un terrain mal entretenu.
##   godot --headless res://tests/nature_test.tscn

var _failures := 0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.call("_start", false)
	await get_tree().process_frame
	FarmState.debris.clear()
	FarmState.tiles.clear()
	# Sillon labouré, vide, jamais arrosé -> mauvaise herbe
	var a := Vector2i(14, 16)
	FarmState.till(a)
	FarmState.advance_day(0, false)
	_check(FarmState.is_tilled(a), "une nuit sans soin : la terre labourée tient encore")
	FarmState.advance_day(0, false)
	_check(not FarmState.is_tilled(a) and FarmState.debris.get(a, {}).get("type") == "weed", "deux nuits vide et sec : une mauvaise herbe s'y installe")
	_check(int(FarmState.last_night.weeds) >= 1, "le matin, on sait ce que la nature a repris")
	# Sillon vide mais arrosé : il tient
	var b := Vector2i(16, 16)
	FarmState.till(b)
	for i in 3:
		FarmState.water(b)
		FarmState.advance_day(0, false)
	_check(FarmState.is_tilled(b), "arrosé chaque jour, le sillon reste propre")
	# Culture oubliée : elle fane, puis les herbes prennent la place
	var c := Vector2i(18, 16)
	FarmState.till(c)
	FarmState.plant(c, "cabbage")
	for i in 3:
		FarmState.advance_day(0, false)
	_check(FarmState.get_crop(c) == "cabbage", "3 nuits sans eau : la culture tient encore")
	FarmState.advance_day(0, false)
	_check(FarmState.is_tilled(c) and FarmState.get_crop(c) == "", "4 nuits sans eau : la culture fane")
	FarmState.advance_day(0, false)
	FarmState.advance_day(0, false)
	_check(FarmState.debris.has(c), "puis la mauvaise herbe envahit le sillon abandonné")
	# Culture arrosée de temps en temps : elle survit
	var d := Vector2i(20, 16)
	FarmState.till(d)
	FarmState.plant(d, "radish")
	for i in 3:
		if i == 1:
			FarmState.water(d)
		FarmState.advance_day(0, false)
	_check(FarmState.get_crop(d) == "radish", "arrosée de temps en temps, elle survit")
	# Les mauvaises herbes se propagent
	FarmState.debris.clear()
	FarmState.tiles.clear()
	FarmState.debris[Vector2i(20, 20)] = {"type": "weed", "hp": 1}
	for i in 30:
		FarmState.advance_day(0, false)
	var weeds := FarmState.debris.values().filter(func(x: Dictionary) -> bool: return x.type == "weed").size()
	_check(weeds > 5, "en un mois sans entretien, les herbes envahissent la ferme (%d)" % weeds)
	_check(FarmState.debris.size() <= FarmState.MAX_DEBRIS, "jusqu'à une limite")
	_check(not FarmState.debris.keys().any(func(k: Vector2i) -> bool: return Rect2i(4, 3, 7, 7).has_point(k)), "jamais devant la maison")
	print("RÉSULTAT : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	get_tree().quit(_failures)


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  ÉCHEC ") + label)
	if not condition:
		_failures += 1
