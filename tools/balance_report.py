#!/usr/bin/env python3
"""Rapport d'équilibrage : rentabilité des cultures (or par case et par jour
sur une saison de 28 jours), en tenant compte de la repousse.

    python3 tools/balance_report.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
crops = json.load(open(os.path.join(ROOT, "data", "crops.json")))
items = json.load(open(os.path.join(ROOT, "data", "items.json")))
SEASON = 28
NAMES = ["printemps", "été", "automne", "hiver"]


def season_profit(cid, c, start=1):
    """Or gagné par case en une saison, en replantant dès la récolte."""
    seed = next(k for k, v in items.items() if v.get("crop") == cid)
    buy = items[seed].get("buy", 0)
    sell = items[c["harvest"]]["sell"]
    grow = sum(c["stage_days"])
    regrow = c.get("regrow", 0)
    day = start
    gold = 0
    harvests = 0
    if regrow:
        gold -= buy
        day += grow
        while day <= SEASON:
            gold += sell
            harvests += 1
            day += regrow
    else:
        while day + grow <= SEASON:
            gold += sell - buy
            harvests += 1
            day += grow
    return gold, harvests, buy, sell, grow, regrow


rows = []
for cid, c in crops.items():
    gold, n, buy, sell, grow, regrow = season_profit(cid, c)
    rows.append((c["seasons"][0], gold / SEASON, cid, buy, sell, grow, regrow, n))
for season in range(4):
    print(f"--- {NAMES[season]} ---")
    for r in sorted([r for r in rows if season in crops[r[2]]["seasons"]], key=lambda r: -r[1]):
        _, per_day, cid, buy, sell, grow, regrow, n = r
        print(f"  {cid:12s} {per_day:6.1f} or/case/jour  graine {buy:4d}  vente {sell:4d}  pousse {grow:2d}j  repousse {regrow}  récoltes {n}")
