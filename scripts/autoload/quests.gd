extends Node
## Tableau des demandes (panneau de la place) : chaque jour, quelques
## habitants demandent un objet. On accepte une demande (3 au plus), on
## apporte l'objet à l'habitant en lui parlant : or et amitié en récompense.

signal changed

const MAX_ACTIVE := 3
const OFFERS_PER_DAY := 3

var active: Array = []  # [{"npc", "item", "qty", "quality", "gold", "points", "days_left", "text"}]
## Qualité minimale demandée (0 normale, 1 argent, 2 or) : plus rare, mieux payée.
const QUALITY_REWARD := [1.0, 1.6, 2.4]
var taken_today: Dictionary = {}  # index d'offre -> true
var completed: int = 0

const LINES := [
	"J'aurais besoin de %s pour %s.",
	"Quelqu'un aurait %s ? C'est pour %s.",
	"Je cherche %s, pour %s. Merci d'avance !",
]
const REASONS := {
	"rosalie": ["remplir mes étagères", "une recette de grand-mère"],
	"gaston": ["un essai à la forge", "mon déjeuner"],
	"odette": ["une tarte pour Théo", "mon herbier"],
	"lina": ["un tableau de nature morte", "trouver la bonne couleur"],
	"bertrand": ["le banquet de la mairie", "la vitrine de la mairie"],
	"mathis": ["un nouveau meuble", "nourrir l'équipe du chantier"],
	"margot": ["les clients de la coopérative", "un échange avec la ville"],
	"leon": ["mes bêtes", "un concours d'éleveurs"],
	"theo": ["mon goûter", "ma collection secrète"],
	"jules": ["un appât spécial", "mon dîner au bord de l'eau"],
}


func reset() -> void:
	active.clear()
	taken_today.clear()
	completed = 0
	changed.emit()


## Objets que l'on peut demander en ce moment (de saison, accessibles).
func _pool() -> Array:
	var pool: Array = []
	for crop: String in GameData.crops:
		if GameData.crop_in_season(crop, TimeManager.season):
			pool.append([str(GameData.crop(crop).get("harvest", crop)), 3, 6])
	for id: String in GameData.items:
		var item := GameData.item(id)
		match str(item.get("type", "")):
			"forage":
				if GameData.items[id].get("seasons", [TimeManager.season]).has(float(TimeManager.season)) or not item.has("seasons"):
					pool.append([id, 1, 3])
			"fish":
				if id in ["roach", "carp", "perch", "trout", "bream", "sardine", "mackerel"]:
					pool.append([id, 1, 2])
	pool.append(["wood", 20, 40])
	pool.append(["stone", 15, 30])
	if PlayerState.flags.has("mine_kit"):
		pool.append(["copper_ore", 5, 10])
		pool.append(["coal", 3, 6])
	if not Animals.animals.is_empty():
		pool.append(["egg", 2, 4])
	return pool


## Les demandes affichées aujourd'hui (les mêmes toute la journée).
func offers() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["demandes", TimeManager.year, TimeManager.season, TimeManager.day])
	var pool := _pool()
	var npcs: Array = GameData.npcs.keys()
	var out: Array = []
	for i in OFFERS_PER_DAY:
		var pick: Array = pool[rng.randi() % pool.size()]
		var npc: String = npcs[rng.randi() % npcs.size()]
		var qty := rng.randi_range(int(pick[1]), int(pick[2]))
		var item := str(pick[0])
		var value := maxi(10, int(GameData.item(item).get("sell", 10)))
		var reasons: Array = REASONS.get(npc, ["me rendre service"])
		# Certaines demandes exigent une qualité (argent ou or) : moins
		# d'objets, mais bien mieux récompensés.
		var quality := 0
		if GameData.has_quality(item):
			var r := rng.randf()
			quality = 2 if r < 0.15 else (1 if r < 0.45 else 0)
			if quality > 0:
				qty = maxi(1, qty - quality)
		var what := "%d %s" % [qty, GameData.item_name(item).to_lower()]
		if quality > 0:
			what += " de qualité %s (ou mieux)" % GameData.QUALITY_NAMES[quality]
		out.append({
			"npc": npc, "item": item, "qty": qty, "quality": quality,
			"gold": int((value * qty * 1.3 + 40) * QUALITY_REWARD[quality] * Soul.request_factor()), "points": 120 + 40 * quality,
			"days_left": 3,
			"text": LINES[rng.randi() % LINES.size()] % [what, reasons[rng.randi() % reasons.size()]],
		})
	return out


