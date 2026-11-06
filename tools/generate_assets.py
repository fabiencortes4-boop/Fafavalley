#!/usr/bin/env python3
"""Génère les graphismes pixel art de Fafavalley.

Tous les sprites sont dessinés pixel par pixel par ce script : ce sont des
créations originales, placées dans le domaine public (CC0 1.0).
Relancer le script régénère les PNG dans assets/sprites/ :

    python3 tools/generate_assets.py
"""
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")
T = 16  # taille d'une tuile

rng = random.Random(42)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def speckle(d, ox, oy, colors, n, w=T, h=T):
    for _ in range(n):
        d.point((ox + rng.randrange(w), oy + rng.randrange(h)), fill=rng.choice(colors))


# ---------------------------------------------------------------- palette
GRASS = (106, 170, 72)
GRASS_D = (82, 142, 58)
GRASS_L = (138, 194, 92)
DIRT = (196, 160, 108)
DIRT_D = (168, 130, 86)
DIRT_L = (214, 184, 132)
WATER = (64, 140, 200)
WATER_D = (46, 110, 172)
WATER_L = (128, 194, 232)
TILLED = (124, 82, 50)
TILLED_D = (96, 62, 38)
WET = (78, 50, 32)
WET_D = (58, 36, 22)
FARMLAND = (150, 112, 72)
FARMLAND_D = (128, 94, 58)
TRUNK = (112, 74, 42)
TRUNK_D = (84, 54, 30)
LEAF = (60, 136, 66)
LEAF_D = (38, 98, 50)
LEAF_L = (96, 170, 82)
WOOD = (176, 124, 72)
WOOD_D = (124, 84, 48)
WOOD_L = (206, 156, 98)
STONE = (140, 140, 148)
STONE_D = (104, 104, 114)
STONE_L = (180, 180, 188)
OUTLINE = (44, 30, 24)


# ---------------------------------------------------------------- tileset
def grass_base(d, ox):
    rect(d, ox, 0, ox + 15, 15, GRASS)
    speckle(d, ox, 0, [GRASS_D, GRASS_L], 22)


