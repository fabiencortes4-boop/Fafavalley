extends Node
## L'âme de Valfleur. Au chapitre 3, trois nouveaux venus de la ville
## ouvrent boutique dans un lotissement neuf (« Les Hauts de Valfleur »).
## Chaque pièce d'or dépensée chez eux ou chez les artisans fait pencher
## une balance. Quand elle penche assez longtemps d'un côté, le village
## change pour de bon :
## - côté nouveaux venus : les loyers montent, un habitant part (et un
##   nouveau venu reprend sa maison), les beaux produits se vendent plus
##   cher ; au troisième palier, une nouvelle maire est élue ;
## - côté artisans : les prix baissent, la forge apprend de nouveaux
##   gestes, les voisins s'entraident ; un nouveau venu repart à chaque palier.
## Le village ne change que trois fois en tout : 3/0, 0/3 ou un partage.
## Un départ est définitif. Il n'y a pas de mauvais choix.

signal changed

const ARRIVAL_CHAPTER := 3
const ARRIVAL_DELAY := 2  # jours entre l'annonce et l'installation
const GOLD_PER_POINT := 200.0
const THRESHOLDS := [30, 60, 90]  # points de balance pour chaque palier
const WARN_MARGIN := 10  # l'habitant menacé s'inquiète avant le palier
const NOTICE_DAYS := 3  # préavis : le changement arrive si la balance tient
const MAX_CHANGES := 3
const TILT_MAX := 100.0

## Boutiques des nouveaux venus -> qui les tient
const MODERN_SHOPS := {"bocal": "capucine", "outils": "hugo", "studio": "elise"}
const ARTISAN_SHOPS := ["store", "cooperative", "ranch", "carpenter", "tavern", "comptoir", "forge"]
## Voie des nouveaux venus : qui part à chaque palier, qui reprend la maison
const MODERN_STEPS := [
	{"leave": ["odette", "theo"], "arrive": "sacha", "house": "odette"},
	{"leave": ["lina"], "arrive": "ines", "house": "lina"},
	{"leave": ["gaston"], "arrive": "", "house": "gaston"},
]
## Voie des artisans : le nouveau venu qui repart à chaque palier
const ARTISAN_STEPS := ["elise", "capucine", "hugo"]
const NEWCOMERS := ["capucine", "hugo", "elise", "sacha", "ines"]
const NEW_MAYOR := "capucine"
const REUNION := [2, 16]  # la Fête des récoltes : ceux qui sont partis reviennent pour la journée
const HELPERS := ["rosalie", "margot", "mathis", "leon", "gaston", "odette"]

