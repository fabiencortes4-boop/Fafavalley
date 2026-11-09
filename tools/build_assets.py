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
import json
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
    tiles.append(tile(DUNGEON, 89))  # 81 coffre
    # 82-87 : herbes folles (x2), branche, arbre mort, pierre, boîte aux lettres
    tiles += [tile(FARM, 64), tile(FARM, 80), tile(FARM, 26), tile(FARM, 14), tile(FARM, 77), draw_mailbox()]
    cols = 16
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGBA", (cols * T, rows * T), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        out.alpha_composite(t, ((i % cols) * T, (i // cols) * T))
    out.save(os.path.join(OUT, "world.png"))
    recolor(out, AUTUMN).save(os.path.join(OUT, "world_autumn.png"))
    recolor(out, WINTER).save(os.path.join(OUT, "world_winter.png"))
    print("world.png :", len(tiles), "tuiles (+ automne, hiver)")


# --------------------------------------------------------------- cultures
# Lignes Kenney Tiny Farm : carotte, navet, maïs, tomate, chou, blé.
# Colonnes : 4 pousse, 5 jeune plant, 6 mûr, 8 légume, 9 sachet de graines.
CROP_ROWS = [0, 1, 2, 3, 4, 5]
SEEDED = 7  # petite butte de terre semée


# Cultures d'hiver ajoutées plus tard : icônes 189-192 (fin de planche)
LATE_CROPS = ["brussels_sprout", "winter_leek"]
# Fleurs semées (jonquille, coquelicot) : seulement le sachet (194-195), la
# récolte garde l'icône de la fleur cueillie
FLOWER_CROPS = ["daffodil", "poppy"]


def new_crops():
    """Cultures ajoutées (data/crops.json, champ « art ») : dessinées en
    recolorant une culture d'origine du pack Tiny Farm."""
    import json
    data = json.load(open(os.path.join(ROOT, "data", "crops.json")))
    return [(cid, c["art"]) for cid, c in data.items() if "art" in c]


def recolor_clothes(img, hue, sat):
    """Change la couleur des vêtements et cheveux, sans toucher à la peau."""
    import colorsys
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            skin = 0.0 <= h <= 0.14 and l > 0.5 and s > 0.2
            if l < 0.18 or skin or s < 0.15:
                continue
            nr, ng, nb = colorsys.hls_to_rgb(hue / 360, l, sat)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def recolor_hue(img, art):
    """Change la teinte des fruits (ou de toute la plante) d'une culture."""
    import colorsys
    out = img.copy()
    px = out.load()
    hue = art["hue"] / 360.0
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            h, l, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if l < 0.2:
                continue  # contour
            green = 70 / 360 <= h <= 170 / 360 and sat > 0.2
            if art["mode"] == "fruit" and green:
                continue
            if art["mode"] == "light" and l < 0.5:
                continue
            nl = min(0.95, max(0.08, l + art["light"]))
            ns = art["sat"] * min(1.0, sat / 0.6 + 0.3)
            nr, ng, nb = colorsys.hls_to_rgb(hue, nl, ns)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def crops():
    rows = [[SEEDED, r * 12 + 4, r * 12 + 5, r * 12 + 6] for r in CROP_ROWS]
    sheet = compose(FARM, rows)
    extra = new_crops()
    out = Image.new("RGBA", (sheet.width, T * (len(rows) + len(extra))), (0, 0, 0, 0))
    out.alpha_composite(sheet, (0, 0))
    for k, (cid, art) in enumerate(extra):
        base = art["base"] * 12
        for stage, i in enumerate([SEEDED, base + 4, base + 5, base + 6]):
            img = tile(FARM, i) if stage == 0 else recolor_hue(tile(FARM, i), art)
            out.alpha_composite(img, (stage * T, (len(rows) + k) * T))
    out.save(os.path.join(OUT, "crops.png"))


SUNFLOWER = 6 * 12 + 11  # tournesol du pack Tiny Farm


def crop_icons():
    """Icônes des cultures ajoutées : sachet de graines, puis récolte. Les
    cultures marquées « late_icons » ont leurs icônes en fin de planche (pour
    ne pas décaler les icônes existantes)."""
    icons = []
    for cid, art in new_crops():
        if cid in LATE_CROPS or cid in FLOWER_CROPS:
            continue
        icons += crop_icon_pair(cid, art)
    return icons


def late_crop_icons():
    data = json.load(open(os.path.join(ROOT, "data", "crops.json")))
    return [icon for cid in LATE_CROPS for icon in crop_icon_pair(cid, data[cid]["art"])]


