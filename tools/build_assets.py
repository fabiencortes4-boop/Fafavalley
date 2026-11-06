#!/usr/bin/env python3
"""Assemble les planches de sprites du jeu à partir des packs Kenney (CC0).

Sources (dans assets/kenney/) :
  - Tiny Farm, Tiny Town, UI Pack Pixel Adventure : https://kenney.nl (CC0)
Sorties : assets/sprites/*.png

    python3 tools/build_assets.py

Les index des tuiles ci-dessous correspondent à la numérotation Kenney
(tile_0000.png = 0, de gauche à droite puis de haut en bas, 12 colonnes).
Les index de world.png sont repris dans scripts/world/world_tiles.gd :
garder les deux fichiers synchronisés.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KENNEY = os.path.join(ROOT, "assets", "kenney")
OUT = os.path.join(ROOT, "assets", "sprites")
T = 16


def load(pack, cols):
    img = Image.open(os.path.join(KENNEY, pack, "tilemap_packed.png")).convert("RGBA")
    return img, cols


FARM = load("tiny-farm", 12)
TOWN = load("tiny-town", 12)
UI = load("ui-pixel-adventure", 23)
DUNGEON = load("tiny-dungeon", 12)


def tile(sheet, i):
    img, cols = sheet
    x, y = (i % cols) * T, (i // cols) * T
    return img.crop((x, y, x + T, y + T))


def compose(sheet, rows):
    """Assemble plusieurs tuiles (None = transparent) en une image."""
    out = Image.new("RGBA", (T * len(rows[0]), T * len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, i in enumerate(row):
            if i is not None:
                out.alpha_composite(tile(sheet, i), (x * T, y * T))
    return out


def on_grass(img):
    base = tile(TOWN, 0).copy()
    base.alpha_composite(img)
    return base


# Recoloration chemin -> eau (on réutilise les bords herbeux du chemin).
WATER_MAP = {
    (234, 165, 108): (92, 168, 214),
    (207, 130, 84): (64, 132, 196),
    (254, 201, 156): (176, 224, 246),
}


def to_water(img):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if (r, g, b) in WATER_MAP:
                px[x, y] = WATER_MAP[(r, g, b)] + (a,)
    return out


# --------------------------------------------------------------- world.png
PATH_9 = [12, 13, 14, 24, 25, 26, 36, 37, 38]  # HG, H, HD, G, C, D, BG, B, BD
PATH_INNER = [39, 40, 41, 42]  # coin d'herbe NO, NE, SE, SO


def world():
    tiles = []
    tiles += [tile(TOWN, i) for i in (0, 1, 2)]  # 0-2 herbe, touffe, fleurs
    tiles += [tile(TOWN, i) for i in PATH_9]  # 3-11 chemin
    tiles += [tile(TOWN, i) for i in PATH_INNER]  # 12-15 coins intérieurs
    tiles += [to_water(tile(TOWN, i)) for i in PATH_9]  # 16-24 eau
    tiles += [to_water(tile(TOWN, i)) for i in PATH_INNER]  # 25-28
    # 29-36 décor sur herbe : sapin, sapin 2, arbre rond, buisson, rocher,
    # tournesol, champignons, grand sapin
    tiles += [on_grass(tile(FARM, 27)), on_grass(tile(TOWN, 28)), on_grass(tile(TOWN, 16))]
    tiles += [on_grass(tile(FARM, i)) for i in (39, 89, 83)]
    tiles += [on_grass(tile(TOWN, 29)), on_grass(tile(FARM, 15))]
    # 37-50 terre labourée (sèche, arrosée) : seule, haut, milieu, bas
    # (verticale), gauche, milieu, droite (horizontale)
    for dry, wet in [(0, 1), (12, 13), (24, 25), (36, 37), (60, 48), (61, 49), (63, 51)]:
        tiles += [tile(FARM, dry), tile(FARM, wet)]
    # 51-54 décor : botte de foin, tonneau, seau, souche
    tiles += [on_grass(tile(FARM, i)) for i in (96, 85, 72, 38)]
    # 55-59 village : clôture (gauche, milieu, droite), panneau, pavés
    tiles += [on_grass(tile(TOWN, i)) for i in (80, 81, 82, 83, 43)]
    # 60-70 mine : vide (x3), mur (x2), sol (x3), gravats, échelle montante, trou
    floor = tile(DUNGEON, 48)
    tiles += [tile(DUNGEON, i) for i in (0, 12, 24, 40, 28, 48, 49, 50, 42)]
    up = floor.copy()
    up.alpha_composite(tile(DUNGEON, 68))
    tiles += [up, ladder_hole(floor)]
    # 71-77 rochers (sur fond transparent, calque au-dessus du sol) :
    # gros, petit, charbon, cuivre, fer, or, gemmes
    rock = tile(FARM, 89)
    tiles += [rock, tile(FARM, 77)]
    for colors in ORE_SPECKS:
        tiles.append(ore_rock(rock, colors))
    # 78-80 : arroseur, arroseur de qualité, enclume de Gaston
    tiles += [draw_sprinkler((226, 120, 64), (170, 80, 44)), draw_sprinkler((192, 203, 220), (253, 190, 83))]
    tiles.append(on_grass(tile(DUNGEON, 74)))
    cols = 16
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGBA", (cols * T, rows * T), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        out.alpha_composite(t, ((i % cols) * T, (i // cols) * T))
    out.save(os.path.join(OUT, "world.png"))
    print("world.png :", len(tiles), "tuiles")


# --------------------------------------------------------------- cultures
# Lignes Kenney Tiny Farm : carotte, navet, maïs, tomate, chou, blé.
# Colonnes : 4 pousse, 5 jeune plant, 6 mûr, 8 légume, 9 sachet de graines.
CROP_ROWS = [0, 1, 2, 3, 4, 5]
SEEDED = 7  # petite butte de terre semée


def crops():
    rows = [[SEEDED, r * 12 + 4, r * 12 + 5, r * 12 + 6] for r in CROP_ROWS]
    compose(FARM, rows).save(os.path.join(OUT, "crops.png"))


def icons():
    out = Image.new("RGBA", (T * 14, T), (0, 0, 0, 0))
    out.alpha_composite(tile(TOWN, 129), (0, 0))  # 0 houe
    out.alpha_composite(tile(FARM, 84), (T, 0))  # 1 arrosoir
    for k, r in enumerate(CROP_ROWS):
        out.alpha_composite(tile(FARM, r * 12 + 9), ((2 + k) * T, 0))  # 2-7 graines
        out.alpha_composite(tile(FARM, r * 12 + 8), ((8 + k) * T, 0))  # 8-13 récoltes
    out.save(os.path.join(OUT, "icons.png"))


# --------------------------------------------------------------- objets
def objects():
    tile(FARM, 109).save(os.path.join(OUT, "player.png"))
    compose(TOWN, [[52, 53, 54], [64, 65, 66], [84, 86, 75]]).save(os.path.join(OUT, "house.png"))
    compose(FARM, [[93, 94, 95], [105, 106, 107], [117, 118, 119], [129, 130, 131],
                   [90, 91, 92], [126, 127, 128]]).save(os.path.join(OUT, "barn.png"))
    tile(FARM, 76).save(os.path.join(OUT, "shipping_bin.png"))
    compose_mixed([(TOWN, 83), (FARM, 11), (FARM, 47)]).save(os.path.join(OUT, "shop_stand.png"))
    compose(FARM, [[122, 121, 120]]).save(os.path.join(OUT, "animals.png"))  # poule, vache, mouton


def village():
    """Bâtiments du village (Tiny Town) et habitants (Tiny Dungeon)."""
    builds = {
        # porte : colonne 2 de la rangée du bas
        "store.png": [[48, 49, 49, 50], [60, 61, 61, 62], [88, 77, 89, 79]],
        # portes : colonne 1 de la rangée du bas
        "house_gray.png": [[48, 49, 50], [60, 61, 62], [88, 89, 79]],
        "house_gable.png": [[None, 63, None], [52, 53, 54], [64, 65, 66], [72, 85, 84]],
        "house_gable_gray.png": [[None, 55, None], [48, 49, 50], [60, 61, 62], [76, 90, 88]],
        "well.png": [[92], [104]],
    }
    for name, rows in builds.items():
        compose(TOWN, rows).save(os.path.join(OUT, name))
    compose(DUNGEON, [[40, 40, 40], [40, 9, 40]]).save(os.path.join(OUT, "mine_entrance.png"))
    # Monstres, dans l'ordre des "sprite" de data/monsters.json
    compose(DUNGEON, [[108, 120, 122, 123, 124, 110, 121]]).save(os.path.join(OUT, "monsters.png"))
    # Habitants, dans l'ordre des "sprite" de data/npcs.json
    compose(DUNGEON, [[99, 86, 100, 85, 111]]).save(os.path.join(OUT, "npcs.png"))


# Minerais visibles sur les rochers : (couleur claire, couleur sombre)
ORE_SPECKS = [
    ((60, 52, 60), (24, 20, 26)),      # charbon
    ((242, 132, 74), (189, 88, 46)),   # cuivre
    ((235, 239, 248), (80, 100, 140)),  # fer (acier)
    ((253, 214, 83), (227, 160, 40)),  # or
    ((150, 240, 250), (150, 90, 200)),  # gemmes
]


def ore_rock(rock, colors):
    """Rocher avec de gros éclats de minerai bien visibles (2x2 ou 3x2)."""
    out = rock.copy()
    px = out.load()
    light, dark = colors
    outline = (63, 38, 49)

    def inside(x, y):
        return 0 <= x < 16 and 0 <= y < 16 and px[x, y][3] > 0 and px[x, y][:3] != outline

    # Teinte générale du rocher vers la couleur du minerai
    for yy in range(16):
        for xx in range(16):
            if inside(xx, yy):
                r, g, b, al = px[xx, yy]
                k = 0.38
                px[xx, yy] = (int(r * (1 - k) + dark[0] * k), int(g * (1 - k) + dark[1] * k), int(b * (1 - k) + dark[2] * k), al)
    for (x, y, w) in ((4, 5, 3), (9, 4, 2), (6, 9, 2), (10, 9, 3), (3, 9, 2), (8, 7, 2)):
        cells = [(x + dx, y + dy) for dx in range(w) for dy in range(2)]
        if not all(inside(cx, cy) for cx, cy in cells):
            continue
        for cx, cy in cells:
            px[cx, cy] = (light if cy == y else dark) + (255,)
        px[x, y] = (255, 255, 255, 255) if light != (60, 52, 60) else (110, 104, 114, 255)
    return out


def ladder_hole(floor):
    out = floor.copy()
    px = out.load()
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) / 6.5) ** 2 + ((y - 8) / 5.5) ** 2
            if d <= 1.0:
                px[x, y] = (40, 24, 30, 255) if d < 0.75 else (63, 38, 49, 255)
    for y in (5, 8, 11):
        for x in range(5, 11):
            px[x, y] = (189, 108, 74, 255)
    for y in range(3, 13):
        px[4, y] = (150, 84, 58, 255)
        px[11, y] = (150, 84, 58, 255)
    return out


def compose_mixed(items):
    out = Image.new("RGBA", (T * len(items), T), (0, 0, 0, 0))
    for x, (sheet, i) in enumerate(items):
        out.alpha_composite(tile(sheet, i), (x * T, 0))
    return out


# --------------------------------------------------------------- interface
def ui():
    tile(UI, 34).save(os.path.join(OUT, "ui_panel.png"))
    tile(UI, 11).save(os.path.join(OUT, "ui_slot.png"))
    tile(UI, 33).save(os.path.join(OUT, "ui_slot_selected.png"))
    tile(UI, 49).save(os.path.join(OUT, "ui_button.png"))
    tile(UI, 26).save(os.path.join(OUT, "ui_button_disabled.png"))
    tile(UI, 79).save(os.path.join(OUT, "ui_round.png"))
    tile(UI, 80).save(os.path.join(OUT, "ui_round_dark.png"))
    compose(UI, [[86, 87], [109, 110]]).save(os.path.join(OUT, "ui_ring.png"))


# --------------------------------------------------------------- pêche
# Kenney n'a pas de poissons « Tiny » : on les dessine au pixel avec la
# palette et le contour des packs Kenney (CC0).
OUTLINE = (63, 38, 49, 255)

# id : (longueur rx, hauteur ry, corps, ventre, nageoires, motif)
FISH = [
    ("roach", 5, 3, (192, 203, 220), (235, 239, 248), (195, 75, 53), None),
    ("carp", 5, 4, (189, 140, 74), (253, 214, 160), (184, 101, 66), "scales"),
    ("perch", 5, 3, (160, 190, 90), (230, 225, 150), (227, 134, 40), "stripes"),
    ("pike", 6, 2, (110, 140, 80), (198, 229, 141), (78, 120, 66), "spots"),
    ("eel", 7, 1, (118, 86, 64), (189, 150, 110), (90, 64, 50), None),
    ("trout", 5, 3, (170, 186, 200), (235, 239, 248), (139, 155, 180), "rainbow"),
    ("catfish", 5, 3, (100, 108, 120), (160, 168, 176), (82, 96, 124), "whiskers"),
    ("golden_carp", 5, 4, (253, 190, 83), (255, 230, 150), (227, 134, 40), "shine"),
]


def draw_fish(rx, ry, body, belly, fin, pattern):
    img = new_img(16, 16)
    px = img.load()
    cx, cy = 9, 8
    mask = set()
    for y in range(16):
        for x in range(16):
            if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1.0:
                mask.add((x, y))
    # queue en triangle à gauche
    tail_x = cx - rx - 1
    fins = set()
    for i in range(3):
        for dy in range(-i - 1, i + 2):
            fins.add((tail_x - i, cy + dy))
    # nageoire dorsale
    for x in range(cx - 1, cx + 2):
        fins.add((x, cy - ry - 1))
    for (x, y) in fins:
        if 0 <= x < 16 and 0 <= y < 16 and (x, y) not in mask:
            px[x, y] = fin + (255,)
    for (x, y) in mask:
        px[x, y] = (belly if y > cy else body) + (255,)
        if pattern == "stripes" and x in (cx - 2, cx + 1) and y <= cy + 1:
            px[x, y] = (78, 100, 50, 255)
        if pattern == "spots" and (x + y) % 3 == 0 and y < cy:
            px[x, y] = belly + (255,)
        if pattern == "rainbow" and y == cy:
            px[x, y] = (242, 132, 150, 255)
        if pattern == "scales" and (x + y) % 2 == 0 and y < cy:
            px[x, y] = (170, 120, 60, 255)
    if pattern == "shine":
        px[cx - 1, cy - 2] = (255, 255, 255, 255)
        px[cx, cy - 2] = (255, 250, 220, 255)
    if pattern == "whiskers":
        for k in range(3):
            px[min(15, cx + rx + 1 + k // 2), cy + 1 + k // 2] = OUTLINE
    # contour
    solid = {(x, y) for y in range(16) for x in range(16) if px[x, y][3] > 0 and px[x, y] != OUTLINE}
    for (x, y) in list(solid):
        for (nx, ny) in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < 16 and 0 <= ny < 16 and (nx, ny) not in solid and px[nx, ny][3] == 0:
                px[nx, ny] = OUTLINE
    # oeil
    px[cx + rx - 1, cy - 1] = OUTLINE
    return img


def draw_rod():
    img = new_img(16, 16)
    px = img.load()
    for i in range(11):
        x, y = 2 + i, 14 - i
        px[x, y] = (189, 108, 74, 255)
        px[x + 1, y] = OUTLINE if i < 10 else (189, 108, 74, 255)
        px[x - 1, y] = OUTLINE
    for y in range(4, 11):
        px[13, y] = (235, 239, 248, 255)
    for (x, y) in ((12, 11), (13, 11), (14, 11), (12, 12), (14, 12), (13, 13)):
        px[x, y] = OUTLINE
    px[13, 12] = (195, 75, 53, 255)
    px[3, 12], px[4, 12] = (63, 38, 49, 255), (118, 59, 54, 255)
    return img


def fishing():
    sheet = Image.open(os.path.join(OUT, "icons.png"))
    out = new_img(T * (15 + len(FISH)), T)
    out.alpha_composite(sheet, (0, 0))
    out.alpha_composite(draw_rod(), (14 * T, 0))  # 14 canne à pêche
    for k, (_id, rx, ry, body, belly, fin, pattern) in enumerate(FISH):
        out.alpha_composite(draw_fish(rx, ry, body, belly, fin, pattern), ((15 + k) * T, 0))
    out = extend_icons(out)
    out.save(os.path.join(OUT, "icons.png"))
    # bouchon (8x8)
    bob = new_img(8, 8)
    px = bob.load()
    for y in range(1, 7):
        for x in range(1, 7):
            if (x - 3.5) ** 2 + (y - 3.5) ** 2 <= 7:
                px[x, y] = ((195, 75, 53, 255) if y < 4 else (235, 239, 248, 255))
    for y in range(8):
        for x in range(8):
            if px[x, y][3] == 0 and any(
                0 <= x + dx < 8 and 0 <= y + dy < 8 and px[x + dx, y + dy][3] > 0 and px[x + dx, y + dy] != OUTLINE
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            ):
                px[x, y] = OUTLINE
    bob.save(os.path.join(OUT, "bobber.png"))
    tile(UI, 77).save(os.path.join(OUT, "ui_alert.png"))


# Minerais et butins dessinés au pixel : (forme, clair, moyen, sombre)
LOOT = [
    ("chunk", (180, 180, 188), (140, 140, 148), (104, 104, 114)),   # 27 pierre
    ("chunk", (90, 84, 92), (60, 52, 60), (36, 30, 38)),            # 28 charbon
    ("chunk", (250, 160, 100), (226, 120, 64), (170, 80, 44)),      # 29 cuivre
    ("chunk", (235, 239, 248), (192, 203, 220), (139, 155, 180)),   # 30 fer
    ("chunk", (255, 230, 120), (253, 190, 83), (210, 140, 40)),     # 31 or
    ("gem", (245, 245, 255), (210, 220, 240), (160, 170, 200)),     # 32 quartz
    ("gem", (220, 160, 255), (170, 100, 220), (110, 60, 160)),      # 33 améthyste
    ("gem", (150, 245, 170), (60, 200, 110), (30, 130, 70)),        # 34 émeraude
    ("blob", (150, 240, 170), (80, 200, 120), (40, 140, 80)),       # 35 gelée
    ("wing", (170, 120, 110), (130, 84, 80), (90, 56, 56)),         # 36 aile
    ("ball", (255, 255, 255), (230, 232, 240), (180, 184, 200)),    # 37 soie
    ("fang", (255, 252, 240), (235, 230, 210), (190, 180, 160)),    # 38 croc
    ("shell", (250, 110, 90), (210, 70, 60), (150, 40, 40)),        # 39 carapace
    ("blob", (220, 240, 255), (170, 200, 240), (120, 140, 200)),    # 40 ectoplasme
]


def loot_mask(shape):
    m = set()
    for y in range(16):
        for x in range(16):
            if shape == "chunk":
                ok = abs(x - 7.5) + abs(y - 8.5) * 1.3 <= 7 and y >= 4
            elif shape == "gem":
                ok = abs(x - 7.5) * 1.2 + abs(y - 8) <= 6.5
            elif shape == "blob":
                ok = ((x - 7.5) / 6) ** 2 + ((y - 9.5) / 4.5) ** 2 <= 1 or ((x - 7.5) / 3) ** 2 + ((y - 5) / 3) ** 2 <= 1
            elif shape == "wing":
                ok = 2 <= x <= 13 and (y - 4) >= abs(x - 7.5) * 0.6 and y <= 11 - (x % 4 == 0)
            elif shape == "ball":
                ok = ((x - 7.5) / 5.5) ** 2 + ((y - 8.5) / 5.5) ** 2 <= 1
            elif shape == "fang":
                ok = 5 <= x <= 10 and 2 <= y <= 13 and abs(x - 7.5) <= (14 - y) * 0.35
            else:  # shell
                ok = ((x - 7.5) / 6.5) ** 2 + ((y - 10) / 5.5) ** 2 <= 1 and y <= 12
            if ok:
                m.add((x, y))
    return m


def draw_loot(shape, light, mid, dark):
    img = new_img(16, 16)
    px = img.load()
    m = loot_mask(shape)
    for (x, y) in m:
        px[x, y] = (mid if (x + y) % 5 else light) + (255,)
        if (x + 1, y + 1) not in m or (x, y + 2) not in m:
            px[x, y] = dark + (255,)
        if (x - 1, y - 1) not in m and (x, y - 1) not in m:
            px[x, y] = light + (255,)
    for y in range(16):
        for x in range(16):
            if (x, y) not in m and any((x + dx, y + dy) in m for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = OUTLINE
    if shape == "shell":
        for x in range(3, 13, 3):
            for y in range(6, 12):
                if (x, y) in m:
                    px[x, y] = dark + (255,)
    if shape == "ball":
        for k in range(4, 12, 3):
            px[k, k] = dark + (255,)
    return img


def extend_icons(sheet):
    """Ajoute outils de mine, armes, minerais et butins (index 23+)."""
    extra = [tile(TOWN, 115), tile(DUNGEON, 104), tile(DUNGEON, 106), tile(DUNGEON, 118)]
    extra += [draw_loot(*l) for l in LOOT]
    # 41-49 : arroseurs, engrais, plats, outils améliorés
    extra += [draw_sprinkler((226, 120, 64), (170, 80, 44)), draw_sprinkler((192, 203, 220), (253, 190, 83))]
    extra.append(recolor(tile(FARM, 74), {(254, 201, 156): (150, 120, 90), (234, 165, 108): (110, 84, 60), (207, 130, 84): (80, 60, 44)}))
    extra += [draw_bowl((242, 132, 74), (78, 151, 76)), draw_plate(), draw_bowl((132, 198, 105), (195, 75, 53)), draw_bowl((150, 96, 60), (253, 190, 83))]
    extra.append(recolor(tile(TOWN, 115), STEEL))
    extra.append(recolor(tile(FARM, 84), COPPER))
    out = new_img(sheet.width + T * len(extra), T)
    out.alpha_composite(sheet, (0, 0))
    for k, img in enumerate(extra):
        out.alpha_composite(img, (sheet.width + k * T, 0))
    return out


# Recolorations (outils améliorés)
STEEL = {(140, 156, 181): (110, 190, 240), (82, 96, 124): (40, 90, 170), (189, 108, 74): (120, 70, 50)}
COPPER = {(139, 155, 180): (189, 88, 46), (192, 203, 220): (242, 152, 94), (82, 96, 124): (130, 60, 36),
          (235, 239, 248): (255, 200, 150)}


def recolor(img, mapping):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if (r, g, b) in mapping:
                px[x, y] = mapping[(r, g, b)] + (a,)
    return out


def outlined(img):
    px = img.load()
    solid = {(x, y) for y in range(16) for x in range(16) if px[x, y][3] > 0}
    for y in range(16):
        for x in range(16):
            if (x, y) not in solid and any((x + dx, y + dy) in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = OUTLINE
    return img


def draw_sprinkler(body, top):
    """Arroseur : pied métallique, tête colorée, jets d'eau."""
    img = new_img(16, 16)
    px = img.load()
    dark = tuple(max(0, c - 50) for c in body)
    for y in range(8, 14):
        for x in range(6, 10):
            px[x, y] = (body if x < 8 else dark) + (255,)
    for y in range(5, 8):
        for x in range(4, 12):
            px[x, y] = (top if y == 5 else body) + (255,)
    for x in range(3, 13):
        px[x, 14] = dark + (255,)
    img = outlined(img)
    px = img.load()
    for (x, y) in ((1, 3), (2, 2), (14, 3), (13, 2), (7, 1), (8, 1)):
        px[x, y] = (153, 216, 248, 255)
    return img


