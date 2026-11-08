#!/usr/bin/env python3
"""Simulation d'économie : ce que rapporte une année de ferme, avec et sans
machines, et la valeur ajoutée par jour de chaque machine.

    python3 tools/economy_sim.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = lambda n: json.load(open(os.path.join(ROOT, "data", n)))
items, crops, machines = D("items.json"), D("crops.json"), D("machines.json")
SEASON = 28


def artisan(tpl, inp):
    t, i = items[tpl], items[inp]
    return round(i["sell"] * t.get("mult", 2) + t.get("add", 0)) if "from" in t else t["sell"]


def best_crop(season):
    best = (0, None)
    for cid, c in crops.items():
        if season not in c["seasons"]:
            continue
        seed = next(k for k, v in items.items() if v.get("crop") == cid)
        buy, sell = items[seed].get("buy", 0), items[c["harvest"]]["sell"]
        grow, regrow = sum(c["stage_days"]), c.get("regrow", 0)
        n = (1 + (SEASON - 1 - grow) // regrow) if regrow else (SEASON - 1) // grow
        gold = n * sell - (buy if regrow else n * buy)
        best = max(best, (gold, cid))
    return best


print("--- Valeur ajoutée par jour de machine ---")
for mid, m in machines["machines"].items():
    for cat, (tpl, days) in m["accepts"].items():
        inputs = [cat] if cat in items else [k for k, v in items.items()
                  if (cat == "fruit" and k in machines["fruits"]) or
                     (cat == "vegetable" and v.get("type") == "crop" and k not in machines["fruits"]) or
                     (cat == "fish" and v.get("type") == "fish")]
        gains = sorted(((artisan(tpl, i) - items[i]["sell"]) / days, i) for i in inputs)
        print("  %-14s %-10s %4.0f à %4.0f or/jour  (ex. %s)" % (mid, cat, gains[0][0], gains[-1][0], gains[-1][1]))

print("--- Une année type (champ qui s'agrandit, machines ajoutées peu à peu) ---")
total = 0
for season, (tiles, n_machines) in enumerate([(30, 0), (60, 2), (100, 4), (40, 6)]):
    gold, cid = best_crop(season)
    farm = gold * tiles
    mach = n_machines * 45 * SEASON  # ~45 or/jour par machine bien remplie
    total += farm + mach
    print("  saison %d : %-10s %3d cases -> %6d or, %d machines -> %6d or" % (season, cid, tiles, farm, n_machines, mach))
print("  total de l'année : %d or (hors pêche, élevage, quêtes)" % total)
