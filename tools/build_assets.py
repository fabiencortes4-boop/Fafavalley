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
    ui()
    app_icon()
    print("Sprites générés dans", OUT)
