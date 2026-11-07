class_name SeaMap
extends WorldMap
## Au large du port du Héron : la barque de Basile, louée pour la journée.
## On y pêche les poissons des grands fonds (thon, espadon... et le Grand
## requin bleu). La barre (E) ramène au port ; à 20h, Basile rentre.
##
## Plan : ~ mer, # pont de la barque (la barre est à la poupe, en HELM).

const MAP := [
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~#########~~~~~~~~~~",
	"~~~~~~~~~~~#########~~~~~~~~~~",
	"~~~~~~~~~~~#########~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
]
const PORT_RETURN := Vector2i(35, 15)  # au bout de la jetée
const RETURN_HOUR := 20
const HELM := Vector2i(11, 10)  # la barre, à la poupe


func _init() -> void:
	map_id = "sea"


func _map_rows() -> Array:
	return MAP


func display_name() -> String:
	return "Au large"


func _after_build() -> void:
	_spawn_cell = Vector2i(15, 10)
	_interactables[HELM] = "exit"
	_place_player()
	if not is_walkable(player_cell()):
		player.position = cell_center(_spawn_cell)  # toujours sur le pont
	TimeManager.time_changed.connect(func(h: int, _m: int) -> void:
		if h >= RETURN_HOUR and not _warping:
			EventBus.toast("Le soleil baisse : Basile ramène la barque au port.")
			_warping = true
			EventBus.map_change_requested.emit("port", PORT_RETURN))


func _interact(kind: String, _cell: Vector2i) -> void:
	if kind == "exit":
		EventBus.toast("Retour au port du Héron.")
		EventBus.map_change_requested.emit("port", PORT_RETURN)
