extends Node
## La vie du village, au fil des saisons :
## - un habitant tombe parfois malade et garde le lit quelques jours ; un
##   plat cuisiné apporté chez lui le remet sur pied (et touche son cœur) ;
## - Jules et Nina se marient sur la place (on leur offre un cadeau au stand) ;
## - une nouvelle venue, Pauline la meunière, s'installe au moulin rénové.

signal changed

const SICK_CANDIDATES := ["odette", "lina", "theo", "jules"]  # ceux qu'on peut visiter chez eux
const SICK_CHANCE := 0.06
const SICK_DAYS := 3
const SICK_THANKS := 150  # points d'amitié pour un plat apporté
const COUPLE := ["jules", "nina"]
const WEDDING_GIFT := 120
const NEWCOMER := "pauline"
const NEWLYWED_LINES := {
	"jules": ["Nina m'a appris à lire les étoiles depuis le phare. Moi, je lui apprends les nœuds marins. Équitable, non ?", "Marié ! Je n'en reviens toujours pas. Merci d'être venu·e."],
	"nina": ["Jules rentre de la pêche, je lui fais signe avec la lanterne du phare. C'est notre code.", "Le phare n'a jamais été aussi chaleureux. Merci pour le cadeau, il est sur la cheminée."],
}

var sick: String = ""  # habitant malade ("" : personne)
var sick_days: int = 0
var visited: bool = false  # un plat lui a déjà été apporté
var wedding_day: int = 0  # numéro du jour du mariage (0 : pas encore prévu)
var wedded: bool = false
var arrival_day: int = 0  # jour d'arrivée de la meunière (0 : pas encore annoncée)
var arrived: bool = false
## Pas de hasard pendant les tests automatiques
var random_events: bool = DisplayServer.get_name() != "headless"


func reset() -> void:
	sick = ""
	sick_days = 0
	visited = false
	wedding_day = 0
	wedded = false
	arrival_day = 0
	arrived = false
	GameData.unwelcome(NEWCOMER)


static func date_of(n: int) -> Array:
	return [((n - 1) % 112) / 28, (n - 1) % 28 + 1]


static func date_text(n: int) -> String:
	var d := date_of(n)
	return "%d %s" % [d[1], ["de printemps", "d'été", "d'automne", "d'hiver"][d[0]]]


func new_day() -> void:
	var today := Marriage.day_number()
	# ---- Maladie
	if sick != "":
		sick_days -= 1
		if sick_days <= 0:
			sick = ""
	elif random_events and TimeManager.day >= 3 and randf() < SICK_CHANCE:
		fall_sick(_pick_sick())
	# ---- Mariage de Jules et Nina (une semaine après l'annonce)
	if wedding_day == 0 and Story.chapter >= 2:
		var d := today + 7
		while _festival_on(d):
			d += 1
		wedding_day = d
		Mail.send_custom("wedding_invite", {
			"from": "Jules et Nina",
			"text": "Bonne nouvelle : on se marie ! La cérémonie aura lieu sur la place de Valfleur le %s, de 10h à 15h. Tout le village sera là, et nous serions si heureux que tu y sois aussi. Le stand de la place recevra les cadeaux (n'importe quoi de ta ferme nous fera plaisir !)." % date_text(d),
		})
	if not wedded and wedding_day > 0 and today > wedding_day:
		wedded = true
	# ---- La nouvelle meunière
	if not arrived and arrival_day == 0 and Projects.state("mill") == "done":
		arrival_day = today + 2
		Mail.send_custom("newcomer_news", {
			"from": Soul.mayor_from(),
			"text": "Le moulin tourne à peine qu'une lettre m'arrive de la ville : une jeune meunière, Pauline, demande à s'y installer ! Elle arrivera dans deux jours. Une nouvelle habitante à Valfleur, ça ne s'était pas vu depuis des années.",
		})
	if not arrived and arrival_day > 0 and today >= arrival_day:
		arrive()
	changed.emit()


func _pick_sick() -> String:
	var pool: Array = SICK_CANDIDATES.filter(func(id: String) -> bool:
		return GameData.npcs.has(id) and id != Marriage.spouse and HeartEvents.birthday_today() != id and wedding_today().is_empty())
	return "" if pool.is_empty() else str(pool[randi() % pool.size()])


