extends Node
## Partenariats avec les nouveaux venus (suite de « L'âme de Valfleur »).
## Quand le joueur favorise les Hauts de Valfleur, leurs commerçants lui
## proposent de s'associer. Chaque partenariat rapporte gros et coûte
## quelque chose ; chacun fait aussi pencher la balance vers les nouveaux
## venus. On signe, on rompt (une rupture fâche, et ferme la porte une
## saison), et un partenariat tombe si le partenaire quitte le village.

signal changed

const BREAK_COOLDOWN := 28  # jours avant de pouvoir re-signer après une rupture
const BREAK_POINTS := -150  # amitié perdue en rompant
const ORDER_QTY := 5
const ORDER_PAY := 2.5  # le Bocal paie 2,5 fois le prix d'expédition
const ORDER_POINTS := 100
const ORDER_LEAN := 3.0  # points de balance par livraison
const MISS_POINTS := -80
const MAX_MISSES := 2  # commandes manquées d'affilée avant la fin du contrat
const NEO_DISCOUNT := 0.75
const NEO_FEE := 0.05  # part des ventes de la nuit reversée à Hugo
const SHOW_BEAUTY := 25  # beauté minimale de la ferme vitrine
const SHOW_GOLD := 15  # or par point de beauté, chaque dimanche
const SHOW_MAX := 3000
const SHOW_LEAN := 2.0
const LABEL_BONUS := 1.10
const LABEL_FEE := 1500  # licence, au premier jour de chaque saison
const LABEL_LEAN := 4.0

## id -> {partenaire, nom, conditions, avantage, revers, lettre}
## (les chiffres des textes reprennent les constantes ci-dessus)
const DEALS := {
	"bocal": {
		"partner": "capucine", "name": "Fournisseur du Bocal", "tilt": 15.0, "tier": 1,
		"perk": "Chaque lundi, Capucine commande 5 produits de qualité argent (ou mieux). Elle les paie 2,5 fois leur prix, et l'amitié suit.",
		"cost": "Une commande manquée la déçoit ; deux d'affilée, et le contrat tombe.",
		"letter": "J'ai une idée : et si le Bocal ne servait plus que les produits de TA ferme ? Je te commande un panier chaque lundi, je le paie bien plus cher que le marché, et j'écris ton nom sur l'ardoise. Il me faut de la belle qualité, et de la régularité. Si ça te tente, signe dans ton Journal, à la page de l'âme de Valfleur.",
	},
	"neo": {
		"partner": "hugo", "name": "Ferme pilote de l'Atelier Néo", "tilt": 25.0, "tier": 1,
		"perk": "Tout l'Atelier Néo à -25 %, et un arroseur connecté offert à la signature.",
		"cost": "Les capteurs de Hugo prélèvent 5 % de chacune de tes ventes expédiées.",
		"letter": "J'ai besoin d'un terrain d'essai, et ta ferme est la mieux tenue de la vallée. Marché : tu deviens ma ferme pilote. Mes machines à prix d'ami, un arroseur connecté offert. En échange, mes capteurs mesurent ce qui sort de tes champs, et je prends une petite part des ventes pour financer la recherche. Tout est dans ton Journal, à la page de l'âme de Valfleur.",
	},
	"lin": {
		"partner": "elise", "name": "Ferme vitrine du Studio Lin", "tilt": 20.0, "tier": 1,
		"perk": "Chaque dimanche, des visiteurs de la ville paient l'entrée : 15 or par point de beauté de la ferme (jusqu'à 3000 or).",
		"cost": "Il faut une beauté d'au moins 25, sinon rien. Et le dimanche, la ferme est aux touristes : les habitants ne viennent plus te rendre visite.",
		"letter": "Ta ferme est ce que j'ai vu de plus juste depuis que je dessine. Je voudrais y amener mes clients de la ville, le dimanche : ils paieront l'entrée, et l'argent sera pour toi. Il faudra la garder belle. Et je te préviens : le dimanche, ce ne sera plus tout à fait chez toi. Si tu veux essayer, signe dans ton Journal, à la page de l'âme de Valfleur.",
	},
	"label": {
		"partner": "capucine", "name": "Label « Valfleur Origine »", "mayor": true,
		"perk": "Tout ce que tu expédies se vend 10 % plus cher, sous le label de la mairie.",
		"cost": "Une licence de 1500 or au premier jour de chaque saison. Impayée, le label est suspendu jusqu'à la saison suivante.",
		"letter": "La mairie lance un label : « Valfleur Origine ». Ta ferme en serait la première. Une étiquette sur chaque cageot, et des acheteurs prêts à payer plus cher. La licence a un prix, je ne vais pas te mentir : le village a besoin de recettes. À signer dans ton Journal, à la page de l'âme de Valfleur.",
	},
}

var offered: Dictionary = {}  # id -> true (proposé par lettre)
var signed: Dictionary = {}  # id -> jour de la signature
var broken: Dictionary = {}  # id -> jour de la rupture
var order: Dictionary = {}  # commande du Bocal : {"item", "qty", "gold", "done"}
var misses: int = 0
var label_paid: bool = true  # licence de la saison réglée
var earned: Dictionary = {}  # id -> or gagné grâce au partenariat
var note: String = ""  # ce que les partenariats ont fait cette nuit


