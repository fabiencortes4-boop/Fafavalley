#!/usr/bin/env python3
"""Pavés du village et du port (créations originales, CC0) :

- assets/sprites/paving_road.png : 4 variantes de pavés (64x64 chacune,
  raccordables), pour les routes ;
- assets/sprites/paving_plaza.png : le dallage de la place de Valfleur, en
  rosace autour de la fontaine (32 px par case).

    python3 tools/build_paving.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")
rng = np.random.default_rng(11)

# Place : cases (24, 22) à (37, 31), fontaine centrée en (31, 27)
PLAZA = (24, 22, 14, 10)
FOUNTAIN = (31.0, 27.0)
PX = 32  # pixels par case pour la place

STONE = np.array([(0.70, 0.66, 0.60), (0.64, 0.60, 0.55), (0.74, 0.70, 0.63), (0.60, 0.57, 0.53), (0.68, 0.62, 0.54)])
MORTAR = np.array([0.42, 0.38, 0.33])


def shade(base, edge_dist, width):
    """Pierre bombée : bords plus sombres, centre éclairé, joint de mortier."""
    t = np.clip(edge_dist / width, 0, 1)
    col = base * (0.82 + 0.22 * np.sqrt(t))[..., None]
    mortar = edge_dist < 1.2
    col[mortar] = MORTAR
    return col


def road_tile(seed):
    r = np.random.default_rng(seed)
    n = 64
    y, x = np.mgrid[0:n, 0:n].astype(float)
    rows = 4
    h = n / rows
    row = np.floor(y / h).astype(int)
    off = np.where(row % 2 == 1, h * 0.75, 0.0)  # pavés décalés d'une rangée à l'autre
    w = n / 3.0
    xx = (x + off) % n
    col_i = np.floor(xx / w).astype(int)
    lx = xx - col_i * w
    ly = y - row * h
    edge = np.minimum(np.minimum(lx, w - lx), np.minimum(ly, h - ly))
    tones = STONE[r.integers(0, len(STONE), (rows, 4))]
    base = tones[row % rows, col_i % 3] * (1 + r.normal(0, 0.025, (n, n, 1)))
    img = shade(base, edge, 5.0)
    return (np.clip(img, 0, 1) * 255).astype(np.uint8)


def plaza():
    cw, ch = PLAZA[2] * PX, PLAZA[3] * PX
    y, x = np.mgrid[0:ch, 0:cw].astype(float)
    # Coordonnées en cases, centrées sur la fontaine
    gx = x / PX + PLAZA[0] - FOUNTAIN[0]
    gy = y / PX + PLAZA[1] - FOUNTAIN[1]
    r = np.hypot(gx, gy)
    th = np.arctan2(gy, gx) + np.pi
    ring_w = 0.42
    ring = np.floor(r / ring_w).astype(int)
    circ = 2 * np.pi * (ring + 0.5) * ring_w
    count = np.maximum(6, np.round(circ / 0.5)).astype(int)
    pos = th / (2 * np.pi) * count + (ring % 2) * 0.5
    idx = np.floor(pos).astype(int)
    lr = (r - ring * ring_w) * PX
    la = (pos - idx) * (circ / count) * PX
    edge_ring = np.minimum(np.minimum(lr, ring_w * PX - lr), np.minimum(la, (circ / count) * PX - la))
    seeds = (ring * 131 + idx * 17) % len(STONE)
    base_ring = STONE[seeds] * 1.04
    # Une couronne de pierres plus sombres tous les 4 anneaux
    dark = (ring % 4 == 3)[..., None]
    base_ring = np.where(dark, base_ring * 0.8, base_ring)
    ring_img = shade(base_ring, edge_ring, 5.0)
    # Au-delà de la rosace : grandes dalles claires
    sx, sy = gx * PX, gy * PX
    slab = 1.0 * PX
    ix = np.floor(sx / slab).astype(int)
    iy = np.floor(sy / slab).astype(int)
    lx = sx - ix * slab
    ly = sy - iy * slab
    edge_slab = np.minimum(np.minimum(lx, slab - lx), np.minimum(ly, slab - ly))
    tone = STONE[(ix * 7 + iy * 13) % len(STONE)] * 1.1
    slab_img = shade(tone, edge_slab, 6.0)
    radius = 4.6
    img = np.where((r < radius)[..., None], ring_img, slab_img)
    # Bordure de la rosace
    border = np.abs(r - radius) < 0.07
    img[border] = MORTAR * 1.1
    img = img * (1 + rng.normal(0, 0.02, img.shape[:2] + (1,)))
    return (np.clip(img, 0, 1) * 255).astype(np.uint8)


def main():
    tiles = [road_tile(s) for s in range(4)]
    Image.fromarray(np.concatenate(tiles, axis=1), "RGB").save(os.path.join(OUT, "paving_road.png"), optimize=True)
    Image.fromarray(plaza(), "RGB").save(os.path.join(OUT, "paving_plaza.png"), optimize=True)
    print("pavés : route et place")


if __name__ == "__main__":
    main()
