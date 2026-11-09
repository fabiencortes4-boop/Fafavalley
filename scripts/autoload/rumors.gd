extends Node
## Rumeurs de la taverne : chaque jour, Marius a un tuyau à donner (la
## première fois qu'on lui parle). Il ne sert que si on l'a entendu :
##  - un banc de poissons : cette espèce mord bien plus souvent aujourd'hui ;
##  - une bourse perdue en forêt (ou à la ferme) : à retrouver, pleine d'or ;
##  - un habitant qui rêve d'un cadeau : ce cadeau compte double aujourd'hui.

var today: Dictionary = {}  # {"type", ... , "heard": bool}
var _day: int = -1


func reset() -> void:
	today.clear()
	_day = -1


func _day_number() -> int:
	return (TimeManager.year - 1) * 112 + TimeManager.season * 28 + TimeManager.day


## La rumeur du jour (tirée une fois par jour).
func current() -> Dictionary:
	if _day != _day_number():
		_day = _day_number()
		today = _roll()
	return today


func _roll() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["rumeur", _day])
	match rng.randi() % 3:
		0:
			var fish: Array = []
			for id: String in GameData.fishes:
				var f: Dictionary = GameData.fishes[id]
				if not f.get("legendary", false) and float(TimeManager.season) in f.get("seasons", []):
					fish.append(id)
			if not fish.is_empty():
				return {"type": "shoal", "fish": fish[rng.randi() % fish.size()], "heard": false}
		1:
			return {"type": "purse", "gold": rng.randi_range(250, 600), "heard": false}
	var npcs: Array = GameData.npcs.keys().filter(func(n: String) -> bool: return n != "marius" and not GameData.npc(n).get("loves", []).is_empty())
	var npc: String = npcs[rng.randi() % npcs.size()]
	var loves: Array = GameData.npc(npc).loves
	return {"type": "gift", "npc": npc, "item": str(loves[rng.randi() % loves.size()]), "heard": false}


## Parler à Marius : la rumeur du jour, une seule fois ("" sinon).
func try_hear(npc_id: String) -> String:
	if npc_id != "marius":
		return ""
	var r := current()
	if r.is_empty() or bool(r.heard):
		return ""
	r.heard = true
	match str(r.type):
		"shoal":
			return "Psst... Les pêcheurs disent qu'il y a un banc de %s aujourd'hui. Ça mord comme jamais ! Va vite tenter ta chance." % GameData.item_name(str(r.fish)).to_lower()
		"purse":
			var place := "forest" if PlayerState.flags.has("story_ch1") else "farm"
			var cell := _purse_cell(place)
			var spots: Dictionary = Forage.spots.get(place, {})
			spots["%d,%d" % [cell.x, cell.y]] = "lost_purse"
			Forage.spots[place] = spots
			r["place"] = place
			return "Un colporteur a perdu sa bourse %s, hier soir. Si tu la trouves, garde-la : il est reparti en jurant qu'il ne remettrait jamais les pieds ici !" % ("dans la forêt du nord" if place == "forest" else "près de ta ferme")
		"gift":
			return "Entre nous... %s rêve d'un(e) %s en ce moment. Si tu lui en offres un aujourd'hui, ça lui fera deux fois plus plaisir !" % [GameData.npc(str(r.npc)).get("name", ""), GameData.item_name(str(r.item)).to_lower()]
	return ""


func _purse_cell(place: String) -> Vector2i:
	var rows: Array = ForestMap.MAP if place == "forest" else Farm.MAP
	var cells: Array = []
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			if row[x] == "." and y > 2 and y < rows.size() - 3 and not Woods.of(place).has(Vector2i(x, y)) and not FarmState.objects.has(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["bourse", _day])
	return cells[rng.randi() % cells.size()] if not cells.is_empty() else Vector2i(10, 10)


## Poids d'un poisson aujourd'hui (x5 pour le banc dont on a entendu parler).
func fish_factor(id: String) -> int:
	var r := current()
	return 5 if str(r.get("type", "")) == "shoal" and bool(r.heard) and str(r.fish) == id else 1


## Cadeau rêvé (entendu à la taverne) : points doublés.
func gift_factor(npc_id: String, item_id: String) -> int:
	var r := current()
	return 2 if str(r.get("type", "")) == "gift" and bool(r.heard) and str(r.npc) == npc_id and GameData.base_id(item_id) == str(r.item) else 1


func to_dict() -> Dictionary:
	return {"today": today.duplicate(), "day": _day}


func from_dict(data: Dictionary) -> void:
	today = (data.get("today", {}) as Dictionary).duplicate()
	_day = int(data.get("day", -1))
