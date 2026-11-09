class_name Farm
extends WorldMap
## La ferme : labour, arrosage, semis, récolte, expédition, sommeil.
## Affiche l'état de FarmState (la logique de croissance y vit).
##
## Caractères propres à la ferme : H maison (3x3), G grange (3x6),
## B coffre d'expédition, C poule, V vache, X boîte aux lettres.

const MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTT==TTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTLLTTTTTTTTTTTTTTT",
	"TTTTT..T.T..T...TTT....==T..TTT.......TT",
	"TTT........f.........R.==....K...J....TT",
	"TT....H.........o.....................TT",
	"TTT........................Q..........TT",
	"TT..X.....B.........'......==.........TT",
	"TTT....==...b..............==........hTT",
	"TTT..f.==..................==...........",
	"TT.....=================================",
	"TTT....=================================",
	"TTT...............................'.....",
	"TTT................k....m.............TT",
	"TTT.....m.....,...............,.....bTTT",
	"TTT.R................................TTT",
	"TT....................'.....~~~~~~...TTT",
	"TTT........................~~~~~~~~..TTT",
	"TTT.......................~~~~~~~~~...TT",
	"TT........'...............~~~~~~~~~~..TT",
	"TT........................~~~~~~~~~~..TT",
	"TT.S...................o..~~~~~~~~~~..TT",
	"TTT.............,.........~~~~~~~~~~..TT",
	"TT.........................~~~~~~~~...TT",
	"TTT.........................~~~~~~...TTT",
	"TT...................................oTT",
	"TTT.........b......................m..TT",
	"TTT...............'......R............TT",
	"TTT..TTTT.T...TT....T......T..T.T.T...TT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]

const TILLABLE := [".", ",", "'", "C", "V"]
const DEBRIS_COUNT := 140  # débris à défricher au début de la partie
const DEBRIS_WEIGHTS := {"weed": 50, "twig": 20, "stone": 20, "stump": 10}
const CROP_STAGES := 4
const CROP_ROWS := 6

signal visual_changed(cell: Vector2i)  # pour la vue 3D
signal visual_reset

var _soil: TileMapLayer
var _objects: TileMapLayer
var _mail_alert: Sprite2D
var _deferring: bool = false  # un geste est en cours : l'affichage attend l'impact
var _deferred: Dictionary = {}
var _mailbox_cell: Vector2i
var _crop_sprites: Dictionary = {}  # Vector2i -> Sprite2D
var _grass_coords := [
	WorldTiles.coords(WorldTiles.GRASS), WorldTiles.coords(WorldTiles.GRASS_TUFT),
	WorldTiles.coords(WorldTiles.GRASS_FLOWERS),
]


func _init() -> void:
	map_id = "farm"


func _map_rows() -> Array:
	return MAP


func display_name() -> String:
	return PlayerState.farm_name if PlayerState.farm_name != "La ferme" else "Ferme"


func _place_special(cell: Vector2i, ch: String) -> void:
	match ch:
		"H":
			var door := _add_building(cell, Vector2i(3, 3), "res://assets/sprites/house.png", 1)
			_interactables[door] = "door"
			_spawn_cell = door + Vector2i.DOWN
		"K", "J", "S":
			_place_plot({"K": "coop", "J": "barn", "S": "greenhouse"}[ch], cell)
		"L":
			# Un tronc barre le chemin de la forêt (dégagé au chapitre 1)
			if not PlayerState.flags.has("story_ch1"):
				block_cell(cell)
				_interactables[cell] = "log_gate"
		"B":
			_add_building(cell, Vector2i(1, 1), "res://assets/sprites/shipping_bin.png")
			_interactables[cell] = "bin"
		"Q":
			_add_sign(cell, "Panneau", "Valfleur, le village : suis le chemin vers l'est. L'épicerie de Rosalie vend des graines de 9h à 17h.")
		"X":
			_add_building(cell, Vector2i(1, 1), "res://assets/sprites/mailbox.png")
			_interactables[cell] = "mailbox"
			_mailbox_cell = cell
		"C", "V":
			var critter := Critter.new()
			critter.frame = 0 if ch == "C" else 1
			critter.position = Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE)
			_entities.add_child(critter)


func _after_build() -> void:
	_soil = TileMapLayer.new()
	_soil.tile_set = _ground.tile_set
	_soil.z_index = -1
	add_child(_soil)
	_objects = TileMapLayer.new()
	_objects.tile_set = _ground.tile_set
	_objects.z_index = -1
	add_child(_objects)
	EventBus.farm_tile_changed.connect(_refresh_cell)
	FarmState.fences_changed.connect(_refresh_fences)
	_refresh_fences()
	if not PlayerState.flags.has("farm_debris"):
		PlayerState.flags["farm_debris"] = true
		_scatter_debris(DEBRIS_COUNT)
	_refresh_all()
	# « ! » au-dessus de la boîte aux lettres quand du courrier attend
	_mail_alert = Sprite2D.new()
	_mail_alert.texture = load("res://assets/sprites/ui_alert.png")
	_mail_alert.position = Vector2(_mailbox_cell * TILE) + Vector2(TILE / 2.0, -10)
	_mail_alert.z_index = 5
	add_child(_mail_alert)
	Mail.mail_changed.connect(_update_mail_alert)
	_update_mail_alert()
	_spawn_animals()
	_spawn_visitors()
	if Marriage.spouse_place() == "farm":
		_spawn_spouse(Vector2i(9, 8))


func _warp_for(cell: Vector2i) -> Dictionary:
	if cell.y <= 0:
		return {"map": "forest", "cell": Vector2i(22, 23)}
	if cell.x >= _map_size.x - 1:
		return {"map": "village", "cell": Vector2i(2, 9 + clampi(cell.y, 9, 10) + 1)}
	return {}