def tileset():
    img = new(T * 12, T)
    d = ImageDraw.Draw(img)
    # 0 herbe
    grass_base(d, 0)
    # 1 herbe fleurie
    grass_base(d, 16)
    for (x, y, c) in [(3, 4, (240, 220, 90)), (11, 9, (236, 120, 150)), (6, 12, (250, 250, 250))]:
        d.point((16 + x, y), fill=c)
        d.point((16 + x - 1, y), fill=(250, 250, 230))
        d.point((16 + x, y + 1), fill=GRASS_D)
    # 2 touffe d'herbe
    grass_base(d, 32)
    for x in (5, 7, 9):
        rect(d, 32 + x, 7, 32 + x, 10, GRASS_D)
        d.point((32 + x, 6), fill=GRASS_L)
    # 3 chemin de terre
    rect(d, 48, 0, 63, 15, DIRT)
    speckle(d, 48, 0, [DIRT_D, DIRT_L], 26)
    # 4 eau
    rect(d, 64, 0, 79, 15, WATER)
    speckle(d, 64, 0, [WATER_D], 12)
    for (x, y) in [(2, 3), (9, 7), (4, 12)]:
        rect(d, 64 + x, y, 64 + x + 3, y, WATER_L)
    # 5 terre labourée
    rect(d, 80, 0, 95, 15, TILLED)
    for y in (2, 6, 10, 14):
        rect(d, 81, y, 94, y, TILLED_D)
    speckle(d, 80, 0, [(140, 96, 60)], 10)
    # 6 terre arrosée
    rect(d, 96, 0, 111, 15, WET)
    for y in (2, 6, 10, 14):
        rect(d, 97, y, 110, y, WET_D)
    speckle(d, 96, 0, [(92, 62, 40)], 10)
    # 7 terre cultivable (non labourée)
    rect(d, 112, 0, 127, 15, FARMLAND)
    speckle(d, 112, 0, [FARMLAND_D, DIRT], 30)
    # 8 arbre (sur herbe)
    grass_base(d, 128)
    rect(d, 128 + 6, 10, 128 + 9, 15, TRUNK)
    rect(d, 128 + 6, 10, 128 + 6, 15, TRUNK_D)
    d.ellipse([128 + 1, 0, 128 + 14, 12], fill=LEAF_D)
    d.ellipse([128 + 2, 0, 128 + 13, 10], fill=LEAF)
    speckle(d, 128 + 3, 1, [LEAF_L, LEAF_D], 14, 9, 8)
    # 9 clôture (sur herbe)
    grass_base(d, 144)
    rect(d, 144, 5, 159, 6, WOOD)
    rect(d, 144, 10, 159, 11, WOOD)
    for x in (2, 12):
        rect(d, 144 + x, 2, 144 + x + 2, 14, WOOD)
        rect(d, 144 + x, 2, 144 + x, 14, WOOD_L)
        rect(d, 144 + x + 2, 2, 144 + x + 2, 14, WOOD_D)
    # 10 rocher (sur herbe)
    grass_base(d, 160)
    d.ellipse([160 + 2, 4, 160 + 13, 14], fill=STONE_D)
    d.ellipse([160 + 2, 3, 160 + 12, 12], fill=STONE)
    rect(d, 160 + 5, 5, 160 + 7, 6, STONE_L)
    # 11 buisson (sur herbe)
    grass_base(d, 176)
    d.ellipse([176 + 1, 3, 176 + 14, 15], fill=LEAF_D)
    d.ellipse([176 + 2, 3, 176 + 13, 13], fill=LEAF)
    for (x, y) in [(5, 6), (9, 8), (7, 10)]:
        d.point((176 + x, y), fill=(220, 60, 70))
    img.save(os.path.join(OUT, "tileset.png"))


# ---------------------------------------------------------------- cultures
CROPS = [
    # (couleur du légume, couleur feuille, forme)
    ((220, 70, 90), (90, 170, 70), "radish"),
    ((150, 200, 110), (110, 176, 80), "cabbage"),
    ((228, 60, 48), (70, 150, 60), "tomato"),
    ((236, 140, 40), (80, 150, 60), "pumpkin"),
]


