#!/usr/bin/env python3
"""Tenues des habitants : chaque habitant reçoit une texture Blocky (Kenney,
CC0) recolorée selon son métier, dans assets/kenney3d/blocky/Textures/npc/.
Les textures sont réduites à 512 px (4 fois moins de mémoire vidéo).

    python3 tools/build_npc_textures.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "kenney3d", "blocky", "Textures")
OUT = os.path.join(SRC, "npc")
SIZE = 512

# Zones de la texture (1024 px) : tête, buste, bras, jambes
HEAD = (0, 0, 512, 400)
EYES = (128, 175, 256, 256)  # bas du visage : yeux et bouche gardent leurs couleurs
BODY = (0, 400, 1024, 1024)
ALL = (0, 0, 1024, 1024)

# habitant : (texture de base, [(zone, couleur source, couleur voulue), ...])
LOOKS = {
    # L'épicière : chemisier vert de la boutique, cheveux auburn
    "rosalie": ("e", [(BODY, "a878e8", "4f9a5a"), (HEAD, "995a41", "8a3a26"), (BODY, "995a41", "8a3a26")]),
    # Le forgeron : tablier de cuir sombre, pantalon de travail gris
    "gaston": ("a", [(BODY, "b56544", "4a3a30"), (BODY, "37a177", "4a4a55"), (BODY, "1e835a", "34343e")]),
    # La jardinière : cheveux blancs, blouse jaune tournesol
    "odette": ("e", [(HEAD, "995a41", "e2ded6"), (BODY, "995a41", "e2ded6"), (BODY, "a878e8", "e0b844")]),
    # La peintre : tunique bleu ciel
    "lina": ("f", [(BODY, "58bd98", "4fa6dc"), (BODY, "8494c9", "c86a8a")]),
    # Le maire : costume et cravate
    "bertrand": ("q", []),
    # Le charpentier : chemise rouge de bûcheron et gilet
    "mathis": ("k", []),
    # La coopérative : salopette orange, pantalon brun
    "margot": ("f", [(BODY, "58bd98", "e08a3a"), (BODY, "8494c9", "6b5a3a")]),
    # L'éleveur : tenue de plein air
    "leon": ("m", []),
    # Le petit-fils d'Odette : sweat rouge
    "theo": ("b", []),
    # Le pêcheur : ciré jaune
    "jules": ("c", [(BODY, "44ae7d", "e6c23a")]),
    # Le tavernier : vieux loup de mer en vareuse bleue
    "marius": ("p", []),
    # La gardienne du phare : vareuse marine, cheveux noirs, peau hâlée
    "nina": ("e", [(BODY, "a878e8", "2e4a7a"), (HEAD, "995a41", "2d2a30"), (BODY, "995a41", "2d2a30"), (ALL, "f6d1a5", "c99067"), (ALL, "e79a76", "b07050")]),
    # Le marchand du port : veste ocre de négociant, lunettes
    "basile": ("i", [(BODY, "d0e8ff", "c8923f"), (BODY, "a0c0e0", "9a6c2c"), (BODY, "b7d4f6", "5a4a3a")]),
    # Tenues du joueur au choix (création du personnage)
    "player_1": ("a", [(BODY, "37a177", "3f5fa8"), (BODY, "1e835a", "2d4680"), (BODY, "b56544", "7a4a2a")]),
    "player_2": ("e", [(BODY, "a878e8", "d9a43a"), (HEAD, "995a41", "3a2a22"), (BODY, "995a41", "3a2a22")]),
    "player_3": ("f", [(BODY, "58bd98", "c0453c"), (BODY, "8494c9", "3a3a4a")]),
    # La meunière (nouvelle venue) : cheveux caramel, blouse blanche farinée
    "pauline": ("e", [(HEAD, "995a41", "c48a4a"), (BODY, "995a41", "c48a4a"), (BODY, "a878e8", "f0ece0")]),
    # Les nouveaux venus des Hauts de Valfleur
    # Capucine (le Bocal) : cheveux roux, tablier vert d'eau
    "capucine": ("e", [(HEAD, "995a41", "c8643a"), (BODY, "995a41", "c8643a"), (BODY, "a878e8", "5fb8a8")]),
    # Hugo (Atelier Néo) : bleu de travail anthracite, pantalon noir
    "hugo": ("a", [(BODY, "b56544", "3a4250"), (BODY, "37a177", "2e2e36"), (BODY, "1e835a", "22222a")]),
    # Élise (Studio Lin) : tunique de lin écru, pantalon noir
    "elise": ("f", [(BODY, "58bd98", "e8dcc4"), (BODY, "8494c9", "2e2e36")]),
    # Sacha (prof de yoga) : sweat corail
    "sacha": ("c", [(BODY, "44ae7d", "e8826a")]),
    # Inès (galeriste) : cheveux noirs, veste noire
    "ines": ("e", [(HEAD, "995a41", "2d2a30"), (BODY, "995a41", "2d2a30"), (BODY, "a878e8", "34343e")]),
    # La musicienne : cheveux blonds, tunique violette de scène
    "celeste": ("e", [(HEAD, "995a41", "e6c060"), (BODY, "995a41", "e6c060"), (BODY, "a878e8", "8a3ab0")]),
}


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


def recolor(a, zone, src, dst, tol=40.0):
    """Remplace une couleur (et ses nuances) par une autre, ombres comprises."""
    x0, y0, x1, y1 = zone
    reg = a[y0:y1, x0:x1, :3]
    s, d = rgb(src), rgb(dst)
    # Nuances : même teinte, plus claire ou plus sombre (rapport de luminosité)
    lum = reg.mean(-1, keepdims=True) / max(1.0, s.mean())
    mask = np.linalg.norm(reg - s * lum, axis=-1) < tol
    mask &= np.abs(lum[..., 0] - 1.0) < 0.35
    if zone == HEAD:
        ex0, ey0, ex1, ey1 = EYES
        mask[ey0 - y0:ey1 - y0, ex0 - x0:ex1 - x0] = False
    reg[mask] = np.clip(d * lum[mask], 0, 255)


def main():
    os.makedirs(OUT, exist_ok=True)
    for npc, (base, changes) in LOOKS.items():
        img = Image.open(os.path.join(SRC, "texture-%s.png" % base)).convert("RGBA")
        a = np.array(img).astype(float)
        for zone, src, dst in changes:
            recolor(a, zone, src, dst)
        out = Image.fromarray(a.astype(np.uint8), "RGBA").resize((SIZE, SIZE), Image.NEAREST)
        out.save(os.path.join(OUT, npc + ".png"), optimize=True)
        print("tenue :", npc)


if __name__ == "__main__":
    main()