func reset() -> void:
	offered.clear()
	signed.clear()
	broken.clear()
	order.clear()
	misses = 0
	label_paid = true
	earned.clear()
	note = ""


func is_signed(id: String) -> bool:
	return signed.has(id)


## Le partenaire propose-t-il encore ce contrat ? (présent, et balance favorable)
func available(id: String) -> bool:
	var d: Dictionary = DEALS[id]
	if not Soul.arrived or Soul.is_gone(str(d.partner)):
		return false
	if d.get("mayor", false):
		return Soul.modern_mayor()
	return Soul.tilt >= float(d.tilt) or Soul.modern_tier >= int(d.tier)


## Jours à attendre avant de pouvoir re-signer (0 : on peut).
func cooldown(id: String) -> int:
	if not broken.has(id):
		return 0
	return maxi(0, BREAK_COOLDOWN - (Marriage.day_number() - int(broken[id])))


func can_sign(id: String) -> bool:
	return offered.has(id) and not signed.has(id) and available(id) and cooldown(id) == 0


func sign(id: String) -> bool:
	if not can_sign(id):
		return false
	signed[id] = Marriage.day_number()
	broken.erase(id)
	Relations.add_points(str(DEALS[id].partner), 60)
	match id:
		"bocal":
			misses = 0
			_new_order()
		"neo":
			Mail.send_custom("partner_neo_gift_%d" % Marriage.day_number(), {"from": "Hugo, de l'Atelier Néo", "text": "Bienvenue dans le programme pilote ! Voici ton arroseur connecté. Pose-le au milieu d'un champ : il arrose les 24 cases autour de lui.", "items": [["smart_sprinkler", 1]]})
		"label":
			label_paid = true
	Soul.lean(2.0)
	changed.emit()
	return true


## Rompre : le partenaire le prend mal, et ne reproposera rien avant une saison.
func cancel(id: String) -> void:
	if not signed.has(id):
		return
	signed.erase(id)
	broken[id] = Marriage.day_number()
	Relations.add_points(str(DEALS[id].partner), BREAK_POINTS)
	if id == "bocal":
		order.clear()
	changed.emit()


# ------------------------------------------------------------ le Bocal
func _new_order() -> void:
	var pool: Array = []
	for crop: String in GameData.crops:
		if GameData.crop_in_season(crop, TimeManager.season):
			pool.append(str(GameData.crop(crop).get("harvest", crop)))
	if pool.is_empty() or not Animals.animals.is_empty():
		pool.append_array(["egg", "milk"])
	var item := str(pool[Marriage.day_number() % pool.size()])
	var value := maxi(10, int(GameData.item(item).get("sell", 10)))
	order = {"item": item, "qty": ORDER_QTY, "gold": int(value * ORDER_QTY * ORDER_PAY), "done": false}


## Combien d'objets de la commande (qualité argent ou mieux) sont dans le sac.
func order_have() -> int:
	return 0 if order.is_empty() else Inventory.count_min_quality(str(order.item), 1)


func can_deliver() -> bool:
	return signed.has("bocal") and not order.is_empty() and not order.done and order_have() >= int(order.qty)


func deliver() -> bool:
	if not can_deliver():
		return false
	Inventory.remove_min_quality(str(order.item), int(order.qty), 1)
	Inventory.add_gold(int(order.gold))
	order.done = true
	misses = 0
	_earn("bocal", int(order.gold))
	Relations.add_points("capucine", ORDER_POINTS)
	Soul.lean(ORDER_LEAN)
	Story.bump("quests")
	changed.emit()
	return true


func order_text() -> String:
	if order.is_empty():
		return ""
	if order.done:
		return "Commande de la semaine livrée. La prochaine arrive lundi."
	var left := 7 - (TimeManager.day - 1) % 7
	return "Commande : %s x%d, qualité argent ou mieux, pour %d or. Dans ton sac : %d. Encore %d jour%s." % [GameData.item_name(str(order.item)), int(order.qty), int(order.gold), order_have(), left, "s" if left > 1 else ""]


# ------------------------------------------------------------ effets
## Prix à l'Atelier Néo pour une ferme pilote.
func price_factor(shop: String) -> float:
	return NEO_DISCOUNT if shop == "outils" and signed.has("neo") else 1.0


## Prix d'expédition sous le label de la mairie.
func sell_factor() -> float:
	return LABEL_BONUS if signed.has("label") and label_paid else 1.0


## Ce que Hugo prélève sur les ventes de la nuit.
func take_fee(sales: int) -> int:
	if not signed.has("neo") or sales <= 0:
		return 0
	var fee := int(sales * NEO_FEE)
	Soul.record("outils", fee)
	return fee


## Le dimanche, la ferme vitrine reçoit des touristes (pas les habitants).
func showroom_day() -> bool:
	return signed.has("lin") and (TimeManager.day - 1) % 7 == 6


func _earn(id: String, gold: int) -> void:
	earned[id] = int(earned.get(id, 0)) + gold