def crops():
    img = new(T * 5, T * 4)
    d = ImageDraw.Draw(img)
    for row, (veg, leaf, kind) in enumerate(CROPS):
        oy = row * T
        leaf_d = tuple(max(0, c - 40) for c in leaf)
        # stade 0 : graines
        for (x, y) in [(5, 11), (8, 12), (10, 10), (7, 9)]:
            d.point((x, oy + y), fill=(230, 210, 150))
        # stade 1 : pousse
        ox = T
        rect(d, ox + 7, oy + 9, ox + 7, oy + 13, leaf_d)
        d.point((ox + 6, oy + 9), fill=leaf)
        d.point((ox + 8, oy + 8), fill=leaf)
        # stade 2 : jeune plant
        ox = 2 * T
        rect(d, ox + 7, oy + 7, ox + 8, oy + 13, leaf_d)
        d.ellipse([ox + 3, oy + 6, ox + 7, oy + 9], fill=leaf)
        d.ellipse([ox + 8, oy + 5, ox + 12, oy + 8], fill=leaf)
        # stade 3 : plant développé
        ox = 3 * T
        rect(d, ox + 7, oy + 4, ox + 8, oy + 13, leaf_d)
        d.ellipse([ox + 2, oy + 4, ox + 7, oy + 9], fill=leaf)
        d.ellipse([ox + 8, oy + 3, ox + 13, oy + 8], fill=leaf)
        d.ellipse([ox + 4, oy + 8, ox + 11, oy + 13], fill=leaf_d)
        # stade 4 : mûr
        ox = 4 * T
        if kind == "radish":
            d.ellipse([ox + 4, oy + 1, ox + 7, oy + 6], fill=leaf)
            d.ellipse([ox + 8, oy + 1, ox + 11, oy + 6], fill=leaf)
            d.ellipse([ox + 4, oy + 6, ox + 11, oy + 13], fill=veg)
            d.point((ox + 6, oy + 8), fill=(250, 190, 200))
        elif kind == "cabbage":
            d.ellipse([ox + 1, oy + 4, ox + 14, oy + 15], fill=leaf_d)
            d.ellipse([ox + 3, oy + 5, ox + 12, oy + 13], fill=veg)
            rect(d, ox + 7, oy + 6, ox + 8, oy + 12, leaf)
        elif kind == "tomato":
            rect(d, ox + 7, oy + 1, ox + 8, oy + 14, leaf_d)
            d.ellipse([ox + 2, oy + 2, ox + 13, oy + 12], fill=leaf)
            for (x, y) in [(3, 5), (9, 3), (6, 9), (10, 9)]:
                d.ellipse([ox + x, oy + y, ox + x + 3, oy + y + 3], fill=veg)
                d.point((ox + x + 1, oy + y + 1), fill=(255, 160, 150))
        else:  # pumpkin
            d.ellipse([ox + 1, oy + 1, ox + 6, oy + 5], fill=leaf)
            d.ellipse([ox + 2, oy + 5, ox + 13, oy + 14], fill=veg)
            rect(d, ox + 7, oy + 4, ox + 8, oy + 6, (110, 80, 40))
            rect(d, ox + 5, oy + 6, ox + 5, oy + 13, (210, 110, 30))
            rect(d, ox + 10, oy + 6, ox + 10, oy + 13, (210, 110, 30))
    img.save(os.path.join(OUT, "crops.png"))


# ---------------------------------------------------------------- icônes
def icons():
    img = new(T * 10, T)
    d = ImageDraw.Draw(img)
    # 0 houe
    ox = 0
    for i in range(10):
        d.point((ox + 3 + i, 13 - i), fill=WOOD)
        d.point((ox + 4 + i, 13 - i), fill=WOOD_D)
    rect(d, ox + 10, 2, ox + 14, 4, STONE)
    rect(d, ox + 12, 4, ox + 14, 7, STONE_D)
    # 1 arrosoir
    ox = 16
    rect(d, ox + 3, 6, ox + 10, 13, (110, 150, 190))
    rect(d, ox + 3, 6, ox + 4, 13, (150, 190, 220))
    rect(d, ox + 10, 7, ox + 14, 8, (90, 130, 170))
    rect(d, ox + 14, 5, ox + 15, 7, (90, 130, 170))
    d.arc([ox + 4, 2, ox + 9, 9], 180, 360, fill=(80, 110, 150))
    # 2..5 sachets de graines
    for i, (veg, _leaf, _k) in enumerate(CROPS):
        ox = 32 + i * 16
        rect(d, ox + 3, 3, ox + 12, 14, (230, 210, 160))
        rect(d, ox + 3, 3, ox + 12, 4, (200, 176, 120))
        d.ellipse([ox + 5, 6, ox + 10, 11], fill=veg)
        rect(d, ox + 3, 14, ox + 12, 14, (180, 150, 100))
    # 6..9 légumes
    sheet = Image.open(os.path.join(OUT, "crops.png"))
    for i in range(4):
        tile = sheet.crop((4 * T, i * T, 5 * T, (i + 1) * T))
        img.alpha_composite(tile, (96 + i * 16, 0))
    img.save(os.path.join(OUT, "icons.png"))


# ---------------------------------------------------------------- joueur
SKIN = (240, 196, 160)
HAIR = (120, 70, 40)
SHIRT = (70, 140, 170)
SHIRT_D = (50, 110, 140)
PANTS = (90, 70, 60)
SHOES = (50, 36, 30)