# ------------------------------------------------------------ actions
func _process(delta: float) -> void:
	super(delta)
	if _mail_alert.visible:
		_mail_alert.offset.y = sin(Time.get_ticks_msec() / 200.0) * 1.5


func _update_mail_alert() -> void:
	_mail_alert.visible = Mail.has_mail()


func _interact(kind: String, _cell: Vector2i) -> void:
	match kind:
		"mailbox":
			if Mail.has_mail():
				EventBus.mail_requested.emit()
			else:
				EventBus.toast("La boîte aux lettres est vide.")
		"door":
			Sfx.play("door")
			EventBus.map_change_requested.emit("home", Vector2i(6, 6))
		"bin":
			_ship_selected()
		"log_gate":
			EventBus.message_requested.emit("Un tronc énorme", "Un vieux chêne est tombé en travers du chemin de la forêt. Impossible de passer seul... Bertrand a promis de t'aider quand la ferme aura fait ses preuves (chapitre 1 de l'histoire).")
		_:
			var parts := kind.split(":")
			if parts.size() == 2:
				_interact_plot(parts[0], parts[1])


func _act_on_ground(cell: Vector2i) -> bool:
	if FarmState.is_mature(cell):
		_harvest(cell)
		return true
	var slot: Variant = Inventory.get_selected()
	if slot == null:
		return false
	var item := GameData.item(slot.id)
	match str(item.get("type", "")):
		"tool":
			_use_tool(str(item.get("tool", "")), item, cell)
			return true
		"seed":
			_plant(cell, str(item.get("crop", "")))
			return true
		"placeable":
			if str(item.place) == "fence":
				_place_fence(cell)
				return true
			if _can_place(cell):
				_deferring = true
				FarmState.place_object(cell, str(item.place))
				Machines.start_auto(cell, str(item.place))
				Inventory.remove_from_slot(Inventory.selected, 1)
				_gesture("bend", cell, func() -> void:
					Sfx.play("drop")
					Fx.puff(_entities, cell_center(cell), Color(0.93, 0.88, 0.78, 0.8), 1.4))
			return true
		"sapling":
			_plant_tree(cell, str(item.get("tree", "")))
			return true
		"tree_seed":
			_plant_wood_tree(cell, str(item.get("tree", "")))
			return true
		"fertilizer":
			_deferring = FarmState.is_tilled(cell) and not FarmState.is_fertilized(cell)
			if FarmState.is_tilled(cell) and FarmState.fertilize(cell):
				Inventory.remove_from_slot(Inventory.selected, 1)
				_gesture("bend", cell, func() -> void:
					Sfx.play("plant")
					Fx.burst(_entities, _cell_fx_point(cell), [Color(0.35, 0.25, 0.18), Color(0.5, 0.4, 0.25)], 10, 35.0))
				EventBus.toast("Engrais épandu : ça va pousser plus vite !")
			return true
	return false


## Toucher un coffre l'ouvre (sauf pioche en main : elle le ramasse).
## Toucher un animal qui se promène le caresse.
func act_on(cell: Vector2i) -> void:
	var animal := _animal_at(cell)
	if animal != null and not fishing.busy():
		var index: int = animal.get_meta("animal_index")
		var a: Dictionary = Animals.animals[index]
		player.face_towards(cell - player_cell())
		player.play_use()
		if Animals.pet(index):
			Sfx.play("harvest")
			Settings.vibrate(18)
			Fx.burst(_entities, animal.position + Vector2(0, -10), [Color(1, 0.45, 0.55), Color(1, 0.75, 0.8)], 8, 35.0)
			EventBus.toast("Tu caresses %s. Ça lui fait plaisir !" % a.name)
		else:
			EventBus.toast("%s a déjà eu ses caresses aujourd'hui." % a.name)
		return
	if FarmState.objects.get(cell) == "tree" and not fishing.busy():
		_shake_tree(cell)
		return
	if Machines.is_machine(str(FarmState.objects.get(cell, ""))) and _holding_tool() != "pickaxe" and not fishing.busy():
		_use_machine(cell)
		return
	if FarmState.objects.get(cell) == "garden_bench" and _holding_tool() == "pickaxe":
		_use_pickaxe(cell, 0)
		return
	var visitor := _visitor_at(cell)
	if visitor != null:
		_talk_visitor(visitor)
		return
	if FarmState.objects.get(cell) == "chest" and _holding_tool() != "pickaxe" and not fishing.busy():
		EventBus.chest_requested.emit(cell)
		return
	if FarmState.objects.get(cell) == "wood_tree" and _holding_tool() != "axe" and not fishing.busy() and Woods.farm.has(cell):
		player.face_towards(cell - player_cell())
		var tip := "coupe-la à la hache" if Woods.is_stump(cell, "farm") else ("coupe-le à la hache pour du bois" if Woods.stage(cell, "farm") == 3 else "adulte dans %d jour(s)" % Woods.days_left(cell, "farm"))
		EventBus.toast("%s : %s." % [Woods.label(cell, "farm"), tip])
		return
	super(cell)


# ------------------------------------------------------------ bâtiments d'élevage
var plots: Dictionary = {}  # "coop"/"barn" -> {"cell": Vector2i, "size": Vector2i, "door": Vector2i}


func _place_plot(id: String, cell: Vector2i) -> void:
	var info := Animals.building_info(id)
	var size := Vector2i(int(info.size[0]), int(info.size[1]))
	var door := cell + Vector2i(int(info.get("door", 1)), size.y - 1)
	plots[id] = {"cell": cell, "size": size, "door": door}
	if Animals.is_built(id) and id == "greenhouse":
		# Serre : murs vitrés tout autour (sauf la porte), intérieur cultivable
		for dx in size.x:
			for dy in size.y:
				var c := cell + Vector2i(dx, dy)
				var border := dx == 0 or dy == 0 or dx == size.x - 1 or dy == size.y - 1
				if border and c != door:
					block_cell(c)
				FarmState.debris.erase(c)
		return
	if Animals.is_built(id):
		_add_building(cell, size, "res://assets/sprites/house_gray.png" if id == "coop" else "res://assets/sprites/store.png", int(info.get("door", 1)))
		_interactables[door] = "animals:" + id
	elif Animals.under_construction(id):
		_interactables[door] = "construction:" + id
		_interactables[cell] = "construction:" + id
	else:
		_interactables[door] = "plot:" + id
		_interactables[cell] = "plot:" + id