def draw_bowl(soup, garnish):
    img = new_img(16, 16)
    px = img.load()
    for y in range(7, 14):
        for x in range(2, 14):
            if ((x - 7.5) / 6) ** 2 + ((y - 7) / 6.5) ** 2 <= 1 and y >= 7:
                px[x, y] = (235, 239, 248, 255) if y > 8 else soup + (255,)
    for x in range(3, 13):
        px[x, 7] = soup + (255,)
        px[x, 8] = soup + (255,)
    for (x, y) in ((5, 6), (9, 6), (7, 7), (10, 7)):
        px[x, y] = garnish + (255,)
    for y in range(10, 14):
        for x in range(4, 12):
            if px[x, y][3] > 0 and y > 11:
                px[x, y] = (192, 203, 220, 255)
    return outlined(img)


def draw_plate():
    img = new_img(16, 16)
    px = img.load()
    for y in range(9, 14):
        for x in range(1, 15):
            if ((x - 7.5) / 7) ** 2 + ((y - 11.5) / 2.5) ** 2 <= 1:
                px[x, y] = (235, 239, 248, 255)
    fish = draw_fish(5, 2, (189, 108, 74), (227, 160, 100), (150, 84, 58), "stripes")
    img.alpha_composite(fish.crop((0, 4, 16, 14)), (0, 3))
    return img