func fall_sick(id: String) -> void:
	if id == "":
		return
	sick = id
	sick_days = SICK_DAYS
	visited = false
	var from := "Odette, la jardinière" if id not in ["odette", "theo"] else "Lina, la peintre"
	Mail.send_custom("sick_%s_%d" % [id, Marriage.day_number()], {
		"from": from,
		"text": "%s a attrapé un mauvais rhume et garde le lit. Un bon plat chaud lui ferait tant de bien ! Sa porte est ouverte de 8h à 20h : apporte-lui un plat cuisiné, en main." % GameData.npc(id).name,
	})
	changed.emit()


func arrive() -> void:
	arrived = true
	GameData.welcome(NEWCOMER)
	Mail.send_custom("newcomer_arrived", {
		"from": "Pauline, la meunière",
		"text": "Bonjour ! Je suis Pauline, la nouvelle meunière. Me voici installée au moulin : les ailes tournent, la farine vole... Passe me voir, je ne connais encore personne ici !",
	})
	changed.emit()


func _festival_on(n: int) -> bool:
	var d := date_of(n)
	for f: Dictionary in Events.festivals:
		if int(f.season) == d[0] and int(f.day) == d[1]:
			return true
	return false


## Le mariage, comme une fête du village ({} si ce n'est pas aujourd'hui).
func wedding_today() -> Dictionary:
	if wedding_day == 0 or wedding_day != Marriage.day_number():
		return {}
	return {
		"id": "wedding", "name": "Mariage de Jules et Nina", "season": TimeManager.season, "day": TimeManager.day,
		"start": 10, "end": 15, "activity": "wedding", "bubble": "Vive les mariés !",
		"desc": "Jules et Nina se marient sur la place ! Prends en main ce que tu veux leur offrir, puis touche le stand.",
	}


## Cadeau de mariage : n'importe quel objet de valeur.
func give_wedding_gift(item_id: String) -> bool:
	if wedding_today().is_empty() or Events.is_done("wedding") or int(GameData.item(item_id).get("sell", 0)) <= 0:
		return false
	if Inventory.count_of(item_id) <= 0:
		return false
	Inventory.remove_item(item_id, 1)
	var value := int(GameData.item(item_id).get("sell", 0))
	for id: String in COUPLE:
		Relations.add_points(id, WEDDING_GIFT + mini(value, 300) / 3)
	for id: String in GameData.npcs:
		Relations.add_points(id, 10)
	Events.mark_done("wedding")
	return true


## Ce que dit l'habitant à cause de la vie du village ("" : rien de spécial).
func talk(id: String) -> String:
	if id == sick:
		var slot: Variant = Inventory.get_selected()
		if not visited and slot != null and GameData.item(slot.id).get("type") == "food":
			var dish := GameData.item_name(str(slot.id)).to_lower()
			Inventory.remove_from_slot(Inventory.selected, 1)
			visited = true
			sick_days = mini(sick_days, 1)  # guéri dès demain
			Relations.add_points(id, SICK_THANKS)
			Relations.talked_today[id] = true
			Sfx.play("levelup")
			changed.emit()
			return "Atchoum... Oh ! Un plat de %s, rien que pour moi ? Tu es un ange. Ça me réchauffe jusqu'au bout des orteils. Je serai sur pied demain, c'est promis !" % dish
		if visited:
			return "Merci encore pour le plat... Je me sens déjà beaucoup mieux."
		return "Atchoum ! Pardon... Je garde le lit, j'ai attrapé froid. Un bon plat chaud me ferait du bien, mais je n'ai même pas la force de cuisiner..."
	if wedded and id in COUPLE and not Relations.talked_today.has(id) and randf() < 0.5:
		Relations.talked_today[id] = true
		Relations.add_points(id, Relations.TALK_POINTS)
		var lines: Array = NEWLYWED_LINES[id]
		return str(lines[randi() % lines.size()])
	return ""


func to_dict() -> Dictionary:
	return {"sick": sick, "sick_days": sick_days, "visited": visited, "wedding_day": wedding_day,
		"wedded": wedded, "arrival_day": arrival_day, "arrived": arrived}


func from_dict(data: Dictionary) -> void:
	reset()
	sick = str(data.get("sick", ""))
	sick_days = int(data.get("sick_days", 0))
	visited = bool(data.get("visited", false))
	wedding_day = int(data.get("wedding_day", 0))
	wedded = bool(data.get("wedded", false))
	arrival_day = int(data.get("arrival_day", 0))
	if bool(data.get("arrived", false)):
		arrived = true
		GameData.welcome(NEWCOMER)