func _interact_plot(kind: String, id: String) -> void:
	var name := str(Animals.building_info(id).get("name", id))
	match kind:
		"animals":
			Sfx.play("door")
			EventBus.animals_requested.emit(id)
		"construction":
			EventBus.message_requested.emit(name, "Le chantier avance : encore %d jour(s) et Mathis aura terminé." % int(Animals.buildings[id].days_left))
		"plot":
			EventBus.message_requested.emit("Terrain à bâtir", "Emplacement prévu : %s. Mathis, le charpentier du village, peut le construire." % name.to_lower())


## En journée, par beau temps, les animaux se promènent devant leur bâtiment.
func _spawn_animals() -> void:
	var hour := TimeManager.minutes / 60.0
	if hour < 7.0 or hour >= 18.0 or TimeManager.is_raining() or TimeManager.season == 3:
		return
	for i in Animals.animals.size():
		var a: Dictionary = Animals.animals[i]
		if not plots.has(a.building) or not Animals.is_built(a.building):
			continue
		var critter := Critter.new()
		critter.kind = str(a.type)
		critter.frame = int(Animals.animal_info(a.type).get("frame", 0))
		critter.position = cell_center(plots[a.building].door + Vector2i(randi_range(-1, 1), 2)) + Vector2(randf_range(-6, 6), 0)
		critter.set_meta("animal_index", i)
		_entities.add_child(critter)


# ------------------------------------------------------------ arbres fruitiers
func _plant_tree(cell: Vector2i, type: String) -> void:
	if not _can_place(cell) or FarmState.in_greenhouse(cell):
		EventBus.toast("Plante l'arbre sur de l'herbe libre.")
		return
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if FarmState.trees.has(cell + Vector2i(dx, dy)):
				EventBus.toast("Trop près d'un autre arbre : laisse-lui de la place.")
				return
	_deferring = true
	if FarmState.plant_tree(cell, type):
		Inventory.remove_from_slot(Inventory.selected, 1)
		_gesture("bend", cell, func() -> void:
			Sfx.play("plant")
			Fx.puff(_entities, cell_center(cell), Color(0.62, 0.45, 0.3, 0.7), 1.2))
		var info: Dictionary = FarmState.tree_data[type]
		EventBus.toast("%s planté ! Adulte dans %d jours." % [info.name, int(info.grow_days)])
	else:
		_deferring = false


# ------------------------------------------------------------ clôtures
var _fence_layer: Node2D


## Le bord visé : entre le joueur et la case touchée (ou devant lui).
func _fence_edge(cell: Vector2i) -> String:
	var from := player_cell()
	var edge := FarmState.edge_between(from, cell)
	return edge if edge != "" else FarmState.edge_between(from, from + player.facing)


func _place_fence(cell: Vector2i) -> void:
	var edge := _fence_edge(cell)
	if edge == "":
		return
	if FarmState.fences.has(edge):
		EventBus.toast("Il y a déjà une clôture ici. (La pioche la reprend.)")
		return
	var parts := FarmState.edge_parts(edge)
	var c: Vector2i = parts[1]
	var other: Vector2i = c + (Vector2i.UP if parts[0] else Vector2i.LEFT)
	if not (_ground_chars.has(c) or _ground_chars.has(other)) or _blocked.has(c) and _blocked.has(other):
		return
	FarmState.add_fence(edge)
	Inventory.remove_from_slot(Inventory.selected, 1)
	_gesture("bend", cell, func() -> void: Sfx.play("drop"))


## Collisions fines le long des bords clôturés, et leur dessin en 2D.
func _refresh_fences() -> void:
	if _fence_layer != null:
		_fence_layer.queue_free()
	_fence_layer = Node2D.new()
	add_child(_fence_layer)
	var body := StaticBody2D.new()
	_fence_layer.add_child(body)
	for edge: String in FarmState.fences:
		var parts := FarmState.edge_parts(edge)
		var c: Vector2i = parts[1]
		var a := Vector2(c * TILE)
		var b := a + (Vector2(TILE, 0) if parts[0] else Vector2(0, TILE))
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE + 2, 4) if parts[0] else Vector2(4, TILE + 2)
		shape.shape = rect
		shape.position = (a + b) / 2.0
		body.add_child(shape)
		var line := Line2D.new()
		line.points = [a, b]
		line.width = 3.0
		line.default_color = Color(0.6, 0.42, 0.26)
		_fence_layer.add_child(line)


# ------------------------------------------------------------ visiteurs du dimanche
var _visitors: Array[Npc] = []
var _visitors_greeted: Dictionary = {}


## Le dimanche, une belle ferme attire des habitants (voir FarmState.beauty).
func _spawn_visitors() -> void:
	if TimeManager.weekday() != "Dim." or TimeManager.season == 3:
		return
	var n := FarmState.visitors_count()
	if n == 0:
		return
	Tips.show("photo")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["visite", TimeManager.year, TimeManager.season, TimeManager.day])
	var ids: Array = GameData.npcs.keys().filter(func(i: String) -> bool: return i != Marriage.spouse)
	var spots: Array = []
	for cell: Vector2i in FarmState.objects:
		if str(FarmState.objects[cell]) in ["garden_bench", "garden_fountain", "flower_bed", "garden_lantern", "golden_statue"]:
			for d: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if is_walkable(cell + d):
					spots.append(cell + d)
					break
	if spots.is_empty():
		spots = [Vector2i(9, 9), Vector2i(12, 9), Vector2i(15, 10)]
	for i in n:
		var npc := Npc.new()
		npc.id = ids[rng.randi() % ids.size()]
		ids.erase(npc.id)
		npc.position = cell_center(spots[i % spots.size()])
		_entities.add_child(npc)
		_visitors.append(npc)