def draw_player(d, ox, oy, direction, frame):
    """direction : 0 bas, 1 gauche, 2 droite (miroir), 3 haut."""
    lift_l = 1 if frame == 1 else 0
    lift_r = 1 if frame == 3 else 0
    # jambes
    rect(d, ox + 5, oy + 18 - lift_l, ox + 7, oy + 22 - lift_l, PANTS)
    rect(d, ox + 8, oy + 18 - lift_r, ox + 10, oy + 22 - lift_r, PANTS)
    rect(d, ox + 5, oy + 23 - lift_l, ox + 7, oy + 23 - lift_l, SHOES)
    rect(d, ox + 8, oy + 23 - lift_r, ox + 10, oy + 23 - lift_r, SHOES)
    # torse
    rect(d, ox + 4, oy + 11, ox + 11, oy + 18, SHIRT)
    rect(d, ox + 4, oy + 17, ox + 11, oy + 18, SHIRT_D)
    # bras
    swing = (frame in (1, 3))
    if direction in (0, 3):
        rect(d, ox + 3, oy + 12, ox + 3, oy + 16, SHIRT_D)
        rect(d, ox + 12, oy + 12, ox + 12, oy + 16, SHIRT_D)
        d.point((ox + 3, oy + 17), fill=SKIN)
        d.point((ox + 12, oy + 17), fill=SKIN)
    else:
        a = 1 if swing else 0
        rect(d, ox + 7, oy + 12, ox + 8, oy + 16 + a, SHIRT_D)
        rect(d, ox + 7, oy + 17 + a, ox + 8, oy + 17 + a, SKIN)
    # tête
    rect(d, ox + 4, oy + 3, ox + 11, oy + 10, SKIN)
    rect(d, ox + 4, oy + 2, ox + 11, oy + 4, HAIR)
    rect(d, ox + 5, oy + 1, ox + 10, oy + 1, HAIR)
    if direction == 0:
        rect(d, ox + 4, oy + 5, ox + 4, oy + 7, HAIR)
        rect(d, ox + 11, oy + 5, ox + 11, oy + 7, HAIR)
        d.point((ox + 6, oy + 7), fill=OUTLINE)
        d.point((ox + 9, oy + 7), fill=OUTLINE)
        d.point((ox + 5, oy + 9), fill=(236, 160, 150))
        d.point((ox + 10, oy + 9), fill=(236, 160, 150))
    elif direction == 3:
        rect(d, ox + 4, oy + 3, ox + 11, oy + 10, HAIR)
    else:  # profil gauche
        rect(d, ox + 8, oy + 3, ox + 11, oy + 9, HAIR)
        d.point((ox + 5, oy + 7), fill=OUTLINE)
        d.point((ox + 4, oy + 9), fill=(236, 160, 150))


def player():
    fw, fh = 16, 24
    img = new(fw * 4, fh * 4)
    d = ImageDraw.Draw(img)
    for frame in range(4):
        draw_player(d, frame * fw, 0, 0, frame)
        draw_player(d, frame * fw, fh, 1, frame)
        draw_player(d, frame * fw, 3 * fh, 3, frame)
    # droite = miroir de gauche
    for frame in range(4):
        left = img.crop((frame * fw, fh, (frame + 1) * fw, 2 * fh))
        img.alpha_composite(left.transpose(Image.FLIP_LEFT_RIGHT), (frame * fw, 2 * fh))
    img.save(os.path.join(OUT, "player.png"))


