class_name Minimap
extends Control
## Mini-carte du lieu actuel : plan simplifié, joueur (rouge), habitants
## (jaune), animaux (blanc). Un toucher l'agrandit (avec les quartiers),
## un second la referme. Elle suit le terrain en temps réel : sillons,
## cultures, objets posés, bâtiments, chantiers, arbres coupés ou replantés
## (chaque carte peint ses changements : WorldMap.minimap_color).

const SMALL_MAX := Vector2(92, 60)
const COLORS := {
	"T": Color(0.2, 0.42, 0.26), "R": Color(0.2, 0.42, 0.26), "b": Color(0.3, 0.55, 0.3),
	"=": Color(0.86, 0.7, 0.48), "c": Color(0.7, 0.7, 0.7), "~": Color(0.35, 0.62, 0.9),
	"#": Color(0.2, 0.17, 0.2), "_": Color(0.6, 0.5, 0.38), "r": Color(0.7, 0.4, 0.35),
	"o": Color(0.55, 0.55, 0.58), "F": Color(0.6, 0.45, 0.3),
	"v": Color(0.9, 0.5, 0.65), "q": Color(0.6, 0.45, 0.3), "g": Color(0.2, 0.45, 0.25),
	"u": Color(0.6, 0.45, 0.3), "y": Color(0.92, 0.8, 0.42), "w": Color(0.6, 0.6, 0.62), "n": Color(0.3, 0.3, 0.32),
	"s": Color(0.8, 0.35, 0.3), ":": Color(0.93, 0.85, 0.62), "W": Color(0.75, 0.3, 0.25),
}
const GRASS := Color(0.45, 0.7, 0.36)
const BUILDING := Color(0.72, 0.36, 0.3)

var world: WorldMap
var big: bool = false
var _texture: ImageTexture
var _image: Image
var _map_size: Vector2i
const REFRESH := 0.35  # secondes entre deux mises à jour du plan
var _refresh_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			big = not big
			Sfx.play("open" if big else "close")
			_layout()
			accept_event())


func setup(map: WorldMap) -> void:
	world = map
	_map_size = map.get("_map_size")
	_image = Image.create(_map_size.x, _map_size.y, false, Image.FORMAT_RGBA8)
	_paint()
	_texture = ImageTexture.create_from_image(_image)
	big = false
	_layout()


## Plan de la carte : le sol, puis ce qui change (cultures, objets, chantiers...).
func _paint() -> void:
	var map := world
	var img := _image
	var chars: Dictionary = map.get("_ground_chars")
	var blocked: Dictionary = map.get("_blocked")
	for cell: Vector2i in chars:
		var ch: String = chars[cell]
		var color: Color = COLORS.get(ch, GRASS)
		if blocked.has(cell) and not COLORS.has(ch):
			color = BUILDING
		if map is MineLevel and ch != "#":
			color = Color(0.55, 0.48, 0.4)
		if (map is PortMap or map is SeaMap) and ch == "#":
			color = Color(0.62, 0.44, 0.27)  # pontons et pont de la barque
		var live: Color = map.minimap_color(cell)
		if live.a > 0.0:
			color = live
		img.set_pixel(cell.x, cell.y, color)


func _layout() -> void:
	if _map_size == Vector2i.ZERO:
		return
	var vp := get_viewport().get_visible_rect().size
	var limit := Vector2(vp.x - 40, vp.y - 50) if big else SMALL_MAX
	var cell := minf(limit.x / _map_size.x, limit.y / _map_size.y)
	size = Vector2(_map_size) * cell + Vector2(4, 4)
	position = (vp - size) / 2.0 if big else Vector2(4, 30)
	z_index = 20 if big else 0
	queue_redraw()


func cell_size() -> float:
	return (size.x - 4) / float(_map_size.x)


var _redraw_timer: float = 0.0


func _process(delta: float) -> void:
	# Redessinée 6 fois par seconde : bien assez pour une mini-carte
	_redraw_timer -= delta
	if _redraw_timer <= 0.0 and world != null and is_instance_valid(world):
		_redraw_timer = 0.16
		queue_redraw()
	# Le terrain a pu changer (on plante, on bâtit, on coupe...)
	_refresh_timer -= delta
	if _refresh_timer <= 0.0 and _image != null and world != null and is_instance_valid(world):
		_refresh_timer = REFRESH
		refresh()


## Remet le plan à jour tout de suite.
func refresh() -> void:
	if _image == null or world == null or not is_instance_valid(world):
		return
	_paint()
	_texture.update(_image)


func _draw() -> void:
	if _texture == null or world == null or not is_instance_valid(world):
		return
	var c := cell_size()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.11, 0.07, 0.9))
	draw_texture_rect(_texture, Rect2(Vector2(2, 2), size - Vector2(4, 4)), false, Color(1, 1, 1, 0.95))
	var to_map := func(p: Vector2) -> Vector2:
		return Vector2(2, 2) + p / WorldMap.TILE * c
	# Traits (clôtures posées sur les bords des cases)
	for seg: Array in world.minimap_lines():
		draw_line(Vector2(2, 2) + (seg[0] as Vector2) * c, Vector2(2, 2) + (seg[1] as Vector2) * c, Color(0.5, 0.33, 0.18), maxf(1.0, c * 0.35))
	# Habitants et animaux
	var entities: Node = world.get("_entities")
	for child in entities.get_children():
		if child is Npc and child.visible:
			draw_circle(to_map.call(child.position), maxf(1.5, c * 0.6), Color(1, 0.86, 0.3))
		elif child is Critter:
			draw_circle(to_map.call(child.position), maxf(1.0, c * 0.4), Color(1, 1, 1, 0.9))
	# Joueur
	var pp: Vector2 = to_map.call(world.player.position)
	draw_circle(pp, maxf(2.2, c * 0.9), Color(0.1, 0.05, 0.05))
	draw_circle(pp, maxf(1.6, c * 0.7), Color(1, 0.3, 0.25))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.43, 0.22), false, 1.5)
	# En grand : noms des quartiers
	if big and world is Village:
		var font := UiTheme.font()
		for z: Array in Village.ZONES:
			var rect: Rect2i = z[1]
			var center: Vector2 = to_map.call(Vector2(rect.get_center()) * WorldMap.TILE)
			var text := str(z[0])
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			draw_string(font, center - Vector2(w / 2.0 - 1, -1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.7))
			draw_string(font, center - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.97, 0.86))