func _visitor_at(cell: Vector2i) -> Npc:
	for v: Npc in _visitors:
		if is_instance_valid(v) and v.position.distance_to(cell_center(cell)) < TILE * 0.8:
			return v
	return null


func _talk_visitor(v: Npc) -> void:
	v.face(player.position)
	if _visitors_greeted.has(v.id):
		talk_to_npc(v)
		return
	_visitors_greeted[v.id] = true
	Relations.talked_today[v.id] = true
	Relations.met[v.id] = true
	Relations.add_points(v.id, 60)
	var lines := [
		"Quelle belle ferme ! On m'avait dit qu'elle valait le détour, c'est encore mieux en vrai.",
		"Je me suis assis(e) un moment près de tes fleurs. Ça fait du bien, un endroit pareil.",
		"Tout le village parle de ta ferme. Je comprends pourquoi !",
	]
	EventBus.dialogue_requested.emit(v.id, lines[hash(v.id) % lines.size()])


## Arbre à bois planté à la ferme (pin, platane, chêne).
func _plant_wood_tree(cell: Vector2i, type: String) -> void:
	if not _can_place(cell) or FarmState.in_greenhouse(cell):
		EventBus.toast("Plante l'arbre sur de l'herbe libre.")
		return
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if FarmState.objects.get(cell + d, "") in ["tree", "wood_tree"]:
			EventBus.toast("Trop près d'un autre arbre : laisse-lui de la place.")
			return
	if not Woods.plant(cell, type, "farm"):
		return
	_deferring = true
	FarmState.place_object(cell, "wood_tree")
	Inventory.remove_from_slot(Inventory.selected, 1)
	_gesture("bend", cell, func() -> void:
		Sfx.play("plant")
		Fx.puff(_entities, cell_center(cell), Color(0.62, 0.45, 0.3, 0.7), 1.2))
	EventBus.toast("%s planté ! Adulte dans %d jours." % [Woods.TYPES[type].name, int(Woods.TYPES[type].grow)])


func _chop_wood_tree(cell: Vector2i, axe: Dictionary) -> void:
	if not Woods.farm.has(cell):
		FarmState.remove_object(cell)
		return
	if not spend_energy(int(axe.get("energy", 2))):
		return
	var from := player_cell()
	var was_tree := not Woods.is_stump(cell, "farm") and Woods.stage(cell, "farm") == 3
	var res := Woods.chop(cell, int(axe.get("power", 1)), from, "farm")
	if res.done and not Woods.farm.has(cell):
		_deferring = true
		FarmState.remove_object(cell)
	elif res.done:
		_deferring = true
		EventBus.farm_tile_changed.emit(cell)  # devenu souche
	var at := _cell_fx_point(cell)
	_gesture("strike", cell, func() -> void:
		Sfx.play("chop")
		Fx.burst(_entities, at, Fx.WOOD, 18 if res.done else 8, 60.0)
		if res.done and was_tree:
			Sfx.play("tree_fall")
			Settings.vibrate(70)
			shake(3.5, 0.3)
			Fx.puff(_entities, cell_center(cell), Color(0.9, 0.85, 0.75, 0.9), 2.4)
		var away := Vector2(cell - from).normalized() if cell != from else Vector2.DOWN
		for i in res.drops.size():
			_drop(str(res.drops[i]), cell_center(cell) + away * float(4 + i % 3 * 3) + Vector2(randf_range(-10, 10), randf_range(-8, 8))))


func _shake_tree(cell: Vector2i) -> void:
	var t: Dictionary = FarmState.trees[cell]
	var info: Dictionary = FarmState.tree_data[t.type]
	player.face_towards(cell - player_cell())
	player.play_use()
	if FarmState.tree_stage(cell) < 2:
		EventBus.toast("%s : encore %d jour(s) avant d'être adulte." % [info.name, int(info.grow_days) - int(t.age)])
		return
	if int(t.fruits) == 0:
		EventBus.toast("Pas de fruits aujourd'hui. Un fruit par jour en %s." % ["printemps", "été", "automne", "hiver"][int(info.season)])
		return
	var got := FarmState.shake_tree(cell)
	var maturity := clampf((float(t.age) - float(info.grow_days)) / 84.0, 0.0, 1.0)
	got[0] = GameData.with_quality(got[0], GameData.roll_quality(Skills.level("farming"), maturity))
	var left := Inventory.add_item(got[0], int(got[1]))
	if left > 0:
		t.fruits = left
	Sfx.play("harvest")
	Settings.vibrate(18)
	shake(1.5, 0.12)
	Fx.burst(_entities, cell_center(cell) + Vector2(0, -14), [Color(0.4, 0.75, 0.3), Color(0.3, 0.6, 0.25)], 12, 50.0)
	Skills.add_xp("farming", 4 * int(got[1]))
	Story.bump("harvest", int(got[1]) - left)
	EventBus.toast("+%d %s" % [int(got[1]) - left, GameData.item_name(got[0])])
	visual_changed.emit(cell)


func _is_farmland() -> bool:
	return true