# ------------------------------------------------------------ chaque nuit
func new_day() -> void:
	note = ""
	var today := Marriage.day_number()
	var notes: Array = []
	# Un partenaire parti, ou une mairie qui a changé : le contrat tombe
	for id: String in signed.keys():
		var d: Dictionary = DEALS[id]
		if Soul.is_gone(str(d.partner)) or (d.get("mayor", false) and not Soul.modern_mayor()):
			signed.erase(id)
			if id == "bocal":
				order.clear()
			notes.append("%s : le contrat a pris fin." % d.name)
	# Nouvelles propositions, par lettre
	for id: String in DEALS:
		if not offered.has(id) and available(id):
			offered[id] = true
			var d: Dictionary = DEALS[id]
			var who := "Capucine, maire de Valfleur" if d.get("mayor", false) else "%s, %s" % [GameData.npc(str(d.partner)).name, GameData.npc(str(d.partner)).title]
			Mail.send_custom("partner_offer_" + id, {"from": who, "text": str(d.letter)})
	var weekday := (TimeManager.day - 1) % 7
	# Le Bocal : chaque lundi, bilan de la semaine et nouvelle commande
	if signed.has("bocal") and weekday == 0 and int(signed.bocal) < today:
		if not order.is_empty() and not order.done:
			misses += 1
			Relations.add_points("capucine", MISS_POINTS)
			if misses >= MAX_MISSES:
				signed.erase("bocal")
				broken["bocal"] = today
				order.clear()
				Mail.send_custom("partner_bocal_end_%d" % today, {"from": "Capucine, du Bocal", "text": "Deux semaines sans panier... Je ne peux pas tenir une carte sans produits. J'arrête notre contrat, sans rancune : une ferme a ses saisons. On en reparlera plus tard, si tu veux."})
			else:
				notes.append("Tu as manqué la commande du Bocal. Capucine est déçue.")
		if signed.has("bocal"):
			_new_order()
			notes.append("Nouvelle commande du Bocal : %s x%d, de qualité." % [GameData.item_name(str(order.item)), int(order.qty)])
	# Le Studio Lin : les entrées du dimanche (encaissées le soir)
	if signed.has("lin") and weekday == 0 and int(signed.lin) < today:
		var beauty := FarmState.beauty()
		if beauty >= SHOW_BEAUTY:
			var gold := mini(beauty * SHOW_GOLD, SHOW_MAX)
			Inventory.add_gold(gold)
			_earn("lin", gold)
			Soul.lean(SHOW_LEAN)
			notes.append("Ferme vitrine : les visiteurs d'hier ont laissé %d or." % gold)
		else:
			notes.append("Ferme vitrine : pas assez belle hier (beauté %d, il faut %d). Aucun visiteur." % [beauty, SHOW_BEAUTY])
	# Le label : licence au premier jour de la saison
	if signed.has("label") and TimeManager.day == 1 and int(signed.label) < today:
		label_paid = Inventory.spend_gold(LABEL_FEE)
		if label_paid:
			Soul.lean(LABEL_LEAN)
			notes.append("Licence du label réglée : %d or." % LABEL_FEE)
		else:
			notes.append("Licence du label impayée : le label est suspendu cette saison.")
	note = " ".join(notes)
	changed.emit()


## Les partenariats à montrer dans le journal (proposés ou signés).
func known() -> Array:
	var out: Array = []
	for id: String in DEALS:
		if offered.has(id) or signed.has(id):
			out.append(id)
	return out


## État d'un partenariat, en une phrase.
func status(id: String) -> String:
	if signed.has(id):
		var gained := int(earned.get(id, 0))
		var text := "Signé."
		if id == "bocal":
			text = order_text()
		elif id == "label" and not label_paid:
			text = "Suspendu : licence impayée cette saison."
		return text + (" Gagné jusqu'ici : %d or." % gained if gained > 0 else "")
	if Soul.is_gone(str(DEALS[id].partner)):
		return "%s a quitté Valfleur." % GameData.npc(str(DEALS[id].partner)).name
	if cooldown(id) > 0:
		return "Rompu. À rediscuter dans %d jours." % cooldown(id)
	if not available(id):
		return "La proposition ne tient plus : la balance ne penche plus assez vers les nouveaux venus."
	return "Proposé."


func to_dict() -> Dictionary:
	return {"offered": offered.keys(), "signed": signed.duplicate(), "broken": broken.duplicate(), "order": order.duplicate(),
		"misses": misses, "label_paid": label_paid, "earned": earned.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	for id: Variant in data.get("offered", []):
		if DEALS.has(str(id)):
			offered[str(id)] = true
	for key: String in ["signed", "broken", "earned"]:
		var d: Dictionary = data.get(key, {})
		for id: String in d:
			if DEALS.has(id):
				(get(key) as Dictionary)[id] = int(d[id])
	var o: Dictionary = data.get("order", {})
	if o.has("item"):
		order = {"item": str(o.item), "qty": int(o.get("qty", ORDER_QTY)), "gold": int(o.get("gold", 0)), "done": bool(o.get("done", false))}
	misses = int(data.get("misses", 0))
	label_paid = bool(data.get("label_paid", true))