## Lettres d'adieu de ceux qui partent
const FAREWELLS := {
	"odette": {
		"from": "Odette, la jardinière",
		"text": "Le loyer a doublé, et mon jardin ne nourrit pas un propriétaire. Théo et moi partons chez ma sœur, dans la vallée voisine. Ne sois pas triste : j'ai vu naître tant de printemps ici que j'en emporte plein les poches. Sème ces graines pour moi. Nous reviendrons pour la Fête des récoltes, promis.",
		"items": [["seed_sunflower", 10], ["flower_bed", 2]],
	},
	"lina": {
		"from": "Lina, la peintre",
		"text": "Mon atelier est devenu trop cher pour quelqu'un qui vend trois toiles par saison. Une galerie de la ville m'offre un mur et un lit : je pars peindre ailleurs. Valfleur a changé de couleurs... ce n'est ni mieux ni moins bien, c'est un autre tableau. Garde celui-ci, c'est le village tel que je l'ai aimé. On se voit à la Fête des récoltes !",
		"items": [["painting", 1]],
	},
	"gaston": {
		"from": "Gaston, le forgeron",
		"text": "Trente ans que je bats le fer ici. On me rachète la forge trois fois ce qu'elle vaut : à mon âge, ça ne se refuse pas. Hugo reprend l'enclume, il fera ça proprement, à sa façon. Ne te laisse pas dire que j'ai été chassé : j'ai choisi. Tiens, du bon minerai, et pense à moi quand ça chauffe. Je reviendrai trinquer à la Fête des récoltes.",
		"items": [["iron_ore", 12], ["coal", 10]],
	},
	"elise": {
		"from": "Élise, du Studio Lin",
		"text": "Je ferme le studio. Ici, on préfère une chaise réparée à une chaise dessinée, et au fond c'est très beau. Je repars en ville avec des carnets pleins de vos granges et de vos enseignes. Merci pour l'accueil : Valfleur m'a appris à ne pas toucher à ce qui tient debout.",
		"items": [["house_plant", 1]],
	},
	"capucine": {
		"from": "Capucine, du Bocal",
		"text": "Le Bocal baisse le rideau. Les gens d'ici boivent leur café chez Marius et achètent leurs légumes chez Rosalie, et ils ont bien raison : c'est leur village. J'ouvrirai ailleurs, plus humblement. Finis mes derniers bocaux, ils sont à toi.",
		"items": [["buddha_bowl", 3], ["oat_latte", 3]],
	},
	"hugo": {
		"from": "Hugo, de l'Atelier Néo",
		"text": "J'ai compris en regardant Gaston réparer ma propre motobineuse avec un bout de fil de fer. Mes machines n'ont rien à apprendre à ce village. Je remballe, sans rancune. Mathis reprend le local pour former des apprentis : c'est une belle fin pour un atelier.",
		"items": [["coal", 15]],
	},
}
## Lettres des nouveaux venus qui reprennent une maison
const ARRIVALS := {
	"sacha": {
		"from": "Sacha, ton nouveau voisin",
		"text": "Bonjour ! Je viens d'emménager dans la petite maison au toit rouge des résidences. Je travaille à distance, je donne des cours de yoga, et je n'ai jamais vu un potager d'aussi près. On m'a dit que la dame d'avant y faisait pousser des merveilles : j'essaierai d'en être digne. Passe quand tu veux !",
	},
	"ines": {
		"from": "Inès, galeriste",
		"text": "Enchantée ! J'ai repris l'atelier de la peintre pour en faire une galerie : murs blancs, grandes vitres, et tes paysages dehors en guise d'exposition permanente. Viens voir, l'entrée est libre.",
	},
}
## Ce que chaque palier change (affiché dans le journal et dans les lettres)
const MODERN_PERKS := [
	"Les produits de qualité et transformés se vendent 10 % plus cher. L'Atelier Néo sort la tronçonneuse et le marteau-piqueur.",
	"Vente des beaux produits : +20 %. L'arroseur connecté arrive à l'Atelier Néo, une terrasse s'installe devant le Bocal.",
	"Vente des beaux produits : +30 %. Nouvelle maire : affiches en ville, fêtes transformées et prix des concours doublés.",
]
const MODERN_COSTS := [
	"Odette et Théo sont partis. Les boutiques des artisans augmentent de 10 %.",
	"Lina est partie. Les boutiques des artisans augmentent de 20 %.",
	"Gaston est parti (la forge coûte bien plus cher). Boutiques des artisans : +30 %. Les fêtes rapprochent moins les habitants.",
]
const ARTISAN_PERKS := [
	"Les boutiques des artisans baissent de 5 %. Gaston forge la houe et l'arrosoir d'acier.",
	"Prix des artisans : -10 %. Les voisins arrosent parfois tes cultures et déposent un panier le dimanche. Demandes payées 15 % de plus. Gaston forge les outils du maître.",
	"Prix des artisans : -15 %. Demandes payées 30 % de plus. Les fêtes sont plus grandes : deux fois plus d'amitié.",
]
const ARTISAN_COSTS := [
	"Élise a fermé le Studio Lin : plus de mobilier ni de décor design.",
	"Capucine a fermé le Bocal : plus de plats qui rendent autant d'énergie.",
	"Hugo a fermé l'Atelier Néo : plus de machines ni d'arrosage connecté.",
]
## Les fêtes sous la nouvelle maire
const MODERN_FESTIVALS := {
	"spring_fair": {"name": "Marché des créateurs", "activity": "market", "bubble": "Tu as vu le stand de céramique ?",
		"desc": "Le concours des semis laisse la place à un marché de créateurs : le stand vend des pièces rares, de 9h à 15h.",
		"letter": "Demain, premier Marché des créateurs sur la place, de 9h à 15h ! Stands, objets rares et café de spécialité. Les boutiques seront fermées pendant l'événement."},
	"lantern_night": {"name": "Nuit électro des lanternes", "bubble": "Monte le son !",
		"desc": "Les lanternes sont à LED et la fontaine sert de piste : invite quelqu'un à danser au stand !",
		"letter": "Demain soir, Nuit électro des lanternes, de 18h à 23h ! DJ sur la place, lanternes lumineuses et piste autour de la fontaine."},
	"harvest_fest": {"name": "Valfleur Food Festival", "bubble": "Tu as goûté le stand du Bocal ?",
		"desc": "Le grand concours d'automne, avec un jury venu de la ville : les prix sont doublés.",
		"letter": "Demain, Valfleur Food Festival ! Concours des plus beaux produits sur la place, de 9h à 15h, jury invité et prix doublés."},
	"winter_market": {"name": "Marché de Noël des créateurs", "bubble": "Un vin chaud bio ?",
		"desc": "Chalets blancs, guirlandes et produits rares au stand, de 10h à 16h.",
		"letter": "Demain, Marché de Noël des créateurs sur la place, de 10h à 16h. Pièces uniques et produits rares !"},
	"fireworks": {"name": "Spectacle de lumières", "bubble": "C'est plus silencieux qu'avant, non ?",
		"desc": "Un grand spectacle lumineux au-dessus de la place. Assieds-toi sur un banc et lève les yeux !",
		"letter": "Demain soir, grand Spectacle de lumières sur la place, de 20h à 23h. Venez nombreux !"},
	"pumpkin_fair": {"name": "Foire bio et locale", "bubble": "Tout est local, ici !",
		"desc": "La foire de fin d'automne, version circuit court : le jury ne regarde que les récoltes, et les prix sont doublés.",
		"letter": "Demain, Foire bio et locale sur la place ! Concours réservé aux récoltes, prix doublés."},
	"ice_fishing": {"name": "Pêche givrée", "bubble": "Un thé chaud après la pêche ?",
		"desc": "L'étang est gelé : concours de pêche, bain nordique et thé fumant. Les prix sont doublés.",
		"letter": "Demain, Pêche givrée à l'étang, de 8h à 14h : concours du plus beau poisson, prix doublés."},
}
## Affiches de la nouvelle mairie (grands panneaux le long de la route)
const BILLBOARDS := [
	[Vector2i(6, 21), "LE BOCAL\nBrunch tous les jours", Color(0.2, 0.5, 0.45)],
	[Vector2i(33, 21), "VALFLEUR 2.0\nVivez la campagne", Color(0.85, 0.4, 0.3)],
	[Vector2i(46, 21), "ATELIER NÉO\nLe geste augmenté", Color(0.25, 0.3, 0.5)],
]
const TERRACE := [Vector2i(26, 36), Vector2i(27, 36)]
const STALLS := [Vector2i(18, 21), Vector2i(19, 21)]