func action_hint(cell: Vector2i) -> String:
	if not fishing.busy():
		if _animal_at(cell) != null:
			return "Caresser"
		if FarmState.objects.get(cell) == "chest" and _holding_tool() != "pickaxe":
			return "Ouvrir"
		if Machines.is_machine(str(FarmState.objects.get(cell, ""))) and _holding_tool() != "pickaxe":
			if Machines.ready(cell):
				return "Récupérer"
			var slot: Variant = Inventory.get_selected()
			if not Machines.state.has(cell) and slot != null and not Machines.recipe(str(FarmState.objects[cell]), str(slot.id)).is_empty():
				return "Déposer"
			return "Voir"
		if FarmState.objects.get(cell) == "tree":
			return "Cueillir" if int(FarmState.trees[cell].fruits) > 0 else "Voir"
		if FarmState.is_mature(cell):
			return "Récolter"
	return super(cell)


func _animal_at(cell: Vector2i) -> Node2D:
	var center := cell_center(cell)
	for child in _entities.get_children():
		if child is Critter and child.has_meta("animal_index") and child.position.distance_to(center) < 13.0:
			return child
	return null


func is_walkable(cell: Vector2i) -> bool:
	var obj: String = FarmState.objects.get(cell, "")
	return super(cell) and (obj == "" or obj in FarmState.WALKABLE_OBJECTS) and not FarmState.debris.has(cell)


# ------------------------------------------------------------ gestes
## Joue un geste d'outil vers une case. L'état du jeu change tout de suite,
## mais l'affichage de la case (terre, plante, débris) attend l'impact,
## moment où se déclenchent aussi effets et sons.
func _gesture(gesture: String, cell: Vector2i, effect: Callable = Callable()) -> void:
	var slot: Variant = Inventory.get_selected()
	var icon: Texture2D = GameData.item_icon(slot.id) if slot != null else null
	player.face_towards(cell - player_cell())
	_deferring = true
	player.play_tool(gesture, icon, func() -> void:
		_deferring = false
		for c: Vector2i in _deferred.keys():
			_refresh_cell(c)
		_deferred.clear()
		if effect.is_valid():
			effect.call())


func _cell_fx_point(cell: Vector2i) -> Vector2:
	return cell_center(cell) + Vector2(0, -4)


# ------------------------------------------------------------ débris
func _scatter_debris(count: int, only_weeds: bool = false) -> void:
	var cells: Array = []
	for cell: Vector2i in _ground_chars:
		if not str(_ground_chars[cell]) in TILLABLE or not is_walkable(cell) or _interactables.has(cell):
			continue
		if FarmState.is_tilled(cell) or (cell - _spawn_cell).length() < 4 or FarmState.in_greenhouse(cell):
			continue
		cells.append(cell)
	cells.shuffle()
	var total := 0
	for w: int in DEBRIS_WEIGHTS.values():
		total += w
	for cell: Vector2i in cells.slice(0, count):
		var type := "weed"
		if not only_weeds:
			var roll := randi() % total
			for t: String in DEBRIS_WEIGHTS:
				roll -= int(DEBRIS_WEIGHTS[t])
				if roll < 0:
					type = t
					break
		FarmState.debris[cell] = {"type": type, "hp": int(FarmState.DEBRIS[type].hp)}


## Coup d'outil sur un débris. Renvoie true si la case en contenait un.
func _hit_debris(cell: Vector2i, tool: String, energy: int) -> bool:
	if not FarmState.debris.has(cell):
		return false
	var d: Dictionary = FarmState.debris[cell]
	var info: Dictionary = FarmState.DEBRIS[d.type]
	if not tool in info.tools:
		var hint: String = {"twig": "la hache", "stump": "la hache", "stone": "la pioche", "meteorite": "la pioche"}.get(d.type, "un outil")
		EventBus.toast("Il faut %s pour ça." % hint)
		return true
	if energy > 0 and not spend_energy(energy):
		return true
	d.hp -= int(GameData.item(Inventory.get_selected().id).get("power", 1)) if Inventory.get_selected() != null and tool != "weapon" else 1
	var type: String = d.type
	var broken: bool = d.hp <= 0
	var drops: Array = []
	if broken:
		FarmState.debris.erase(cell)
		Skills.add_xp("foraging", int(info.xp))
		Story.bump("cleared")
		for drop: Array in info.drops:
			if randf() < float(drop[3]):
				var n := randi_range(int(drop[1]), int(drop[2]))
				if drop[0] == "wood" and Skills.roll("foraging", 6.0):
					n *= 2
				for i in n:
					drops.append(str(drop[0]))
		_deferring = tool != "weapon"
		_refresh_cell(cell)
	var at := _cell_fx_point(cell)
	var effect := func() -> void:
		match type:
			"weed":
				Sfx.play("swish")
				Fx.burst(_entities, at, Fx.GRASS, 12, 55.0)
			"twig", "stump":
				Sfx.play("chop")
				Fx.burst(_entities, at, Fx.WOOD, 8 if not broken else 18, 60.0)
				if broken and type == "stump":
					Sfx.play("tree_fall")
					Settings.vibrate(60)
					shake(3.0, 0.25)
					Fx.puff(_entities, cell_center(cell), Color(0.9, 0.85, 0.75, 0.9), 2.0)
			"stone", "meteorite":
				Sfx.play("clink")
				Fx.burst(_entities, at, Fx.STONE, 10, 60.0)
				if broken:
					Sfx.play("rock_break")
					Settings.vibrate(30)
					shake(2.0, 0.15)
		for id: String in drops:
			_drop(id, cell_center(cell))
	if tool == "weapon":
		effect.call()
	else:
		_gesture("sweep" if tool == "scythe" else "strike", cell, effect)
	return true


func _drop(item_id: String, at: Vector2) -> void:
	var pickup := Pickup.new()
	pickup.item_id = item_id
	pickup.target = player
	pickup.position = at
	_entities.add_child(pickup)


func _swing_hit_cell(cell: Vector2i) -> void:
	if FarmState.debris.get(cell, {}).get("type") == "weed":
		_hit_debris(cell, "weapon", 0)