def crop_icon_pair(cid, art):
    if True:
        harvest = tile(FARM, SUNFLOWER) if cid == "sunflower" else recolor_hue(tile(FARM, art["base"] * 12 + 8), art)
        packet = tile(FARM, 9)  # sachet (celui des carottes), image remplacée
        px = packet.load()
        paper = px[8, 4]
        for y in range(5, 13):
            for x in range(4, 12):
                if px[x, y][3] and px[x, y][:3] != OUTLINE[:3]:
                    px[x, y] = paper
        small = harvest.resize((8, 8), Image.NEAREST)
        packet.alpha_composite(small, (4, 5))
        return [packet, harvest]


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
    # player.png : rendu depuis le modèle 3D (tools/render_characters.gd --portraits)
    compose(TOWN, [[52, 53, 54], [64, 65, 66], [84, 86, 75]]).save(os.path.join(OUT, "house.png"))
    compose(FARM, [[93, 94, 95], [105, 106, 107], [117, 118, 119], [129, 130, 131],
                   [90, 91, 92], [126, 127, 128]]).save(os.path.join(OUT, "barn.png"))
    tile(FARM, 76).save(os.path.join(OUT, "shipping_bin.png"))
    draw_mailbox().save(os.path.join(OUT, "mailbox.png"))
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
    # Habitants (npcs.png) : rendus depuis leurs modèles 3D par
    # tools/render_characters.gd --portraits, pour que vue 2D, portraits et
    # vue 3D se ressemblent.


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
            px[x, y] = tuple(max(0, c - 40) for c in body) + (255,)
        if pattern == "waves" and y < cy and (x + (y * 2)) % 4 == 0:
            px[x, y] = (30, 60, 60, 255)
        if pattern == "plates" and y == cy - ry + 1 and x % 2 == 0:
            px[x, y] = (225, 228, 232, 255)
        if pattern == "gold_band" and x == cx + rx - 2 and y < cy:
            px[x, y] = (240, 190, 60, 255)
        if pattern == "speckle" and (x * 7 + y * 3) % 5 == 0:
            px[x, y] = tuple(max(0, c - 50) for c in body) + (255,)
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


# Poissons ajoutés (icônes 128+) : lac puis mer
FISH_MORE = [
    ("tench", 5, 3, (96, 118, 62), (178, 176, 96), (72, 92, 50), "scales"),
    ("bream", 5, 4, (172, 160, 128), (224, 218, 192), (122, 110, 90), None),
    ("zander", 6, 2, (128, 150, 128), (222, 226, 212), (98, 118, 108), "stripes"),
    ("sturgeon", 7, 2, (92, 102, 112), (202, 206, 212), (70, 80, 90), "plates"),
    ("crayfish", None, None, None, None, None, None),
    ("sardine", 5, 2, (112, 152, 204), (232, 240, 250), (90, 122, 172), "spots"),
    ("mackerel", 5, 2, (62, 132, 124), (232, 240, 240), (52, 102, 100), "waves"),
    ("seabass", 5, 3, (150, 166, 178), (236, 240, 246), (118, 130, 142), None),
    ("seabream", 4, 4, (176, 186, 198), (242, 242, 244), (150, 160, 175), "gold_band"),
    ("red_mullet", 5, 3, (232, 102, 92), (252, 202, 172), (200, 72, 62), None),
    ("sole", 6, 3, (172, 142, 102), (196, 168, 126), (140, 112, 80), "speckle"),
    ("tuna", 6, 4, (42, 62, 112), (202, 212, 228), (242, 202, 62), None),
    ("squid", None, None, None, None, None, None),
    ("conger", 7, 1, (72, 78, 88), (152, 156, 166), (60, 66, 76), None),
    ("swordfish", 4, 3, (70, 82, 150), (210, 218, 236), (60, 70, 130), "sword"),
]


def draw_crayfish():
    """Écrevisse : carapace rouge-brun, pinces, antennes."""
    img = new_img(16, 16)
    px = img.load()
    body, dark = (196, 86, 56), (140, 54, 38)
    for x in range(4, 13):
        for y in range(7, 10):
            px[x, y] = body + (255,)
    for x in range(3, 6):  # queue
        px[x, 6], px[x, 10] = dark + (255,), dark + (255,)
    for (x, y) in ((12, 5), (13, 4), (14, 4), (13, 6), (12, 11), (13, 12), (14, 12), (13, 10)):  # pinces
        px[x, y] = body + (255,)
    for (x, y) in ((14, 3), (15, 2), (14, 13), (15, 14)):
        px[x, y] = dark + (255,)
    for x in (6, 8, 10):  # pattes
        px[x, 11], px[x, 5] = dark + (255,), dark + (255,)
    for x in range(5, 12, 2):
        px[x, 8] = dark + (255,)
    px[12, 7] = OUTLINE
    return outline_img(img)


def draw_squid():
    """Calmar : manteau pointu, tentacules."""
    img = new_img(16, 16)
    px = img.load()
    body, light = (226, 160, 172), (246, 206, 214)
    for y in range(2, 10):
        half = 1 + (y - 2) // 2
        for x in range(8 - half, 8 + half + 1):
            px[x, y] = (light if x == 8 - half + 1 else body) + (255,)
    for k, x in enumerate((5, 7, 9, 11)):
        for y in range(10, 14 + (k % 2)):
            px[x if y < 12 else x + (1 if k > 1 else -1), y] = body + (255,)
    px[7, 7], px[9, 7] = OUTLINE, OUTLINE
    return outline_img(img)


def outline_img(img):
    px = img.load()
    solid = {(x, y) for y in range(16) for x in range(16) if px[x, y][3] > 0 and px[x, y] != OUTLINE}
    for (x, y) in list(solid):
        for (nx, ny) in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < 16 and 0 <= ny < 16 and (nx, ny) not in solid and px[nx, ny][3] == 0:
                px[nx, ny] = OUTLINE
    return img


def more_fish_icons():
    out = []
    for (fid, rx, ry, body, belly, fin, pattern) in FISH_MORE:
        if fid == "crayfish":
            out.append(draw_crayfish())
        elif fid == "squid":
            out.append(draw_squid())
        else:
            img = draw_fish(rx, ry, body, belly, fin, pattern)
            if pattern == "sword":
                # Rostre de l'espadon : une longue épée devant la tête
                px = img.load()
                for x in range(9 + rx, 16):
                    px[x, 8] = (190, 196, 214, 255)
                    px[x, 7] = OUTLINE if px[x, 7][3] == 0 else px[x, 7]
                    px[x, 9] = OUTLINE if px[x, 9][3] == 0 else px[x, 9]
            out.append(img)
    return out


