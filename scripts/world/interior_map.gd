class_name InteriorMap
extends WorldMap
## Intérieur d'un bâtiment du village (boutiques, mairie, maisons).
## map_id = "in:<bâtiment>". On y entre par la porte du village et on en
## sort en marchant sur le seuil. Les habitants qui y vivent (ou y
## travaillent, aux heures d'ouverture) s'y trouvent.
##
## Plan : # mur, _ plancher, D porte, o place d'un habitant, r tapis,
## t table, c chaise, C comptoir (boutique), S étagère garnie, K bibliothèque
## (lisible), M tableau (lisible), B lit, b tonneau, x coffre, P plante,
## p cheminée, k cuisinière, N enclume (forge), W établi, L bûches, H foin,
## A poussin, F filets et poissons.

const LAYOUTS := {
	"store": {
		"name": "Épicerie de Rosalie", "floor": "light", "wall": "cream",
		"rows": [
			"############",
			"#SSS_SS_SSS#",
			"#____o_____#",
			"#_CCCCCC__b#",
			"#__________#",
			"#P_rrrr___P#",
			"#__rrrr__bb#",
			"#####D######",
		],
	},
	"mairie": {
		"name": "Mairie de Valfleur", "floor": "dark", "wall": "blue", "open": [9, 17],
		"rows": [
			"############",
			"#K_M____K_K#",
			"#____o_____#",
			"#__tttt____#",
			"#__cccc__P_#",
			"#__________#",
			"#P_rrrr___P#",
			"#####D######",
		],
	},
	"gaston": {
		"name": "Forge de Gaston", "floor": "stone", "wall": "stone", "open": [8, 19],
		"rows": [
			"###########",
			"#N_p__b_KB#",
			"#_________#",
			"#__o______#",
			"#_______tc#",
			"#b________#",
			"####D######",
		],
	},
	"menuiserie": {
		"name": "Menuiserie de Mathis", "floor": "light", "wall": "wood",
		"rows": [
			"############",
			"#LL_W__W_LL#",
			"#____o_____#",
			"#_CCCC_____#",
			"#________b_#",
			"#P___rr____#",
			"#####D######",
		],
	},
	"cooperative": {
		"name": "Coopérative de Margot", "floor": "light", "wall": "green",
		"rows": [
			"############",
			"#HH_SS_SS_H#",
			"#____o_____#",
			"#__CCCC__bb#",
			"#__________#",
			"#H_____P__H#",
			"######D#####",
		],
	},
	"ranch": {
		"name": "Ranch de Léon", "floor": "dark", "wall": "wood",
		"rows": [
			"############",
			"#HH_K___HHH#",
			"#____o_____#",
			"#__CCC_____#",
			"#________A_#",
			"#b___rr__A_#",
			"#####D######",
		],
	},
	"odette": {
		"name": "Chez Odette et Théo", "floor": "light", "wall": "cream", "open": [8, 20],
		"rows": [
			"###########",
			"#B__K_k_PB#",
			"#_________#",
			"#__tto_o__#",
			"#__cc_____#",
			"#P__rrr__p#",
			"####D######",
		],
	},
	"lina": {
		"name": "Chez Lina", "floor": "light", "wall": "blue", "open": [8, 20],
		"rows": [
			"###########",
			"#B_P_K_K__#",
			"#_________#",
			"#_o_rrr_tc#",
			"#___rrr___#",
			"#P_______P#",
			"####D######",
		],
	},
	"taverne": {
		"name": "Taverne du Héron", "floor": "dark", "wall": "wood", "map": "port", "open": [16, 24],
		"rows": [
			"##############",
			"#bb_o___K_bbb#",
			"#CCCCCC______#",
			"#____________#",
			"#_tt_o_o_tt__#",
			"#_o_____o__o_#",
			"#_____tt___E_#",
			"#p___o_o___o_#",
			"#____________#",
			"######D#######",
		],
	},
	"comptoir": {
		"name": "Comptoir de Basile", "floor": "light", "wall": "green", "map": "port",
		"rows": [
			"###########",
			"#SSS_x_SSS#",
			"#____o____#",
			"#_CCCCC___#",
			"#_______bb#",
			"#P_rr___bb#",
			"####D######",
		],
	},
	"celeste": {
		"name": "Chez Céleste", "floor": "light", "wall": "blue", "map": "port", "open": [8, 20],
		"rows": [
			"##########",
			"#B__K__P_#",
			"#________#",
			"#_o_rrr__#",
			"#E__rrr__#",
			"#P______p#",
			"####D#####",
		],
	},
	"phare": {
		"name": "Le phare", "floor": "stone", "wall": "stone", "map": "port", "open": [8, 20],
		"rows": [
			"########",
			"#K_o__B#",
			"#______#",
			"#_b__x_#",
			"###D####",
		],
	},
	"jules": {
		"name": "Cabane de Jules", "floor": "dark", "wall": "wood", "open": [8, 20],
		"rows": [
			"###########",
			"#B_bb_F_x_#",
			"#_________#",
			"#__o__tc__#",
			"#_________#",
			"#F__rr___P#",
			"####D######",
		],
	},
}