def new_img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


HEART = [
    "........",
    ".XX..XX.",
    "XooXXooX",
    "XoooooOX",
    ".XoooOX.",
    "..XoOX..",
    "...XX...",
    "........",
]


def hearts():
    """Petits cœurs d'amitié (plein, vide), dessinés au pixel (CC0)."""
    out = Image.new("RGBA", (16, 8), (0, 0, 0, 0))
    px = out.load()
    full = {"X": (62, 39, 49, 255), "o": (228, 72, 84, 255), "O": (178, 40, 60, 255)}
    empty = {"X": (62, 39, 49, 255), "o": (120, 96, 92, 255), "O": (96, 74, 72, 255)}
    for k, colors in enumerate((full, empty)):
        for y, row in enumerate(HEART):
            for x, ch in enumerate(row):
                if ch in colors:
                    px[k * 8 + x, y] = colors[ch]
    out.save(os.path.join(OUT, "hearts.png"))


def app_icon():
    """Icône de l'application : le fermier devant ses carottes."""
    base = compose(TOWN, [[0, 0], [0, 0]])
    base.alpha_composite(tile(FARM, 6), (0, 14))
    base.alpha_composite(tile(FARM, 6), (17, 14))
    base.alpha_composite(tile(FARM, 109), (8, 4))
    base.resize((128, 128), Image.NEAREST).save(os.path.join(ROOT, "icon.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    world()
    crops()
    icons()
    objects()
    village()
    ui()
    hearts()
    fishing()
    app_icon()
    print("Sprites générés dans", OUT)