func _can_place(cell: Vector2i) -> bool:
	return (
		str(_ground_chars.get(cell, "")) in TILLABLE
		and not _blocked.has(cell)
		and not _interactables.has(cell)
		and not FarmState.objects.has(cell)
		and not FarmState.debris.has(cell)
		and not FarmState.is_tilled(cell)
		and cell != player_cell()
	)


## La pioche ramasse les objets posés (arroseurs).
func _use_pickaxe(cell: Vector2i, energy: int) -> void:
	var edge := _fence_edge(cell)
	if FarmState.fences.has(edge):
		if Inventory.add_item("fence", 1) > 0:
			EventBus.toast("Inventaire plein !")
			return
		FarmState.remove_fence(edge)
		_gesture("strike", cell, func() -> void: Sfx.play("pickup"))
		return
	if _hit_debris(cell, "pickaxe", energy):
		return
	if not FarmState.objects.has(cell) or FarmState.objects[cell] in ["tree", "wood_tree"]:
		return
	var id := FarmState.objects[cell] as String
	if id == "chest" and not FarmState.chest_is_empty(cell):
		EventBus.toast("Vide le coffre avant de le déplacer.")
		return
	if Machines.state.has(cell) and not Machines.data.get(id, {}).has("auto"):
		EventBus.toast("Attends que la machine ait fini (ou récupère son produit) avant de la déplacer.")
		return
	Machines.remove(cell)
	if not Inventory.can_add(id):
		EventBus.toast("Inventaire plein !")
		return
	_deferring = true
	FarmState.remove_object(cell)
	Inventory.add_item(id, 1)
	_gesture("strike", cell, func() -> void:
		Sfx.play("pickup")
		Fx.item_pop(_entities, _cell_fx_point(cell), GameData.item_icon(id), player))


func _use_tool(tool: String, item: Dictionary, cell: Vector2i) -> void:
	var energy := int(item.get("energy", 2))
	if tool == "axe" and FarmState.objects.get(cell) == "wood_tree":
		_chop_wood_tree(cell, item)
		return
	if _hit_debris(cell, tool, energy):
		return
	match tool:
		"hoe":
			if not _can_till(cell):
				_gesture("strike", cell, func() -> void: Sfx.play("whoosh"))
				return
			if not spend_energy(energy):
				return
			_deferring = true
			FarmState.till(cell)
			# Parfois, la houe met au jour un fossile
			var fossil := Museum.roll_find(0.015)
			if fossil != "":
				_drop(fossil, cell_center(cell))
				EventBus.toast("Un fossile dans la terre : %s ! (Le musée est dans Menu > Journal.)" % GameData.item_name(fossil))
			_gesture("strike", cell, func() -> void:
				Sfx.play("dig")
				Fx.burst(_entities, _cell_fx_point(cell), Fx.DIRT, 14, 65.0)
				Fx.puff(_entities, cell_center(cell), Color(0.7, 0.55, 0.4, 0.6), 1.2))
		"axe":
			_gesture("strike", cell, func() -> void: Sfx.play("whoosh"))
		"scythe":
			_gesture("sweep", cell, func() -> void: Sfx.play("swish"))
		"watering_can":
			if _ground_chars.get(cell, "") == "~":
				PlayerState.refill_water()
				_gesture("bend", cell, func() -> void:
					Sfx.play("splash")
					Fx.burst(_entities, _cell_fx_point(cell), Fx.WATER, 14, 70.0))
				EventBus.toast("Arrosoir rempli !")
				return
			# L'arrosoir en cuivre arrose plusieurs cases en ligne.
			var targets: Array[Vector2i] = []
			for k in int(item.get("area", 1)):
				var c := cell + player.facing * k
				if FarmState.is_tilled(c) and not FarmState.is_watered(c):
					targets.append(c)
			if targets.is_empty():
				return
			if PlayerState.water <= 0:
				EventBus.toast("Arrosoir vide : remplis-le à l'étang.")
				return
			if not spend_energy(energy):
				return
			_deferring = true
			for c in targets:
				if PlayerState.use_water():
					FarmState.water(c)
			Sfx.play("water")
			# Gouttes qui tombent sur les cases pendant que l'arrosoir verse
			var drops_timer := get_tree().create_timer(0.14)
			drops_timer.timeout.connect(func() -> void:
				for c: Vector2i in targets:
					Fx.burst(_entities, cell_center(c) + Vector2(0, -14), Fx.WATER, 10, 25.0, false, 380.0, 0.35))
			_gesture("pour", cell, func() -> void:
				for c: Vector2i in targets:
					Fx.burst(_entities, cell_center(c), Fx.WATER, 6, 35.0)
				Sfx.play("splash", -10.0))


func _can_till(cell: Vector2i) -> bool:
	return (
		str(_ground_chars.get(cell, "")) in TILLABLE
		and _ground.get_cell_atlas_coords(cell) in _grass_coords
		and not _blocked.has(cell)
		and not _interactables.has(cell)
		and not FarmState.objects.has(cell)
		and not FarmState.debris.has(cell)
		and not FarmState.is_tilled(cell)
		and cell != player_cell()
	)