## Livres et tableaux : un peu de l'histoire de Valfleur
const READINGS := {
	"store": ["Livre de comptes", "Il y a dix ans, l'épicerie vendait des fleurs de toute la vallée pour la fête. Depuis que la fontaine s'est tue, la page des fleurs est restée blanche."],
	"mairie": ["Registre de Valfleur", "« An 1 : Les fondateurs creusent la fontaine au-dessus de la source. An 112 : première Fête des fleurs. Il y a 10 ans : éboulement dans la mine, la source se tarit. Fête annulée. »"],
	"mairie_board": ["Tableau de la mairie", "Projet : faire refleurir Valfleur. 1. Relancer les cultures. 2. Réunir les habitants. 3. Comprendre ce qui s'est passé dans la mine. 4. Une ferme vivante. 5. La Fête des fleurs !"],
	"gaston": ["Carnet de forge", "« Firmin m'a commandé des étais pour la mine, juste avant de partir. Il disait que l'eau chantait encore derrière la roche. »"],
	"ranch": ["Livre d'élevage", "Une poule heureuse pond de plus gros œufs. Une vache brossée chaque jour donne le meilleur lait. Le foin, toujours le foin !"],
	"odette": ["Album photo", "Une photo jaunie : la place de Valfleur couverte de fleurs, Firmin et Odette qui dansent devant la fontaine."],
	"taverne": ["Le livre d'or de la taverne", "« Marius, ta soupe guérit tout, même le mal de mer. - Firmin » L'écriture date de dix ans. Juste en dessous : « Je reviendrai quand le phare brillera. »"],
	"celeste": ["Partitions", "« La chanson de la fontaine » - le dernier couplet est encore blanc."],
	"phare": ["Journal du gardien", "Mille deux cent quarante-trois bateaux guidés. La dernière ligne : « Ce soir, la lanterne s'éteint. Plus d'huile, plus de lentille. Que quelqu'un la rallume un jour. »"],
	"lina": ["Journal de Lina", "« Un jour je peindrai la fontaine qui coule. Grand-mère dit qu'au printemps, l'eau sentait la violette. »"],
}

var building: String = "store"
var floor_style: String = "light"
var wall_style: String = "cream"
var exit_front: Vector2i  # case devant la porte, au village (ou au port)
var exit_map: String = "village"
var residents: Array[Npc] = []
var _spots: Array[Vector2i] = []


func setup(id: String) -> void:
	building = id
	map_id = "in:" + id
	var layout: Dictionary = LAYOUTS.get(id, LAYOUTS["store"])
	floor_style = str(layout.get("floor", "light"))
	wall_style = str(layout.get("wall", "cream"))
	exit_front = PortMap.door_front(id) if layout.get("map", "village") == "port" else Village.door_front(id)
	exit_map = str(layout.get("map", "village"))


func _map_rows() -> Array:
	return LAYOUTS.get(building, LAYOUTS["store"]).rows


func display_name() -> String:
	return str(LAYOUTS.get(building, {}).get("name", "Intérieur"))


## Boutique tenue dans ce bâtiment ("" si aucune).
static func shop_of(id: String) -> String:
	return str(Village.SHOP_DOORS.merged({"taverne": "tavern", "comptoir": "comptoir"}).get(id, ""))


## Peut-on entrer ? Boutique : à ses horaires. Autres : horaires d'ouverture.
static func is_open(id: String) -> bool:
	var shop := shop_of(id)
	if shop != "":
		return Shops.is_open(shop)
	var hours: Array = LAYOUTS.get(id, {}).get("open", [8, 20])
	if id == "mairie" and (TimeManager.day - 1) % 7 >= 5:
		return false  # mairie fermée le week-end
	return TimeManager.minutes >= int(hours[0]) * 60 and TimeManager.minutes < int(hours[1]) * 60


static func closed_text(id: String) -> String:
	var shop := shop_of(id)
	if shop != "":
		return "C'est fermé. " + Shops.hours_text(shop)
	var hours: Array = LAYOUTS.get(id, {}).get("open", [8, 20])
	if id == "mairie":
		return "La mairie est fermée. Ouverte du lundi au vendredi, de %dh à %dh." % [int(hours[0]), int(hours[1])]
	return "La porte est fermée à clé. On reçoit de %dh à %dh." % [int(hours[0]), int(hours[1])]


func _ground_tile(_cell: Vector2i, ch: String) -> int:
	match ch:
		"#":
			return WorldTiles.MINE_WALL
		"D":
			return WorldTiles.MINE_FLOOR_SHADE
		"_", "o", "r":
			return WorldTiles.MINE_FLOOR_2 if ch == "r" else WorldTiles.MINE_FLOOR
	return WorldTiles.BARREL  # meubles : on ne les traverse pas