var arrived: bool = false
var arrival_day: int = 0  # jour d'installation annoncé (0 : pas encore)
var tilt: float = 0.0  # > 0 : vers les nouveaux venus ; < 0 : vers les artisans
var modern_tier: int = 0
var artisan_tier: int = 0
var warned: Dictionary = {}  # "modern:0" -> true (inquiétude déjà exprimée)
var notice: Dictionary = {}  # préavis en cours : {"side": String, "day": int}
var stayed: Array = []  # ceux qui devaient partir mais sont restés (mariage)
var ended: bool = false
var visiting: bool = false  # jour des retrouvailles : les anciens sont de passage
var note: String = ""  # ce qui s'est passé cette nuit (affiché au réveil)
## Pas de hasard pendant les tests automatiques
var random_events: bool = DisplayServer.get_name() != "headless"
var _titles: Dictionary = {}  # titres d'origine (le maire, Capucine)
var _event_letters: Dictionary = {}  # lettres de fêtes d'origine


func _ready() -> void:
	for id: String in ["bertrand", NEW_MAYOR]:
		_titles[id] = str(GameData.npc(id).get("title", ""))
	for f: Dictionary in Events.festivals:
		var key := "event_" + str(f.id)
		if Mail.letters.has(key):
			_event_letters[key] = (Mail.letters[key] as Dictionary).duplicate()


func reset() -> void:
	arrived = false
	arrival_day = 0
	tilt = 0.0
	modern_tier = 0
	artisan_tier = 0
	warned.clear()
	notice.clear()
	stayed.clear()
	ended = false
	visiting = false
	note = ""
	_apply()


func changes() -> int:
	return modern_tier + artisan_tier


## Tout est joué : le village ne changera plus.
func settled() -> bool:
	return changes() >= MAX_CHANGES


## "modern", "artisan" ou "shared" une fois le village fixé ("" avant).
func outcome() -> String:
	if not settled():
		return ""
	if modern_tier >= MAX_CHANGES:
		return "modern"
	return "artisan" if artisan_tier >= MAX_CHANGES else "shared"


func mayor() -> String:
	return NEW_MAYOR if modern_tier >= 3 else "bertrand"


func modern_mayor() -> bool:
	return mayor() == NEW_MAYOR


## Signature des lettres de la mairie.
func mayor_from() -> String:
	return "Capucine, maire de Valfleur" if modern_mayor() else "Bertrand, maire de Valfleur"


## Habitants partis pour de bon (anciens et nouveaux venus).
func gone() -> Array:
	var out: Array = []
	for i in modern_tier:
		for id: String in MODERN_STEPS[i].leave:
			if not id in stayed:
				out.append(id)
	for i in artisan_tier:
		out.append(ARTISAN_STEPS[i])
	return out


func is_gone(id: String) -> bool:
	return id in gone()


## Une lettre signée d'un habitant parti ne part plus du village.
func silent(from: String) -> bool:
	for id: String in gone():
		if from.begins_with(str(GameData.npc(id).get("name", "?")) + ","):
			return true
	return false


## La forge a changé de mains (Gaston est parti).
func forge_taken() -> bool:
	return is_gone("gaston")


## La maison de cet habitant a été reprise par un nouveau venu.
func house_taken(house: String) -> bool:
	for i in modern_tier:
		var step: Dictionary = MODERN_STEPS[i]
		if str(step.house) == house and not str(step.leave[0]) in stayed:
			return true
	return false


