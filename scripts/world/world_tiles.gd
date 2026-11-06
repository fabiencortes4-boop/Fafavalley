class_name WorldTiles
extends RefCounted
## Index des tuiles de assets/sprites/world.png (générée par
## tools/build_assets.py à partir des packs Kenney). Garder synchronisé.

const COLUMNS := 16
const GRASS := 0
const GRASS_TUFT := 1
const GRASS_FLOWERS := 2
## 9 tuiles de bord (haut-gauche ... bas-droite) puis 4 coins intérieurs.
const PATH_START := 3
const PATH_INNER := 12
const WATER_START := 16
const WATER_INNER := 25
const PINE := 29
const PINE_2 := 30
const ROUND_TREE := 31
const BUSH := 32
const ROCK := 33
const SUNFLOWER := 34
const MUSHROOMS := 35
const BIG_PINE := 36
## Terre labourée : paires (sèche, arrosée).
const SOIL_SINGLE := 37
const SOIL_V_TOP := 39
const SOIL_V_MID := 41
const SOIL_V_BOTTOM := 43
const SOIL_H_LEFT := 45
const SOIL_H_MID := 47
const SOIL_H_RIGHT := 49
const HAY := 51
const BARREL := 52
const BUCKET := 53
const STUMP := 54
const COUNT := 55

const SOLID := [
	16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28,
	PINE, PINE_2, ROUND_TREE, BUSH, ROCK, SUNFLOWER, BIG_PINE, HAY, BARREL, STUMP,
]


static func coords(index: int) -> Vector2i:
	return Vector2i(index % COLUMNS, index / COLUMNS)


## Choisit la tuile de bord d'un groupe (chemin, eau) selon ses voisins.
## same(dx, dy) indique si la case voisine appartient au même groupe.
static func autotile(start: int, inner: int, same: Callable) -> int:
	var n: bool = same.call(0, -1)
	var s: bool = same.call(0, 1)
	var w: bool = same.call(-1, 0)
	var e: bool = same.call(1, 0)
	if not n:
		return start + (0 if not w else (2 if not e else 1))
	if not s:
		return start + (6 if not w else (8 if not e else 7))
	if not w:
		return start + 3
	if not e:
		return start + 5
	if not same.call(-1, -1):
		return inner
	if not same.call(1, -1):
		return inner + 1
	if not same.call(1, 1):
		return inner + 2
	if not same.call(-1, 1):
		return inner + 3
	return start + 4