func _plant(cell: Vector2i, crop_id: String) -> void:
	if crop_id == "" or not FarmState.is_tilled(cell) or FarmState.get_crop(cell) != "":
		return
	var hybrid := crop_id == "@hybrid"
	if hybrid:
		# Graine hybride : une culture de la saison (ou n'importe laquelle en serre)
		var choices: Array = GameData.crops.keys().filter(func(c: String) -> bool: return FarmState.in_greenhouse(cell) or GameData.crop_in_season(c, TimeManager.season))
		if choices.is_empty():
			EventBus.toast("Rien ne pousse dehors en cette saison : sème-la dans la serre.")
			return
		crop_id = choices[randi() % choices.size()]
	if not GameData.crop_in_season(crop_id, TimeManager.season) and not FarmState.in_greenhouse(cell):
		EventBus.toast("Ce n'est pas la saison pour planter ça (sauf dans une serre).")
		return
	_deferring = true
	if not FarmState.plant(cell, crop_id):
		_deferring = false
	else:
		Inventory.remove_from_slot(Inventory.selected, 1)
		if hybrid:
			FarmState.tiles[cell].hybrid = true
			EventBus.toast("Graine hybride : ce sera %s, de qualité cristal !" % str(GameData.crop(crop_id).get("name", crop_id)).to_lower())
		# Semé trop tard : la culture mourra au changement de saison avant d'être mûre
		var need := 0
		for d: Variant in GameData.crop(crop_id).get("stage_days", []):
			need += int(d)
		var left := TimeManager.DAYS_PER_SEASON - TimeManager.day + 1
		var next_ok := GameData.crop_in_season(crop_id, (TimeManager.season + 1) % 4)
		if need > left and not next_ok and not FarmState.in_greenhouse(cell):
			EventBus.toast("Attention : il faut %d jours à cette culture, il n'en reste que %d dans la saison." % [need, left])
		_gesture("bend", cell, func() -> void:
			Sfx.play("plant")
			Fx.puff(_entities, cell_center(cell), Color(0.62, 0.45, 0.3, 0.7), 0.9))


func _harvest(cell: Vector2i) -> void:
	var harvest_id := str(GameData.crop(FarmState.get_crop(cell)).get("harvest", ""))
	if not Inventory.can_add(harvest_id):
		EventBus.toast("Inventaire plein !")
		return
	_deferring = true
	# Qualité : compétence d'agriculture, et l'engrais aide beaucoup
	var fertilized := FarmState.is_fertilized(cell)
	var hybrid: bool = FarmState.tiles.get(cell, {}).get("hybrid", false)
	var got := FarmState.harvest(cell)
	if got == "":
		_deferring = false
	if got != "":
		got = GameData.with_quality(got, 3 if hybrid else GameData.roll_quality(Skills.level("farming"), 0.5 if fertilized else 0.0))
		var count := 2 if (hybrid or Skills.roll("farming", 5.0)) and Inventory.can_add(got, 2) else 1
		Inventory.add_item(got, count)
		Skills.add_xp("farming", maxi(3, int(GameData.item(got).get("sell", 30)) / 8))
		Story.bump("harvest", count)
		EventBus.toast("+%d %s" % [count, GameData.item_name(got)])
		_gesture("bend", cell, func() -> void:
			Sfx.play("harvest")
			Settings.vibrate(18)
			Fx.burst(_entities, _cell_fx_point(cell), Fx.GRASS, 10, 50.0)
			for i in count:
				Fx.item_pop(_entities, _cell_fx_point(cell), GameData.item_icon(got), player)
			get_tree().create_timer(0.5).timeout.connect(func() -> void: Sfx.play("pickup")))


## Machine de transformation : récupérer le produit prêt, ou y déposer
## l'objet tenu en main.
func _use_machine(cell: Vector2i) -> void:
	var machine := str(FarmState.objects[cell])
	var name := str(Machines.data[machine].get("name", machine))
	player.face_towards(cell - player_cell())
	if Machines.ready(cell):
		var out := Machines.collect(cell)
		if out == "":
			EventBus.toast("Inventaire plein !")
			return
		player.play_use()
		Sfx.play("harvest")
		Settings.vibrate(20)
		Fx.burst(_entities, cell_center(cell) + Vector2(0, -10), [Color(1, 0.95, 0.6), Color(1, 1, 1)], 10, 45.0)
		Fx.item_pop(_entities, cell_center(cell) + Vector2(0, -8), GameData.item_icon(out), player)
		EventBus.toast("+1 %s" % GameData.item_name(out))
		visual_changed.emit(cell)
		return
	if Machines.busy(cell):
		var s: Dictionary = Machines.state[cell]
		EventBus.toast("%s : %s, prêt dans %d nuit(s)." % [name, GameData.item_name(str(s.output)), int(s.days)])
		return
	var slot: Variant = Inventory.get_selected()
	var r: Array = [] if slot == null else Machines.recipe(machine, str(slot.id))
	if r.is_empty():
		var hint: String = {"preserves_jar": "un fruit ou un légume", "fruit_press": "un fruit ou un légume", "smoker": "un poisson", "cheese_press": "du lait ou un œuf", "cask": "un fromage, un jus, une confiture ou du miel (pas encore cristal)", "oak_cask": "un fromage, un jus, une confiture ou du miel (pas encore cristal)"}.get(machine, "un ingrédient")
		EventBus.toast("%s : prends %s en main, puis touche la machine." % [name, hint])
		return
	var nights := Machines.insert(cell, machine, str(slot.id))
	Inventory.remove_from_slot(Inventory.selected, 1)
	player.play_use()
	Sfx.play("craft")
	Fx.puff(_entities, cell_center(cell) + Vector2(0, -6), Color(0.95, 0.92, 0.85, 0.8), 1.0)
	EventBus.toast("%s : %s dans %d nuit(s)." % [name, GameData.item_name(str(r[0])), nights])
	visual_changed.emit(cell)


func _ship_selected() -> void:
	var slot: Variant = Inventory.get_selected()
	if slot == null or int(GameData.item(slot.id).get("sell", 0)) <= 0 or GameData.item(slot.id).get("type") == "tool":
		EventBus.toast("Sélectionne un objet à vendre, puis touche le coffre.")
		return
	var qty: int = slot.qty
	Sfx.play("coins_2")
	player.play_use()
	FarmState.ship(slot.id, qty)
	EventBus.toast("Expédié : %d x %s (payé cette nuit)" % [qty, GameData.item_name(slot.id)])
	Inventory.remove_from_slot(Inventory.selected, qty)