# ------------------------------------------------------------ population
## Met le village en accord avec l'état : qui est là, qui est maire.
func _apply() -> void:
	var away := gone()
	for id: String in NEWCOMERS:
		GameData.unwelcome(id)
	for step: Dictionary in MODERN_STEPS:
		for id: String in step.leave:
			GameData.come_back(id)
	if arrived:
		for shop: String in MODERN_SHOPS:
			if not MODERN_SHOPS[shop] in away:
				GameData.welcome(str(MODERN_SHOPS[shop]))
	for i in modern_tier:
		var step: Dictionary = MODERN_STEPS[i]
		if str(step.arrive) != "" and house_taken(str(step.house)):
			GameData.welcome(str(step.arrive))
	if not visiting:
		for id: String in away:
			GameData.depart(id)
	# Le maire
	var b := GameData.npc("bertrand")
	if not b.is_empty():
		b["title"] = "l'ancien maire" if modern_mayor() else _titles.get("bertrand", "le maire")
	var c := GameData.npc(NEW_MAYOR)
	if not c.is_empty():
		c["title"] = "la maire" if modern_mayor() else _titles.get(NEW_MAYOR, "")
	# Les lettres d'annonce des fêtes
	for f: Dictionary in Events.festivals:
		var key := "event_" + str(f.id)
		if not _event_letters.has(key):
			continue
		var letter: Dictionary = (_event_letters[key] as Dictionary).duplicate()
		letter["from"] = mayor_from()
		letter["text"] = festival(f).get("letter", letter.get("text", ""))
		Mail.letters[key] = letter


## Est-ce un ancien de passage pour la journée ?
func is_visitor(id: String) -> bool:
	return visiting and is_gone(id)


# ------------------------------------------------------------ la balance
func side_of(shop: String) -> String:
	if MODERN_SHOPS.has(shop):
		return "modern"
	if shop == "forge":
		return "modern" if forge_taken() else "artisan"
	return "artisan" if shop in ARTISAN_SHOPS else ""


## Un achat : la balance penche du côté de la boutique.
func record(shop: String, gold: int) -> void:
	if not arrived or gold <= 0:
		return
	var side := side_of(shop)
	if side == "":
		return
	var points := gold / GOLD_PER_POINT
	tilt = clampf(tilt + (points if side == "modern" else -points), -TILT_MAX, TILT_MAX)
	changed.emit()


## Un soutien qui n'est pas un achat (partenariat) : la balance penche vers
## les nouveaux venus (points > 0) ou vers les artisans (points < 0).
func lean(points: float) -> void:
	if not arrived:
		return
	tilt = clampf(tilt + points, -TILT_MAX, TILT_MAX)
	changed.emit()


## Prix dans une boutique d'artisan : les loyers montent ou la vie s'adoucit.
func price_factor(shop: String) -> float:
	if MODERN_SHOPS.has(shop) or (shop != "forge" and not shop in ARTISAN_SHOPS):
		return 1.0
	var f := 1.0 + 0.10 * modern_tier - 0.05 * artisan_tier
	if shop == "forge" and forge_taken():
		f += 0.3
	return f


## Prix de vente : en ville nouvelle, on paie cher ce qui est beau.
func sell_factor(item_id: String) -> float:
	if modern_tier <= 0:
		return 1.0
	var fine: bool = GameData.quality_of(item_id) >= 1 or str(GameData.item(item_id).get("type", "")) in ["artisan", "food"]
	return 1.0 + 0.10 * modern_tier if fine else 1.0


## Récompense des demandes des habitants.
func request_factor() -> float:
	return 1.0 + 0.15 * maxi(artisan_tier - 1, 0)


## Or des concours (jury de la ville) et amitié gagnée aux fêtes.
func prize_factor() -> float:
	return 2.0 if modern_mayor() else 1.0


func fete_factor() -> float:
	if modern_mayor():
		return 0.5
	return 2.0 if artisan_tier >= 3 else 1.0


## Objet d'une boutique de nouveau venu : disponible à ce palier ?
func in_stock(shop: String, item_id: String) -> bool:
	var tiers: Dictionary = Shops.info(shop).get("tiers", {})
	return int(tiers.get(item_id, 0)) <= modern_tier


## Recette d'artisan : débloquée à ce palier ?
func recipe_unlocked(recipe: Dictionary) -> bool:
	return int(recipe.get("soul", 0)) <= artisan_tier and not (int(recipe.get("soul", 0)) > 0 and forge_taken())


## La fête telle qu'elle se tient aujourd'hui (transformée par la nouvelle maire).
func festival(f: Dictionary) -> Dictionary:
	if f.is_empty() or not modern_mayor() or not MODERN_FESTIVALS.has(str(f.get("id", ""))):
		return f
	return f.merged(MODERN_FESTIVALS[str(f.id)], true)