# ---------------------------------------------------------------- bâtiments
def house():
    img = new(64, 48)
    d = ImageDraw.Draw(img)
    # murs
    rect(d, 4, 20, 59, 47, (226, 204, 168))
    for y in range(22, 47, 4):
        rect(d, 4, y, 59, y, (204, 180, 144))
    # toit
    roof = (178, 72, 58)
    roof_d = (140, 52, 44)
    d.polygon([(0, 22), (32, 2), (63, 22)], fill=roof)
    for i in range(0, 20, 4):
        d.line([(32 - i * 1.6, 2 + i), (32 + i * 1.6, 2 + i)], fill=roof_d)
    rect(d, 0, 21, 63, 23, roof_d)
    # cheminée
    rect(d, 44, 4, 49, 12, (150, 110, 100))
    # porte (tuile x=1 → pixels 16..31)
    rect(d, 19, 30, 28, 47, WOOD_D)
    rect(d, 20, 31, 27, 47, WOOD)
    d.point((26, 39), fill=(240, 210, 90))
    # fenêtre
    rect(d, 38, 28, 52, 39, WOOD_D)
    rect(d, 39, 29, 51, 38, (150, 200, 230))
    rect(d, 45, 29, 45, 38, WOOD_D)
    rect(d, 39, 33, 51, 33, WOOD_D)
    img.save(os.path.join(OUT, "house.png"))


def shipping_bin():
    img = new(16, 16)
    d = ImageDraw.Draw(img)
    rect(d, 1, 5, 14, 15, WOOD_D)
    rect(d, 2, 6, 13, 14, WOOD)
    for y in (8, 11):
        rect(d, 2, y, 13, y, WOOD_D)
    rect(d, 0, 2, 15, 5, (150, 96, 56))
    rect(d, 0, 2, 15, 2, WOOD_L)
    rect(d, 6, 4, 9, 6, (220, 190, 80))
    img.save(os.path.join(OUT, "shipping_bin.png"))


def shop_stand():
    img = new(32, 32)
    d = ImageDraw.Draw(img)
    # poteaux
    rect(d, 2, 8, 3, 31, WOOD_D)
    rect(d, 28, 8, 29, 31, WOOD_D)
    # comptoir
    rect(d, 0, 20, 31, 31, WOOD)
    rect(d, 0, 20, 31, 21, WOOD_L)
    rect(d, 0, 31, 31, 31, WOOD_D)
    # cagettes
    for i, (veg, _l, _k) in enumerate(CROPS):
        x = 3 + i * 7
        rect(d, x, 16, x + 5, 19, WOOD_D)
        d.ellipse([x, 13, x + 5, 18], fill=veg)
    # auvent rayé
    for i in range(8):
        c = (232, 232, 220) if i % 2 == 0 else (90, 150, 90)
        rect(d, i * 4, 2, i * 4 + 3, 9, c)
    for i in range(8):
        d.point((i * 4 + 1, 10), fill=(90, 150, 90))
        d.point((i * 4 + 2, 10), fill=(90, 150, 90))
    img.save(os.path.join(OUT, "shop_stand.png"))


# ---------------------------------------------------------------- interface
def action_button():
    img = new(44, 44)
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, 43, 43], fill=(60, 40, 26, 200))
    d.ellipse([3, 3, 40, 40], fill=(214, 170, 96, 230))
    d.ellipse([3, 3, 40, 37], fill=(234, 196, 120, 230))
    # petite main / outil stylisé
    rect(d, 17, 12, 26, 30, (120, 80, 46, 255))
    rect(d, 13, 12, 30, 17, (120, 80, 46, 255))
    img.save(os.path.join(OUT, "action_button.png"))


def app_icon():
    img = Image.new("RGBA", (128, 128), GRASS + (255,))
    d = ImageDraw.Draw(img)
    rect(d, 16, 72, 111, 111, TILLED)
    for y in range(78, 111, 8):
        rect(d, 18, y, 109, y + 1, TILLED_D)
    rect(d, 61, 40, 66, 80, LEAF_D)
    d.ellipse([28, 26, 64, 52], fill=LEAF)
    d.ellipse([64, 18, 102, 46], fill=LEAF_L)
    img.save(os.path.join(ROOT, "icon.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    tileset()
    crops()
    icons()
    player()
    house()
    shipping_bin()
    shop_stand()
    action_button()
    app_icon()
    print("Assets générés dans", OUT)