# ------------------------------------------------------------ affichage
func _on_day_started(day: int, season: int, year: int) -> void:
	super(day, season, year)
	_refresh_all()


func _refresh_all() -> void:
	_soil.clear()
	_objects.clear()
	for cell: Vector2i in FarmState.objects:
		_refresh_object(cell)
	for cell: Vector2i in FarmState.debris:
		_refresh_object(cell)
	for cell: Vector2i in _crop_sprites.keys():
		if FarmState.get_crop(cell) == "":
			_crop_sprites[cell].queue_free()
			_crop_sprites.erase(cell)
	for cell: Vector2i in FarmState.tiles:
		_refresh_soil(cell)
		_refresh_crop(cell)
	visual_reset.emit()


func _refresh_cell(cell: Vector2i) -> void:
	if _deferring:
		_deferred[cell] = true
		return
	# Une parcelle change l'apparence de ses voisines (rangées continues).
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		_refresh_soil(cell + offset)
	_refresh_crop(cell)
	visual_changed.emit(cell)
	_refresh_object(cell)


func _refresh_object(cell: Vector2i) -> void:
	# Banc de jardin : un siège (on s'y assoit) ; retiré, le siège disparaît
	if FarmState.objects.get(cell, "") == "garden_bench":
		if not seats.has(cell):
			add_seat(cell, Vector2i.DOWN)
	elif seats.has(cell):
		seats.erase(cell)
		_interactables.erase(cell)
	match str(FarmState.objects.get(cell, "")):
		"sprinkler":
			_objects.set_cell(cell, 0, WorldTiles.coords(WorldTiles.SPRINKLER))
		"quality_sprinkler":
			_objects.set_cell(cell, 0, WorldTiles.coords(WorldTiles.QUALITY_SPRINKLER))
		"chest":
			_objects.set_cell(cell, 0, WorldTiles.coords(WorldTiles.CHEST))
		"path_wood", "path_stone":
			_objects.set_cell(cell, 0, WorldTiles.coords(WorldTiles.COBBLES))
		"scarecrow", "garden_lantern":
			_objects.set_cell(cell, 0, WorldTiles.coords(WorldTiles.SIGN))
		"garden_bench", "flower_bed", "garden_fountain", "golden_statue":
			_objects.set_cell(cell, 0, WorldTiles.coords(WorldTiles.BARREL if FarmState.objects[cell] in ["garden_fountain", "golden_statue"] else WorldTiles.BUSH))
		"wood_tree":
			var wt := 0 if not Woods.farm.has(cell) else (WorldTiles.STUMP if Woods.is_stump(cell, "farm") else (WorldTiles.BUSH if Woods.stage(cell, "farm") < 3 else (WorldTiles.PINE if Woods.farm[cell].type == "pine" else WorldTiles.ROUND_TREE)))
			if wt != 0:
				_objects.set_cell(cell, 0, WorldTiles.coords(wt))
			else:
				_objects.erase_cell(cell)
		"tree":
			var stage := FarmState.tree_stage(cell)
			_objects.set_cell(cell, 0, WorldTiles.coords([WorldTiles.GRASS_TUFT, WorldTiles.BUSH, WorldTiles.ROUND_TREE][stage]))
		_:
			_objects.erase_cell(cell)
	if FarmState.debris.has(cell):
		var tile: int = {
			"weed": WorldTiles.WEED if _hash(cell) % 2 == 0 else WorldTiles.WEED_2,
			"twig": WorldTiles.TWIG, "stone": WorldTiles.DEBRIS_STONE, "stump": WorldTiles.DEAD_TREE, "meteorite": WorldTiles.DEBRIS_STONE,
		}[FarmState.debris[cell].type]
		_objects.set_cell(cell, 0, WorldTiles.coords(tile))


func _refresh_soil(cell: Vector2i) -> void:
	if not FarmState.is_tilled(cell):
		_soil.erase_cell(cell)
		return
	var left := FarmState.is_tilled(cell + Vector2i.LEFT)
	var right := FarmState.is_tilled(cell + Vector2i.RIGHT)
	var up := FarmState.is_tilled(cell + Vector2i.UP)
	var down := FarmState.is_tilled(cell + Vector2i.DOWN)
	var index := WorldTiles.SOIL_SINGLE
	if left or right:
		index = WorldTiles.SOIL_H_LEFT if not left else (WorldTiles.SOIL_H_RIGHT if not right else WorldTiles.SOIL_H_MID)
	elif up or down:
		index = WorldTiles.SOIL_V_TOP if not up else (WorldTiles.SOIL_V_BOTTOM if not down else WorldTiles.SOIL_V_MID)
	if FarmState.is_watered(cell):
		index += 1
	_soil.set_cell(cell, 0, WorldTiles.coords(index))


func _refresh_crop(cell: Vector2i) -> void:
	var stage := FarmState.crop_stage(cell)
	if stage < 0:
		if _crop_sprites.has(cell):
			_crop_sprites[cell].queue_free()
			_crop_sprites.erase(cell)
		return
	var sprite: Sprite2D = _crop_sprites.get(cell)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.texture = load("res://assets/sprites/crops.png")
		sprite.hframes = CROP_STAGES
		sprite.vframes = maxi(CROP_ROWS, sprite.texture.get_height() / TILE)
		sprite.centered = false
		sprite.offset = Vector2(0, -13)
		sprite.set_meta("no3d", true)
		sprite.position = Vector2(cell.x * TILE, cell.y * TILE + 12)
		_entities.add_child(sprite)
		_crop_sprites[cell] = sprite
	var row := int(GameData.crop(FarmState.get_crop(cell)).get("sprite_row", 0))
	sprite.frame = row * CROP_STAGES + mini(stage, CROP_STAGES - 1)