# ------------------------------------------------------------ chaque nuit
func new_day() -> void:
	var today := Marriage.day_number()
	note = ""
	if not arrived:
		if arrival_day == 0 and Story.chapter >= ARRIVAL_CHAPTER:
			arrival_day = today + ARRIVAL_DELAY
			Mail.send_custom("soul_news", {
				"from": mayor_from(),
				"text": "Grande nouvelle : le pré au sud de la place est vendu ! Trois jeunes gens de la ville y ouvrent boutique dans deux jours : un café-épicerie, un atelier d'outils modernes et un studio de design. Ils appellent ça « Les Hauts de Valfleur ». Les anciens grognent un peu, les autres sont curieux. Moi, je dis : laissons-leur une chance. À toi de voir chez qui tu fais tes achats... le village suivra ton or.",
			})
		elif arrival_day > 0 and today >= arrival_day:
			arrive()
		return
	# Les retrouvailles : une fois par an, ceux qui sont partis reviennent
	var reunion := TimeManager.season == int(REUNION[0]) and TimeManager.day == int(REUNION[1]) and not gone().is_empty()
	if reunion != visiting:
		visiting = reunion
		_apply()
	if not settled():
		_weigh(today)
	elif not ended:
		_ending()
	_neighbours(today)
	changed.emit()


func arrive() -> void:
	arrived = true
	_apply()
	Mail.send_custom("soul_arrived", {
		"from": "Capucine, du Bocal",
		"text": "Bonjour voisin·e ! Nous voilà installés aux Hauts de Valfleur, au sud de la place. Moi, c'est Capucine : je tiens le Bocal, café et épicerie bio. Hugo vend des outils qui font le travail tout seuls à l'Atelier Néo, et Élise dessine du mobilier au Studio Lin. Tout est un peu cher, on ne va pas se mentir, mais tout est très bien. Passe nous voir !",
		"items": [["oat_latte", 2]],
	})
	changed.emit()


func _level(side: String) -> float:
	return tilt if side == "modern" else -tilt


func _tier(side: String) -> int:
	return modern_tier if side == "modern" else artisan_tier


## Inquiétude, préavis, puis changement si la balance tient.
func _weigh(today: int) -> void:
	if not notice.is_empty():
		var side := str(notice.side)
		if _level(side) < float(THRESHOLDS[_tier(side)]):
			notice.clear()
			Mail.send_custom("soul_stay_%d" % today, {"from": mayor_from(), "text": _stay_text(side)})
		elif today >= int(notice.day):
			notice.clear()
			_advance(side)
		return
	for side: String in ["modern", "artisan"]:
		var need := float(THRESHOLDS[_tier(side)])
		var key := "%s:%d" % [side, _tier(side)]
		if _level(side) >= need:
			notice = {"side": side, "day": today + NOTICE_DAYS}
			Mail.send_custom("soul_notice_%s" % key, _notice_letter(side))
			return
		if _level(side) >= need - WARN_MARGIN and not warned.has(key):
			warned[key] = true
			Mail.send_custom("soul_warn_%s" % key, _warn_letter(side))


## Celui ou celle que le prochain palier fera partir.
func threatened(side: String) -> String:
	if settled():
		return ""
	if side == "modern":
		var id := str(MODERN_STEPS[modern_tier].leave[0])
		return "" if id == Marriage.spouse else id
	return str(ARTISAN_STEPS[artisan_tier])


func _warn_letter(side: String) -> Dictionary:
	var id := threatened(side)
	if side == "modern":
		return {"from": "Rosalie, l'épicière", "text": "Tu as vu les prix des maisons ? Depuis que les boutiques des Hauts de Valfleur marchent si bien, tout le monde veut s'installer ici, et les loyers grimpent. %s Si la vie continue de renchérir, certains ne pourront pas rester. Je ne te fais pas la morale : leurs produits sont bons. Je te dis juste ce que je vois de mon comptoir." % ("%s compte ses sous, en ce moment." % GameData.npc(id).name if id != "" else "Tout le monde compte ses sous.")}
	return {"from": "Capucine, du Bocal", "text": "Petite inquiétude entre voisins : les clients se font rares aux Hauts de Valfleur. %s regarde déjà les annonces en ville. Si les gens d'ici n'achètent que chez les artisans, l'un de nous finira par fermer. C'est le jeu, je ne me plains pas... mais je préfère que tu le saches." % GameData.npc(id).name}


func _notice_letter(side: String) -> Dictionary:
	var id := threatened(side)
	if side == "modern":
		if id == "":
			return {"from": mayor_from(), "text": "Les loyers ont encore monté. Dans %d jours, le village aura changé un peu plus... à moins que les artisans ne retrouvent des clients d'ici là." % NOTICE_DAYS}
		return {"from": "%s, %s" % [GameData.npc(id).name, GameData.npc(id).title], "text": "Le loyer a encore monté. Je ne peux plus suivre : j'ai donné mon préavis, je pars dans %d jours. Si d'ici là les artisans retrouvaient des clients, le propriétaire se calmerait peut-être... Sinon, sans rancune. Ce village a le droit de changer." % NOTICE_DAYS}
	return {"from": "%s, %s" % [GameData.npc(id).name, GameData.npc(id).title], "text": "Les comptes sont faits : sans clients, je ferme dans %d jours. Si la caisse se remplit d'ici là, je reste. Sinon, je repars en ville, et sans amertume : on ne s'installe pas chez les gens pour leur forcer la main." % NOTICE_DAYS}


func _stay_text(side: String) -> String:
	if side == "modern":
		return "Bonne nouvelle : les artisans ont retrouvé des clients, et le propriétaire a renoncé à sa hausse. Personne ne part... pour l'instant."
	return "Bonne nouvelle : les caisses des Hauts de Valfleur se sont remplies à temps. Personne ne ferme boutique... pour l'instant."