func _place_special(cell: Vector2i, ch: String) -> void:
	match ch:
		"D":
			_interactables[cell] = "exit"
			_spawn_cell = cell + Vector2i.UP
		"o":
			_spots.append(cell)
		"C":
			_interactables[cell] = "counter"
		"N":
			_interactables[cell] = "forge"
		"K":
			var r: Array = READINGS.get(building, ["Bibliothèque", "Des livres de cuisine, des almanachs et un vieux roman d'aventure."])
			_add_sign(cell, r[0], r[1])
		"M":
			var m: Array = READINGS["mairie_board"]
			_add_sign(cell, m[0], m[1])
		"B":
			_add_sign(cell, "Un lit", "Ce n'est pas ton lit. Mieux vaut ne pas s'y allonger !")
		"S":
			_add_sign(cell, "Étagère", "Des sacs de graines, des bocaux, des outils bien rangés.")


func _after_build() -> void:
	_place_player()
	_spawn_residents()


func _place_player() -> void:
	player.step_sound = "step_stone"
	super()


## Les habitants présents : ceux qui y vivent et sont chez eux, et le
## commerçant pendant ses heures d'ouverture.
func _spawn_residents() -> void:
	var spot := 0
	var ids: Array = GameData.npcs.keys()
	if building == "taverne":
		# Le tavernier d'abord (derrière le comptoir), puis les clients du soir
		ids.erase("marius")
		ids.push_front("marius")
	for id: String in ids:
		if building == "taverne" and id != "marius" and id != Marriage.spouse and Npc.place_at(id, TimeManager.minutes) == "tavern" and not Events.gathering_now():
			var guest := Npc.new()
			guest.id = id
			guest.position = cell_center(_spots[spot] if spot < _spots.size() else _spawn_cell + Vector2i(spot % 5, -3))
			spot += 1
			_entities.add_child(guest)
			residents.append(guest)
			continue
		var data := GameData.npc(id)
		var lives_here := str(data.get("home", "")) == building
		if not lives_here or id == Marriage.spouse or not Npc.is_home_at(id, TimeManager.minutes):
			continue
		var npc := Npc.new()
		npc.id = id
		npc.position = cell_center(_spots[spot] if spot < _spots.size() else _spawn_cell + Vector2i(spot, -2))
		spot += 1
		_entities.add_child(npc)
		residents.append(npc)


func action_hint(cell: Vector2i) -> String:
	if not fishing.busy() and npc_at(cell) != null:
		var slot: Variant = Inventory.get_selected()
		var gift: bool = slot != null and GameData.item(slot.id).get("type") in ["crop", "fish", "forage", "animal", "food"]
		var npc_id := npc_at(cell).id
		if Quests.deliverable(npc_id) >= 0:
			return "Livrer"
		return "Offrir" if gift else "Parler"
	return super(cell)


func npc_at(cell: Vector2i) -> Npc:
	var center := cell_center(cell)
	for npc in residents:
		if npc.position.distance_to(center) < TILE * 0.8:
			return npc
	return null


func act_on(cell: Vector2i) -> void:
	var npc: Npc = npc_at(cell)
	if npc == null and _interactables.get(cell, "") == "counter":
		# Toucher le comptoir : on parle au commerçant derrière
		npc = npc_at(cell + Vector2i.UP)
	if npc != null and _interactables.get(cell, "") != "counter":
		_talk_to(npc)
		return
	super(cell)


func _talk_to(npc: Npc) -> void:
	talk_to_npc(npc)


func _interact(kind: String, _cell: Vector2i) -> void:
	match kind:
		"exit":
			Sfx.play("door")
			EventBus.map_change_requested.emit(exit_map, exit_front)
		"forge":
			EventBus.forge_requested.emit()
		"counter":
			var shop := shop_of(building)
			if shop == "":
				return
			if Shops.is_open(shop):
				EventBus.shop_opened.emit(shop)
			else:
				EventBus.message_requested.emit(str(Shops.info(shop).get("name", "")), "C'est fermé. " + Shops.hours_text(shop))


## Marcher sur le seuil = sortir.
func _warp_for(cell: Vector2i) -> Dictionary:
	if _interactables.get(cell, "") == "exit":
		Sfx.play("door")
		return {"map": exit_map, "cell": exit_front}
	return {}


func _update_tint(_hour: int, _minute: int) -> void:
	_tint.color = Color(1.0, 0.95, 0.88)


const TAVERN_LINES := ["Santé !", "Encore une chanson, Céleste !", "Marius, la même chose !", "Ha ha ha !", "À la tienne !", "Quelle journée...", "Tu as vu la mer, ce soir ?"]
var _chatter: float = 3.0


func _process(delta: float) -> void:
	super(delta)
	# Ambiance de la taverne : on trinque, on chante
	if building != "taverne" or residents.size() < 2:
		return
	_chatter -= delta
	if _chatter <= 0.0:
		_chatter = randf_range(3.0, 6.0)
		var who: Npc = residents[randi() % residents.size()]
		var line: String = "La la la... (Céleste joue de la guitare)" if who.id == "celeste" else TAVERN_LINES[randi() % TAVERN_LINES.size()]
		EventBus.npc_bubble.emit(who.id, line)