def draw_bottle(juice, light):
    """Bouteille de jus : verre, liquide coloré, bouchon de liège."""
    img = new_img(16, 16)
    px = img.load()
    for y in range(7, 15):
        for x in range(5, 11):
            px[x, y] = (juice if y > 8 else (220, 236, 240)) + (255,)
    for y in range(3, 7):
        for x in range(7, 9):
            px[x, y] = (220, 236, 240, 255)
    px[7, 2], px[8, 2] = (170, 120, 70, 255), (170, 120, 70, 255)
    for y in range(9, 14):
        px[6, y] = light + (255,)
    for x in range(5, 11):
        px[x, 11] = (245, 230, 190, 255)
    return outlined(img)


def draw_machine(kind):
    """Icônes des machines de transformation."""
    img = new_img(16, 16)
    px = img.load()
    def rect(x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                px[x, y] = c + (255,)
    if kind == "jar":  # grand bocal de verre sur un socle
        rect(3, 13, 13, 15, (150, 100, 60))
        rect(4, 4, 12, 13, (200, 225, 235))
        rect(5, 7, 11, 12, (200, 90, 110))
        rect(4, 2, 12, 4, (120, 80, 50))
        rect(5, 5, 6, 12, (240, 250, 255))
    elif kind == "press":  # tonneau cerclé et sa vis
        rect(3, 5, 13, 15, (160, 104, 62))
        for y in (7, 12):
            rect(3, y, 13, y + 1, (90, 90, 96))
        rect(7, 1, 9, 5, (110, 110, 118))
        rect(4, 1, 12, 2, (110, 110, 118))
    elif kind == "smoker":  # petit four de briques et cheminée
        rect(2, 6, 14, 15, (170, 80, 60))
        for y in (8, 11, 14):
            rect(2, y, 14, y + 1, (130, 60, 46))
        rect(5, 9, 11, 13, (40, 30, 30))
        rect(10, 1, 13, 6, (120, 60, 46))
        px[11, 0] = (200, 200, 200, 255)
    elif kind == "cheese":  # presse en bois, meule jaune
        rect(2, 13, 14, 15, (140, 92, 56))
        rect(3, 2, 5, 13, (140, 92, 56))
        rect(11, 2, 13, 13, (140, 92, 56))
        rect(3, 2, 13, 4, (120, 78, 46))
        rect(5, 9, 11, 13, (250, 210, 90))
        rect(7, 4, 9, 9, (110, 110, 118))
    return outlined(img)


def draw_sea_life(kind):
    """Crabe, crevette, moule, huître, appât, casier."""
    img = new_img(16, 16)
    px = img.load()
    def put(pts, c):
        for (x, y) in pts:
            px[x, y] = c + (255,)
    if kind == "crab":
        body = [(x, y) for x in range(4, 12) for y in range(7, 11)]
        put(body, (214, 84, 60))
        put([(x, 7) for x in range(5, 11)], (240, 120, 90))
        put([(2, 5), (3, 5), (2, 6), (3, 7), (12, 7), (13, 5), (14, 5), (14, 6)], (214, 84, 60))
        put([(4, 11), (6, 12), (9, 12), (11, 11), (3, 10), (12, 10)], (170, 60, 44))
        put([(6, 6), (9, 6)], (40, 30, 30))
    elif kind == "shrimp":
        pts = [(4 + i, 9 - int(2.5 * (1 - ((i - 4) / 4.0) ** 2))) for i in range(9)]
        for (x, y) in pts:
            put([(x, y), (x, y + 1)], (240, 140, 110))
        put([(12, 6), (13, 5), (14, 4)], (200, 100, 80))
        put([(3, 9), (2, 10), (3, 11)], (220, 120, 90))
    elif kind == "mussel":
        for y in range(4, 13):
            w = 2 + (y - 4) // 2
            put([(x, y) for x in range(8 - w // 2, 8 + w)], (40, 44, 70))
        put([(8, y) for y in range(5, 12)], (90, 100, 140))
    elif kind == "oyster":
        for y in range(5, 12):
            put([(x, y) for x in range(3, 13) if (x - 8) ** 2 / 25 + (y - 8) ** 2 / 9 <= 1], (190, 180, 160))
        put([(x, 8) for x in range(5, 11)], (230, 225, 210))
        put([(8, 8)], (250, 250, 255))
    elif kind == "bait":
        put([(x, y) for x in range(4, 12) for y in range(8, 14)], (150, 110, 70))
        put([(x, 7) for x in range(4, 12)], (120, 85, 55))
        put([(6, 6), (7, 5), (8, 5), (9, 6), (10, 5)], (220, 120, 130))
    elif kind == "pot":
        put([(x, y) for x in range(3, 13) for y in range(6, 13) if (x + y) % 2 == 0], (170, 130, 80))
        put([(x, 6) for x in range(3, 13)] + [(x, 12) for x in range(3, 13)], (130, 95, 60))
        put([(3, y) for y in range(6, 13)] + [(12, y) for y in range(6, 13)], (130, 95, 60))
        put([(8, 3), (8, 4), (8, 5)], (230, 220, 190))
        put([(7, 2), (8, 2), (9, 2)], (220, 60, 50))
    return outlined(img)


def draw_misc(kind):
    """Tonneau, ruche, miel, minerais de glace et de lave, cœur de la
    montagne, lait de chèvre, laine, meubles, plan d'agrandissement."""
    img = new_img(16, 16)
    px = img.load()
    def rect(x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                px[x, y] = c + (255,)
    def gem(light, mid, dark):
        for y in range(3, 14):
            w = 5 - abs(y - 8) // 1 if abs(y - 8) < 5 else 0
            for x in range(8 - w, 8 + w):
                px[x, y] = (light if x < 8 and y < 8 else (mid if y < 10 else dark)) + (255,)
    if kind == "cask":
        rect(2, 4, 14, 13, (150, 96, 56))
        for x in (4, 11):
            rect(x, 4, x + 1, 13, (90, 90, 96))
        rect(7, 7, 9, 10, (60, 40, 30))
    elif kind == "beehive":
        for i, y in enumerate(range(4, 14, 2)):
            rect(4 - (i % 2), y, 12 + (i % 2), y + 2, (230, 190, 90) if i % 2 == 0 else (210, 160, 70))
        rect(7, 11, 9, 13, (60, 40, 30))
        rect(3, 14, 13, 15, (130, 90, 55))
    elif kind == "honey":
        rect(4, 5, 12, 14, (240, 170, 40))
        rect(5, 6, 6, 13, (255, 210, 110))
        rect(4, 3, 12, 5, (200, 150, 90))
        rect(6, 9, 10, 11, (250, 235, 200))
    elif kind == "frost":
        gem((230, 250, 255), (150, 210, 245), (90, 150, 210))
    elif kind == "lava":
        gem((255, 220, 120), (240, 110, 50), (160, 40, 30))
    elif kind == "heart":
        for y in range(4, 14):
            for x in range(2, 14):
                dx, dy = (x - 5.5, y - 6) if x < 8 else (x - 10.5, y - 6)
                if dx * dx + dy * dy <= 7 or (y >= 6 and abs(x - 8) <= 13 - y):
                    px[x, y] = ((120, 230, 220) if x + y < 14 else (40, 160, 170)) + (255,)
        px[5, 5] = (255, 255, 255, 255)
    elif kind == "goat_milk":
        rect(5, 4, 11, 14, (245, 242, 230))
        rect(6, 2, 10, 4, (200, 190, 170))
        rect(5, 8, 11, 10, (150, 190, 120))
    elif kind == "wool":
        for (cx, cy) in ((6, 8), (10, 8), (8, 6), (8, 10)):
            for y in range(cy - 3, cy + 3):
                for x in range(cx - 3, cx + 3):
                    if (x - cx) ** 2 + (y - cy) ** 2 <= 8:
                        px[x, y] = (250, 248, 240, 255)
        px[7, 7], px[10, 9] = (215, 210, 200, 255), (215, 210, 200, 255)
    elif kind == "rug":
        rect(2, 4, 14, 12, (170, 60, 60))
        rect(4, 6, 12, 10, (220, 180, 90))
        rect(6, 7, 10, 9, (170, 60, 60))
    elif kind == "lamp":
        rect(7, 6, 9, 14, (90, 70, 50))
        rect(5, 13, 11, 15, (90, 70, 50))
        rect(4, 2, 12, 7, (250, 220, 140))
    elif kind == "plant":
        rect(5, 10, 11, 15, (180, 100, 60))
        for (x, y) in ((8, 3), (6, 5), (10, 5), (7, 7), (9, 7), (8, 8), (5, 8), (11, 8)):
            rect(x - 1, y - 1, x + 1, y + 1, (70, 150, 80))
    elif kind == "shelf":
        rect(3, 2, 13, 15, (130, 85, 50))
        for y in (5, 9, 13):
            rect(4, y - 3, 12, y, (60, 40, 30))
            for k, x in enumerate(range(4, 12, 2)):
                rect(x, y - 3, x + 1, y, [(200, 60, 60), (60, 120, 200), (230, 190, 60), (80, 160, 90)][(k + y) % 4])
    elif kind == "painting":
        rect(2, 3, 14, 13, (180, 140, 60))
        rect(3, 4, 13, 12, (140, 200, 240))
        rect(3, 9, 13, 12, (90, 160, 80))
        rect(9, 5, 11, 7, (255, 230, 120))
    elif kind == "table":
        rect(2, 6, 14, 8, (150, 100, 60))
        for x in (3, 12):
            rect(x, 8, x + 1, 14, (120, 80, 50))
        rect(6, 4, 9, 6, (240, 240, 240))
    elif kind == "pine_cone":
        # Écailles brunes en losange, plus claires au bord
        for y in range(3, 15):
            w = min(y - 2, 15 - y, 5)
            for x in range(8 - w, 8 + w):
                c = (150, 96, 52) if (x + y) % 3 else (196, 136, 78)
                px[x, y] = (c if y < 12 else (112, 70, 40)) + (255,)
        rect(7, 1, 9, 3, (90, 70, 40))
    elif kind == "plane_seed":
        # Boule de platane hérissée, au bout de sa tige
        rect(7, 1, 8, 6, (110, 80, 50))
        for y in range(5, 15):
            for x in range(3, 13):
                d = (x - 7.5) ** 2 + (y - 9.5) ** 2
                if d <= 20:
                    px[x, y] = ((176, 150, 90) if (x * 3 + y) % 4 else (120, 98, 58)) + (255,)
        px[6, 7], px[9, 8] = (220, 200, 140, 255), (220, 200, 140, 255)
    elif kind == "acorn":
        # Gland : cupule rugueuse et fruit brillant
        for y in range(6, 15):
            for x in range(4, 12):
                if (x - 7.5) ** 2 / 14 + (y - 9.5) ** 2 / 22 <= 1:
                    px[x, y] = ((214, 150, 70) if x < 7 and y < 11 else (176, 112, 50)) + (255,)
        rect(3, 4, 13, 7, (120, 86, 50))
        for x in range(3, 13, 2):
            px[x, 5] = (90, 64, 38, 255)
        rect(7, 2, 9, 4, (90, 64, 38))
    elif kind == "hardwood":
        # Bûches de chêne sombres, cernes visibles
        for (cx, cy) in ((5, 11), (11, 11), (8, 6)):
            for y in range(cy - 3, cy + 3):
                for x in range(cx - 3, cx + 3):
                    d = (x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2
                    if d <= 9:
                        px[x, y] = ((170, 120, 70) if d <= 3 else ((120, 76, 44) if d <= 6 else (84, 52, 30))) + (255,)
    elif kind == "oak_cask":
        rect(2, 4, 14, 13, (104, 64, 36))
        rect(3, 5, 13, 7, (130, 82, 46))
        for x in (3, 7, 12):
            rect(x, 4, x + 1, 13, (70, 70, 78))
        rect(7, 8, 9, 10, (210, 170, 70))
    elif kind == "armchair":
        rect(3, 2, 13, 9, (120, 74, 40))
        rect(4, 3, 12, 8, (170, 60, 60))
        rect(2, 8, 14, 12, (120, 74, 40))
        rect(4, 8, 12, 11, (196, 80, 76))
        for x in (3, 12):
            rect(x, 12, x + 1, 15, (90, 56, 30))
    elif kind == "wardrobe":
        rect(3, 1, 13, 15, (110, 68, 38))
        rect(2, 1, 14, 3, (86, 52, 28))
        rect(4, 4, 8, 14, (140, 90, 50))
        rect(8, 4, 12, 14, (140, 90, 50))
        rect(7, 8, 8, 10, (230, 190, 90))
        rect(8, 8, 9, 10, (230, 190, 90))
    elif kind == "clock":
        rect(5, 1, 11, 15, (110, 68, 38))
        for y in range(2, 8):
            for x in range(5, 11):
                if (x - 7.5) ** 2 + (y - 4.5) ** 2 <= 6:
                    px[x, y] = (245, 236, 210, 255)
        px[7, 3], px[7, 4], px[8, 4] = (40, 30, 20, 255), (40, 30, 20, 255), (40, 30, 20, 255)
        rect(7, 8, 9, 13, (60, 40, 25))
        rect(7, 11, 9, 13, (230, 190, 70))
    elif kind == "fence":
        for x in (3, 11):
            rect(x, 3, x + 2, 15, (150, 100, 58))
            rect(x, 3, x + 2, 4, (190, 140, 90))
        for y in (6, 10):
            rect(1, y, 15, y + 2, (176, 120, 70))
    elif kind == "path_wood":
        for k, y in enumerate((3, 7, 11)):
            rect(2 + k % 2, y, 14 - (k + 1) % 2, y + 3, (170, 116, 66) if k % 2 == 0 else (150, 100, 56))
            px[4, y + 1] = (90, 60, 34, 255)
            px[11, y + 1] = (90, 60, 34, 255)
    elif kind == "path_stone":
        for (cx, cy, r, c) in ((5, 5, 3, (170, 168, 160)), (11, 6, 3, (150, 148, 142)), (7, 11, 3, (160, 158, 150)), (12, 12, 2, (180, 178, 170))):
            for y in range(cy - r, cy + r):
                for x in range(cx - r, cx + r):
                    if (x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2 <= r * r:
                        px[x, y] = c + (255,)
    elif kind == "trophy":
        rect(4, 3, 12, 4, (250, 215, 90))
        for y in range(4, 9):
            w = 4 - (y - 4) // 2
            rect(8 - w, y, 8 + w, y + 1, (240, 190, 60) if y % 2 else (255, 225, 110))
        rect(2, 4, 4, 7, (220, 170, 50))
        rect(12, 4, 14, 7, (220, 170, 50))
        rect(7, 9, 9, 12, (220, 170, 50))
        rect(4, 12, 12, 15, (120, 80, 50))
    elif kind == "plan":
        rect(3, 2, 13, 14, (235, 225, 195))
        for y in (5, 8, 11):
            rect(5, y, 11, y + 1, (90, 110, 170))
        rect(5, 5, 6, 12, (90, 110, 170))
    return outlined(img)


def legendary(img):
    """Contour doré des poissons légendaires."""
    px = img.load()
    for y in range(16):
        for x in range(16):
            if px[x, y] == OUTLINE:
                px[x, y] = (232, 176, 40, 255)
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
    # 50 coffre, 51-52 sacs (grand, de voyageur)
    extra.append(tile(DUNGEON, 89))
    extra.append(tile(TOWN, 107))
    extra.append(recolor(tile(TOWN, 107), {(189, 108, 74): (78, 151, 76), (234, 165, 108): (132, 198, 105), (207, 130, 84): (71, 159, 74), (184, 101, 66): (60, 120, 60)}))
    # 53-64 : hache, faux, bois, fibre, cueillette (2 par saison)
    extra += [tile(FARM, 87), tile(FARM, 88), draw_log(),
              recolor(tile(FARM, 80), {(78, 151, 76): (205, 186, 120), (132, 198, 105): (235, 214, 150), (71, 159, 74): (190, 160, 100)})]
    extra += [tile(TOWN, 17), draw_flower((253, 214, 83), (227, 160, 40)),
              tile(FARM, 78), draw_flower((232, 69, 55), (176, 40, 30)),
              tile(TOWN, 29), tile(FARM, 79),
              recolor(tile(FARM, 78), {(78, 151, 76): (30, 90, 60), (132, 198, 105): (50, 120, 80), (71, 159, 74): (40, 105, 70)}),
              recolor(tile(FARM, 125), {(234, 165, 108): (150, 90, 130), (254, 201, 156): (190, 130, 170), (207, 130, 84): (110, 60, 100)})]
    # 65-73 : élevage (foin, brosse, seau à lait, œuf, gros œuf, lait, laine, truffe, omelette)
    egg = tile(FARM, 125)
    big_egg = new_img(16, 16)
    big_egg.alpha_composite(egg.resize((20, 20), Image.NEAREST).crop((2, 1, 18, 17)))
    extra += [tile(FARM, 96), draw_brush(), tile(FARM, 72), egg, big_egg, tile(FARM, 123),
              draw_loot("ball", (255, 250, 245), (240, 232, 225), (205, 195, 190)),
              draw_loot("blob", (110, 90, 80), (80, 62, 56), (52, 40, 38)),
              draw_bowl((253, 214, 83), (78, 151, 76))]
    # 74-75 : confiture de baies, fromage (débloqués par l'histoire)
    extra += [draw_jar((150, 40, 90), (195, 75, 120)), draw_cheese()]
    # 76-77 : lame d'acier (coffre du niveau 15), épée de Firmin (niveau 30)
    extra += [tint_metal(tile(DUNGEON, 106), (120, 190, 255)), tint_metal(tile(DUNGEON, 106), (255, 205, 80))]
    # 78+ : cultures ajoutées (graines, récolte)
    extra += crop_icons()
    # puis 3 plats : soupe de citrouille, ratatouille, tarte aux myrtilles
    extra += [draw_bowl((242, 150, 50), (250, 240, 220)), draw_bowl((200, 60, 50), (110, 50, 130)), draw_bowl((70, 80, 170), (240, 220, 160))]
    # 117+ : arbres fruitiers (jeune arbre, fruit) : cerisier, pêcher, oranger, pommier
    for color, leaf in (((212, 42, 60), True), ((245, 164, 106), True), ((240, 138, 30), True), ((200, 48, 42), True)):
        extra += [draw_sapling(color), draw_fruit(color, cherry=(color == (212, 42, 60)))]
    # 125 bouquet, 126 pendentif de la source (mariage)
    extra += [draw_bouquet(), draw_pendant()]
    # 127 soupe du marin
    extra += [draw_bowl((235, 225, 200), (240, 140, 90))]
    # 128-142 : poissons ajoutés (lac, puis mer)
    extra += more_fish_icons()
    # 143-147 : produits artisanaux (cornichons, jus de fruits, jus de légumes,
    # poisson fumé, mayonnaise)
    extra += [draw_jar((110, 150, 60), (150, 190, 90)), draw_bottle((235, 120, 70), (250, 170, 120)),
              draw_bottle((120, 170, 70), (160, 210, 110)),
              draw_fish(5, 3, (150, 96, 56), (196, 140, 86), (110, 70, 40), "stripes"),
              draw_jar((248, 240, 210), (255, 252, 240))]
    # 148-151 : machines (bocal, pressoir, fumoir, presse à fromage)
    extra += [draw_machine(k) for k in ("jar", "press", "smoker", "cheese")]
    # 152-157 : crabe, crevette, moule, huître, appât, casier
    extra += [draw_sea_life(k) for k in ("crab", "shrimp", "mussel", "oyster", "bait", "pot")]
    # 158-161 : poissons légendaires (carpe ancienne, silure géant, brochet de
    # la source, grand requin bleu)
    extra += [legendary(draw_fish(5, 4, (150, 110, 60), (230, 190, 120), (120, 80, 40), "scales")),
              legendary(draw_fish(6, 3, (60, 64, 76), (130, 134, 146), (50, 54, 66), "whiskers")),
              legendary(draw_fish(6, 2, (90, 170, 150), (210, 240, 220), (60, 140, 120), "spots")),
              legendary(draw_fish(6, 3, (60, 100, 170), (220, 228, 240), (40, 80, 150), None))]
    # 162+ : tonneau, ruche, miel, cristal de givre, opale de feu, cœur de la
    # montagne, lait de chèvre, laine, tapis, lampe, plante, bibliothèque,
    # tableau, table, plan d'agrandissement
    extra += [draw_misc(k) for k in ("cask", "beehive", "honey", "frost", "lava", "heart", "goat_milk", "wool",
                                     "rug", "lamp", "plant", "shelf", "painting", "table", "plan",
                                     "pine_cone", "plane_seed", "acorn", "hardwood")]
    # 181 : hache renforcée (lame d'acier, manche en bois dur) ; 182-185 : fût de
    # chêne, fauteuil, armoire et horloge comtoise
    extra.append(recolor(tile(FARM, 87), {(139, 155, 180): (110, 190, 240), (140, 156, 181): (110, 190, 240),
                                          (192, 203, 220): (190, 230, 250), (82, 96, 124): (40, 90, 170),
                                          (189, 108, 74): (110, 66, 40), (234, 165, 108): (150, 96, 56)}))
    extra += [draw_misc(k) for k in ("oak_cask", "armchair", "wardrobe", "clock")]
    # 186-188 : clôture en bois, chemin de planches, chemin pavé
    extra += [draw_misc(k) for k in ("fence", "path_wood", "path_stone")]
    # 189-192 : cultures d'hiver (graines, récolte) ; 193 : trophée de Valfleur
    extra += late_crop_icons()
    extra.append(draw_misc("trophy"))
    data = json.load(open(os.path.join(ROOT, "data", "crops.json")))
    extra += [crop_icon_pair(cid, data[cid]["art"])[0] for cid in FLOWER_CROPS]
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


def tint_metal(img, color):
    """Teinte les pixels gris (le métal) d'une couleur, en gardant la lumière."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and max(r, g, b) - min(r, g, b) < 40 and max(r, g, b) > 60:
                k = (r + g + b) / 3 / 255
                px[x, y] = (min(255, int(color[0] * k * 1.25)), min(255, int(color[1] * k * 1.25)), min(255, int(color[2] * k * 1.25)), a)
    return out


def draw_fruit(color, cherry=False):
    img = new_img(16, 16)
    px = img.load()
    light = tuple(min(255, c + 60) for c in color)
    centers = [(5, 10), (10, 10)] if cherry else [(8, 9)]
    radius = 3.2 if cherry else 5.2
    for (cx, cy) in centers:
        for y in range(16):
            for x in range(16):
                if (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2:
                    px[x, y] = color + (255,)
        px[cx - 1, cy - 1] = light + (255,)
    stem = (90, 60, 30, 255)
    if cherry:
        for k in range(5):
            px[5 + k // 2, 6 - k] = stem
            px[10 - k // 2, 6 - k] = stem
    else:
        px[8, 3] = stem
        px[8, 2] = stem
        px[9, 2] = (78, 151, 76, 255)
        px[10, 2] = (78, 151, 76, 255)
    return outlined(img)


def draw_sapling(fruit_color):
    """Jeune arbre en pot de terre, avec un fruit pour le reconnaître."""
    img = new_img(16, 16)
    px = img.load()
    for y in range(11, 15):
        for x in range(5, 11):
            px[x, y] = (150, 95, 60, 255)
    for y in range(6, 11):
        px[8, y] = (110, 75, 45, 255)
    for y in range(1, 8):
        for x in range(3, 13):
            if (x - 8) ** 2 / 25 + (y - 4.5) ** 2 / 10 <= 1:
                px[x, y] = (78, 151, 76, 255) if (x + y) % 3 else (101, 165, 86, 255)
    px[6, 4] = fruit_color + (255,)
    px[10, 5] = fruit_color + (255,)
    return outlined(img)


def draw_bouquet():
    img = new_img(16, 16)
    px = img.load()
    for y in range(8, 15):
        for x in range(7 - (14 - y) // 3, 9 + (14 - y) // 3):
            px[x, y] = (101, 165, 86, 255)
    for x in range(5, 11):
        px[x, 10] = (240, 230, 210, 255)
    for (cx, cy, col) in ((5, 5, (232, 69, 55)), (8, 3, (253, 214, 83)), (11, 5, (190, 110, 210)), (7, 7, (255, 160, 190)), (10, 7, (232, 69, 55))):
        for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 0), (0, -1)):
            px[cx + dx, cy + dy] = col + (255,)
    return outlined(img)


def draw_pendant():
    img = new_img(16, 16)
    px = img.load()
    for k in range(9):
        px[3 + k, 2 + abs(4 - k) // 2] = (230, 200, 90, 255)
    for y in range(7, 14):
        for x in range(5, 12):
            if abs(x - 8) + abs(y - 10) <= 3:
                px[x, y] = (110, 190, 240, 255) if (x + y) % 3 else (180, 230, 255, 255)
    return outlined(img)


def draw_jar(jam, light):
    img = new_img(16, 16)
    px = img.load()
    for y in range(5, 15):
        for x in range(4, 12):
            px[x, y] = (jam if y > 6 else (235, 239, 248)) + (255,)
    for y in range(7, 14):
        px[5, y] = light + (255,)
    for x in range(4, 12):  # couvercle à carreaux
        px[x, 3] = ((232, 69, 55) if x % 2 else (255, 255, 255)) + (255,)
        px[x, 4] = ((255, 255, 255) if x % 2 else (232, 69, 55)) + (255,)
    for x in range(5, 11):  # étiquette
        px[x, 10] = (245, 230, 190, 255)
        px[x, 11] = (245, 230, 190, 255)
    return outlined(img)


def draw_cheese():
    img = new_img(16, 16)
    px = img.load()
    for y in range(5, 13):
        for x in range(2, 14):
            if x - 2 >= (12 - y) * 1.4 - 2:
                px[x, y] = ((253, 214, 83) if y > 6 else (255, 232, 140)) + (255,)
    for (x, y) in ((8, 9), (11, 8), (10, 11), (6, 11)):
        px[x, y] = (227, 160, 40, 255)
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


# Saisons : remplacement des verts (herbe, feuillages, eau en hiver)
AUTUMN = {(132, 198, 105): (205, 172, 92), (101, 165, 86): (178, 132, 70), (139, 216, 125): (232, 200, 120),
          (71, 159, 74): (227, 134, 40), (78, 151, 76): (195, 75, 53)}
WINTER = {(132, 198, 105): (235, 239, 248), (101, 165, 86): (192, 203, 220), (139, 216, 125): (255, 255, 255),
          (71, 159, 74): (52, 110, 82), (78, 151, 76): (44, 96, 74),
          (92, 168, 214): (156, 204, 232), (64, 132, 196): (120, 172, 214), (176, 224, 246): (226, 242, 252)}


def draw_brush():
    img = new_img(16, 16)
    px = img.load()
    for y in range(4, 12):
        for x in range(3, 9):
            px[x, y] = (189, 108, 74, 255) if y < 9 else (150, 84, 58, 255)
    for y in range(4, 12):
        for x in range(9, 13):
            if (x + y) % 2 == 0:
                px[x, y] = (235, 214, 150, 255)
            else:
                px[x, y] = (205, 186, 120, 255)
    return outlined(img)


def draw_mailbox():
    img = new_img(16, 16)
    px = img.load()
    for y in range(8, 16):
        px[7, y] = (150, 84, 58, 255)
        px[8, y] = (118, 59, 54, 255)
    for y in range(2, 9):
        for x in range(3, 13):
            px[x, y] = ((232, 69, 55) if y > 3 else (242, 120, 100)) + (255,)
    for x in range(4, 12):
        px[x, 8] = (176, 40, 30, 255)
    for y in range(1, 5):
        px[13, y] = (253, 214, 83, 255)
    px[14, 1] = (253, 214, 83, 255)
    return outlined(img)


def draw_log():
    img = new_img(16, 16)
    px = img.load()
    for y in range(6, 12):
        for x in range(2, 13):
            px[x, y] = ((189, 108, 74) if y < 9 else (150, 84, 58)) + (255,)
    for y in range(6, 12):
        for x in range(12, 15):
            if ((x - 12.5) / 2) ** 2 + ((y - 8.5) / 3) ** 2 <= 1:
                px[x, y] = (234, 190, 140, 255)
    px[13, 8] = (189, 108, 74, 255)
    return outlined(img)


def draw_flower(petal, dark):
    img = new_img(16, 16)
    px = img.load()
    for y in range(8, 15):
        px[8, y] = (78, 151, 76, 255)
    px[7, 11] = px[6, 10] = (78, 151, 76, 255)
    for (x, y) in ((8, 3), (6, 5), (10, 5), (7, 7), (9, 7), (8, 4), (7, 5), (9, 5), (8, 6), (7, 4), (9, 4), (7, 6), (9, 6)):
        px[x, y] = petal + (255,)
    px[8, 5] = dark + (255,)
    return outlined(img)


def hud_icons():
    """Petites icônes du HUD (12x12) : soleil, pluie, neige, pièce."""
    out = new_img(48, 12)
    px = out.load()
    sun, cloud, rain, coin = (253, 214, 83, 255), (235, 239, 248, 255), (92, 168, 214, 255), (253, 190, 83, 255)
    for y in range(12):
        for x in range(12):
            d = ((x - 5.5) ** 2 + (y - 5.5) ** 2) ** 0.5
            if d <= 3.2:
                px[x, y] = sun
            elif 4.2 <= d <= 5.2 and (x in (5, 6) or y in (5, 6) or abs(x - y) <= 0 or abs(x + y - 11) <= 0):
                px[x, y] = sun
            # pluie : nuage + gouttes
            if ((x - 5.5) / 5) ** 2 + ((y - 4) / 3) ** 2 <= 1:
                px[12 + x, y] = cloud
            if y >= 8 and x in (3, 6, 9) and (y + x) % 2 == 0:
                px[12 + x, y] = rain
            # neige : flocon
            if x == 5 or y == 5 or x == y or x + y == 10:
                if 1 <= x <= 9 and 1 <= y <= 9:
                    px[24 + x, y] = cloud
            # pièce
            if ((x - 5.5) / 4.5) ** 2 + ((y - 5.5) / 5) ** 2 <= 1:
                px[36 + x, y] = coin if not (4 <= x <= 7 and 3 <= y <= 8 and x in (5, 6)) else (227, 134, 40, 255)
    for k in range(4):
        part = out.crop((k * 12, 0, k * 12 + 12, 12))
        big = new_img(14, 14)
        big.alpha_composite(part, (1, 1))
        px2 = big.load()
        solid = {(x, y) for y in range(14) for x in range(14) if px2[x, y][3] > 0}
        for y in range(14):
            for x in range(14):
                if (x, y) not in solid and any((x + dx, y + dy) in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    px2[x, y] = OUTLINE
        out.paste(big.crop((1, 1, 13, 13)), (k * 12, 0))
    out.save(os.path.join(OUT, "hud_icons.png"))


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
    # Icône du projet en 180 px (= icône iOS « apple-touch-icon » du web)
    icon = Image.new("RGBA", (180, 180), (132, 198, 105, 255))
    icon.alpha_composite(base.resize((160, 160), Image.NEAREST), (10, 10))
    icon.save(os.path.join(ROOT, "icon.png"))
    # Icônes de l'application web (écran d'accueil iOS / Android)
    web = os.path.join(ROOT, "assets", "web")
    os.makedirs(web, exist_ok=True)
    for size, scale in ((144, 4), (180, 5), (512, 16)):
        canvas = Image.new("RGBA", (size, size), (132, 198, 105, 255))
        art = base.resize((32 * scale, 32 * scale), Image.NEAREST)
        canvas.alpha_composite(art, ((size - art.width) // 2, (size - art.height) // 2))
        canvas.convert("RGB").save(os.path.join(web, "icon_%d.png" % size))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    world()
    crops()
    icons()
    objects()
    village()
    ui()
    hearts()
    hud_icons()
    fishing()
    app_icon()
    print("Sprites générés dans", OUT)