## Le village change pour de bon.
func _advance(side: String) -> void:
	var today := Marriage.day_number()
	if side == "modern":
		var step: Dictionary = MODERN_STEPS[modern_tier]
		var leaver := str(step.leave[0])
		if leaver == Marriage.spouse:
			stayed.append(leaver)
			Mail.send_custom("soul_spouse_%d" % modern_tier, {"from": mayor_from(), "text": "Les loyers ont encore monté, mais %s ne partira pas : sa maison, maintenant, c'est la tienne. Le reste du village, lui, continue de changer." % GameData.npc(leaver).name})
		else:
			Mail.send_custom("soul_bye_" + leaver, FAREWELLS[leaver])
			if str(step.arrive) != "":
				Mail.send_custom("soul_hello_" + str(step.arrive), ARRIVALS[str(step.arrive)])
		modern_tier += 1
		if modern_tier >= 3:
			Mail.send_custom("soul_election", {
				"from": "Capucine, maire de Valfleur",
				"text": "Les résultats sont tombés hier soir : je suis élue maire de Valfleur ! Bertrand a été très digne, il m'a remis les clés lui-même. Mon programme : faire connaître le village. Des affiches, des événements, des visiteurs ! Les fêtes vont changer de nom et de style, et les concours seront mieux dotés. Je sais que tout le monde n'est pas ravi. Je ferai de mon mieux pour que chacun y trouve sa place.",
			})
		Mail.send_custom("soul_modern_%d" % modern_tier, {"from": "Hugo, de l'Atelier Néo", "text": "Les Hauts de Valfleur grandissent, et c'est beaucoup grâce à toi. Ce qui change : %s\n\nLe revers, pour être honnête : %s" % [MODERN_PERKS[modern_tier - 1], MODERN_COSTS[modern_tier - 1]]})
	else:
		var leaver := str(ARTISAN_STEPS[artisan_tier])
		Mail.send_custom("soul_bye_" + leaver, FAREWELLS[leaver])
		artisan_tier += 1
		Mail.send_custom("soul_artisan_%d" % artisan_tier, {"from": "Gaston, le forgeron", "text": "Les ateliers tournent comme jamais, et c'est beaucoup grâce à toi. Ce qui change : %s\n\nLe revers, pour être honnête : %s" % [ARTISAN_PERKS[artisan_tier - 1], ARTISAN_COSTS[artisan_tier - 1]]})
	# Plus personne ne s'inquiète pour un palier qui n'existera pas
	_apply()
	_forget_gone()
	PlayerState.flags["soul_changes"] = changes()
	if today > 0:
		note = "Valfleur a changé cette nuit. Regarde ton courrier."


## Les demandes et la maladie d'un habitant parti n'ont plus lieu d'être.
func _forget_gone() -> void:
	var away := gone()
	Quests.active = Quests.active.filter(func(q: Dictionary) -> bool: return not str(q.npc) in away)
	if VillageLife.sick in away:
		VillageLife.sick = ""


func _ending() -> void:
	ended = true
	var kind := outcome()
	PlayerState.flags["soul_ending"] = kind
	var texts := {
		"artisan": ["Bertrand, maire de Valfleur", "Valfleur des artisans. Les Hauts de Valfleur sont devenus des ateliers d'apprentis, la forge sonne dès l'aube et les fêtes n'ont jamais été aussi grandes. Nous n'aurons ni machines ni terrasses, et certains diront que nous sommes restés en arrière. Moi je dis : nous sommes restés nous-mêmes. Firmin aurait reconnu chaque pierre. Voici l'horloge de la mairie : elle sonnera chez toi l'heure du village.", [["oak_clock", 1]]],
		"modern": ["Capucine, maire de Valfleur", "Valfleur nouvelle. Le village n'a jamais été aussi vivant, ni aussi cher. Odette, Lina et Gaston sont partis, et leur absence se voit sur chaque façade repeinte. Mais les enfants reviennent s'installer, les produits de ta ferme partent à prix d'or, et la place ne désemplit pas. Ce n'est plus le village de Firmin : c'est le tien. Cette sculpture a été dessinée pour ta ferme.", [["design_sculpture", 1]]],
		"shared": [mayor_from(), "Valfleur partagée. Le village a changé, mais pas tout entier : des anciens sont restés, des nouveaux aussi, et chacun a fini par saluer l'autre le matin. Personne n'a tout gagné, personne n'a tout perdu. On dit que c'est la fin la plus difficile à obtenir, parce qu'elle demande de ne jamais choisir tout à fait. Cette fontaine vient de la place : les deux moitiés du village se sont cotisées.", [["garden_fountain", 1]]],
	}
	var t: Array = texts[kind]
	Mail.send_custom("soul_ending", {"from": t[0], "text": t[1], "items": t[2]})