func can_accept(index: int) -> bool:
	return active.filter(func(q: Dictionary) -> bool: return not q.get("big", false)).size() < MAX_ACTIVE and not taken_today.has(index)


func accept(index: int) -> bool:
	if not can_accept(index):
		return false
	var q: Dictionary = offers()[index].duplicate()
	active.append(q)
	taken_today[index] = true
	changed.emit()
	return true


## Demande en cours pour cet habitant, que l'on peut livrer maintenant.
func deliverable(npc_id: String) -> int:
	for i in active.size():
		var q: Dictionary = active[i]
		if q.npc == npc_id and have(q) >= int(q.qty):
			return i
	return -1


## Combien d'objets conviennent (bonne qualité) dans le sac.
func have(q: Dictionary) -> int:
	return Inventory.count_min_quality(str(q.item), int(q.get("quality", 0)))


## Livre la demande : retire les objets, donne la récompense.
func deliver(index: int) -> Dictionary:
	var q: Dictionary = active[index]
	Inventory.remove_min_quality(str(q.item), int(q.qty), int(q.get("quality", 0)))
	Inventory.add_gold(int(q.gold))
	Relations.add_points(str(q.npc), int(q.points))
	active.remove_at(index)
	completed += 1
	Story.bump("quests")
	changed.emit()
	return q


func new_day() -> void:
	taken_today.clear()
	for q: Dictionary in active.duplicate():
		q.days_left = int(q.days_left) - 1
		if int(q.days_left) <= 0:
			active.erase(q)
	if TimeManager.weekday() == "Lun.":
		weekly_order()
	changed.emit()


## Commande de la semaine (chaque lundi) : un commerçant passe une grosse
## commande, à livrer en 7 jours ; bien mieux payée que l'expédition. Elle
## s'ajoute aux demandes, même si elles sont déjà trois.
const ORDER_FROM := {
	"rosalie": "son épicerie", "margot": "la coopérative", "marius": "la taverne", "basile": "son comptoir",
}


func weekly_order() -> void:
	for q: Dictionary in active:
		if q.get("big", false):
			return  # une seule à la fois
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["commande", TimeManager.year, TimeManager.season, TimeManager.day])
	var pool := _pool().filter(func(p: Array) -> bool: return not str(p[0]) in ["wood", "stone"])
	if pool.is_empty():
		return
	var pick: Array = pool[rng.randi() % pool.size()]
	var npc: String = ORDER_FROM.keys()[rng.randi() % ORDER_FROM.size()]
	if npc in ["marius", "basile"] and not PlayerState.flags.has("story_port"):
		npc = "rosalie"
	var item := str(pick[0])
	var qty := int(pick[2]) * 3
	var value := maxi(10, int(GameData.item(item).get("sell", 10)))
	var what := "%d %s" % [qty, GameData.item_name(item).to_lower()]
	var q := {
		"npc": npc, "item": item, "qty": qty, "quality": 0, "big": true,
		"gold": int(value * qty * 2.2 + 150), "points": 250, "days_left": 7,
		"text": "Commande de la semaine pour %s : %s." % [ORDER_FROM[npc], what],
	}
	active.append(q)
	Mail.send_custom("commande_%d_%d_%d" % [TimeManager.year, TimeManager.season, TimeManager.day], {
		"from": str(GameData.npc(npc).get("name", npc)),
		"text": "Bonjour ! J'ai une grosse commande pour %s cette semaine : %s, d'ici 7 jours. Je paie %d pièces d'or à la livraison, bien plus que l'expédition. Viens me voir quand tu as tout !" % [ORDER_FROM[npc], what, int(q.gold)],
	})


func to_dict() -> Dictionary:
	return {"active": active.duplicate(true), "taken": taken_today.keys(), "completed": completed}


func from_dict(data: Dictionary) -> void:
	reset()
	for q: Variant in data.get("active", []):
		if q is Dictionary:
			active.append(q)
	for k: Variant in data.get("taken", []):
		taken_today[int(k)] = true
	completed = int(data.get("completed", 0))
	changed.emit()