## Voie des artisans (palier 2) : les voisins donnent un coup de main.
func _neighbours(today: int) -> void:
	if artisan_tier < 2:
		return
	var helpers: Array = HELPERS.filter(func(id: String) -> bool: return GameData.npcs.has(id))
	if helpers.is_empty():
		return
	var who := str(helpers[today % helpers.size()])
	if (TimeManager.day - 1) % 7 == 6:
		var seeds: Array = Shops.items("store").filter(func(id: String) -> bool: return GameData.item(id).get("type") == "seed")
		var items: Array = [["vegetable_soup", 1]]
		if not seeds.is_empty():
			items.append([str(seeds[today % seeds.size()]), 6])
		Mail.send_custom("soul_basket_%d" % today, {"from": "%s, %s" % [GameData.npc(who).name, GameData.npc(who).title], "text": "C'est dimanche : les voisins se sont cotisés pour ton panier. Ici, on ne laisse pas une ferme travailler seule.", "items": items})
	elif random_events and randf() < 0.35 and not TimeManager.is_raining():
		var watered := 0
		for cell: Vector2i in FarmState.tiles.keys():
			if not FarmState.is_watered(cell) and str(FarmState.tiles[cell].crop) != "":
				FarmState.water(cell)
				watered += 1
		if watered > 0:
			note = "%s est passé·e arroser tes cultures avant l'aube." % GameData.npc(who).name


# ------------------------------------------------------------ ce qu'on en dit
const WORRIED := [
	"Tu as vu le prix du pain ? Depuis que le lotissement marche fort, tout augmente.",
	"Ils sont gentils, les nouveaux. Mais chaque fois qu'un des leurs s'installe, mon loyer prend dix pour cent.",
	"On ne reconnaît plus la rue. C'est propre, c'est joli... c'est plus tout à fait chez nous.",
]
const PROUD := [
	"Les ateliers n'ont jamais eu autant de travail. Merci de faire tes achats ici.",
	"Tu sais ce qui fait un village ? Des gens qui se doivent des services. Et ça, on en a à revendre.",
	"On n'aura pas leurs machines. Mais on aura toujours quelqu'un pour tenir l'échelle.",
]
const CURIOUS := [
	"Tu es allé·e voir les Hauts de Valfleur ? Leur café coûte le prix d'un sac de graines !",
	"Des gens de la ville, à Valfleur... Mon grand-père n'en reviendrait pas.",
]
const NEW_HAPPY := [
	"Les affaires marchent ! Je crois que le village commence à nous adopter.",
	"J'ai compté : douze clients ce matin. En ville, je n'en voyais pas autant en une semaine.",
]
const NEW_SAD := [
	"C'est calme, aux Hauts de Valfleur. Très calme. Trop calme.",
	"Les gens d'ici sont polis, mais ils achètent chez leurs voisins. Je les comprends, remarque.",
]


## Ce que l'habitant dit de la situation ("" : rien de spécial aujourd'hui).
func talk(id: String) -> String:
	if not arrived or Relations.talked_today.has(id):
		return ""
	var line := ""
	if not notice.is_empty() and id == threatened(str(notice.side)):
		line = "Le loyer a encore monté... J'ai donné mon préavis. Sauf miracle, je pars dans quelques jours." if str(notice.side) == "modern" else "Je fais mes cartons, doucement. Si la caisse ne se remplit pas d'ici quelques jours, je ferme."
	elif is_visitor(id):
		line = "Ça fait drôle de revoir la place. Ma maison a changé de rideaux... mais toi, tu n'as pas changé."
	elif id == "bertrand" and modern_mayor():
		line = "Ancien maire, ça sonne bien, non ? Capucine fait les choses à sa manière. Moi, j'ai enfin le temps de pêcher."
	elif id == NEW_MAYOR and modern_mayor():
		line = "Maire ! Moi ! Je veux que tout le monde y gagne, même ceux qui n'ont pas voté pour moi. Surtout eux."
	elif randf() < 0.3:
		var newcomer: bool = id in NEWCOMERS
		var pool: Array = CURIOUS
		if newcomer:
			pool = NEW_HAPPY if tilt >= 0.0 else NEW_SAD
		elif tilt >= 20.0 or modern_tier > artisan_tier:
			pool = WORRIED
		elif tilt <= -20.0 or artisan_tier > modern_tier:
			pool = PROUD
		line = str(pool[randi() % pool.size()])
	if line != "":
		Relations.talked_today[id] = true
		Relations.add_points(id, Relations.TALK_POINTS)
	return line


## Petites phrases entendues en passant.
func bubbles() -> Array:
	if not arrived:
		return []
	if modern_mayor():
		return ["Tu as vu les affiches ?", "Un latte, et ça repart !", "C'est devenu chic, ici."]
	if artisan_tier >= 2:
		return ["Vive les artisans !", "Besoin d'un coup de main ?", "Passe à l'atelier !"]
	return ["Tu vas aux Hauts de Valfleur ?", "Ça change, par ici."]


# ------------------------------------------------------------ le décor
## Nom d'un bâtiment, selon qui l'occupe.
func building_name(id: String, fallback: String) -> String:
	match id:
		"odette":
			return "Chez Sacha" if house_taken("odette") else fallback
		"lina":
			return "Galerie d'Inès" if house_taken("lina") else fallback
		"gaston":
			return "Forge & Design (atelier de Hugo)" if forge_taken() else fallback
	return fallback


## Une porte close : boutique fermée pour de bon ("" : on entre normalement).
func door_note(building: String) -> String:
	if not MODERN_SHOPS.has(building) or not is_gone(str(MODERN_SHOPS[building])):
		return ""
	if artisan_tier >= 3:
		return "Atelier des apprentis. Mathis et Gaston y forment la relève : on entend les rabots et les marteaux depuis la rue."
	return "À vendre. %s est reparti·e en ville." % GameData.npc(str(MODERN_SHOPS[building])).name


## Apparence d'un bâtiment du village : {} (inchangé) ou
## {"wall": String, "roof": Color, "sign": String}.
func house_look(id: String) -> Dictionary:
	if MODERN_SHOPS.has(id):
		if is_gone(str(MODERN_SHOPS[id])):
			if artisan_tier >= 3:
				return {"wall": "wall-wood", "roof": Color(0.55, 0.36, 0.22), "sign": "ATELIER"}
			return {"wall": "wall", "roof": Color(0.5, 0.5, 0.52), "sign": "À VENDRE"}
		return {"wall": "wall", "roof": Color(0.22, 0.26, 0.3), "sign": {"bocal": "LE BOCAL", "outils": "ATELIER NÉO", "studio": "STUDIO LIN"}[id]}
	if id in ["odette", "lina"] and house_taken(id):
		return {"wall": "wall", "roof": Color(0.22, 0.26, 0.3), "sign": ""}
	if id == "gaston" and forge_taken():
		return {"wall": "wall", "roof": Color(0.22, 0.26, 0.3), "sign": "FORGE & DESIGN"}
	if id == "mairie" and modern_mayor():
		return {"wall": "wall", "roof": Color(0.2, 0.5, 0.45), "sign": "MAIRIE 2.0"}
	return {}


## Décor ajouté au village : [[case, sorte, texte, couleur], ...].
## Sortes : "billboard" (affiche), "terrace" (terrasse du Bocal), "stall" (étal d'artisan).
func decor() -> Array:
	var out: Array = []
	if not arrived:
		return out
	if modern_mayor():
		for b: Array in BILLBOARDS:
			out.append([b[0], "billboard", b[1], b[2]])
	if modern_tier >= 2 and not is_gone("capucine"):
		for c: Vector2i in TERRACE:
			out.append([c, "terrace", "", Color.WHITE])
	if artisan_tier >= 2:
		for c: Vector2i in STALLS:
			out.append([c, "stall", "", Color.WHITE])
	return out


## Fanions permanents au-dessus de la rue des artisans.
func bunting() -> bool:
	return artisan_tier >= 1


# ------------------------------------------------------------ journal
## Position de la balance, de -1 (artisans) à 1 (nouveaux venus).
func balance() -> float:
	return tilt / TILT_MAX


func balance_text() -> String:
	if absf(tilt) < 10.0:
		return "La balance est à l'équilibre."
	var side := "les nouveaux venus" if tilt > 0.0 else "les artisans"
	return "La balance penche %s vers %s." % ["nettement" if absf(tilt) >= 30.0 else "un peu", side]


## Ce qui se prépare ("" : rien).
func notice_text() -> String:
	if notice.is_empty():
		return ""
	var left := maxi(0, int(notice.day) - Marriage.day_number())
	var id := threatened(str(notice.side))
	var who := "Le village" if id == "" else str(GameData.npc(id).name)
	return "%s a donné son préavis : départ dans %d jour%s, sauf si la balance revient." % [who, left, "s" if left > 1 else ""]


func to_dict() -> Dictionary:
	return {"arrived": arrived, "arrival_day": arrival_day, "tilt": tilt, "modern": modern_tier, "artisan": artisan_tier,
		"warned": warned.keys(), "notice": notice.duplicate(), "stayed": stayed.duplicate(), "ended": ended, "visiting": visiting}


func from_dict(data: Dictionary) -> void:
	reset()
	arrived = bool(data.get("arrived", false))
	arrival_day = int(data.get("arrival_day", 0))
	tilt = clampf(float(data.get("tilt", 0.0)), -TILT_MAX, TILT_MAX)
	modern_tier = clampi(int(data.get("modern", 0)), 0, MAX_CHANGES)
	artisan_tier = clampi(int(data.get("artisan", 0)), 0, MAX_CHANGES - modern_tier)
	for k: Variant in data.get("warned", []):
		warned[str(k)] = true
	var n: Dictionary = data.get("notice", {})
	if n.has("side") and n.has("day"):
		notice = {"side": str(n.side), "day": int(n.day)}
	for id: Variant in data.get("stayed", []):
		stayed.append(str(id))
	ended = bool(data.get("ended", false))
	visiting = bool(data.get("visiting", false))
	_apply()
