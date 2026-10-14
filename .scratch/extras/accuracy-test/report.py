"""Summarise extras_test.py output: python3 report.py extras-truth.json run1.json [run2.json ...]"""
import json, sys
from collections import Counter, defaultdict
truth = {t["line"]: t for t in json.load(open(sys.argv[1]))}
runs = [json.load(open(p)) for p in sys.argv[2:]]
tally = defaultdict(Counter)
for run in runs:
    for r in run:
        for extra, g in r["grades"].items():
            tally[extra][g] += 1
print("| Extra | Right | Wrong (a number that's off) | Missing (left blank) | Gave a number the brand doesn't publish |")
print("|---|---|---|---|---|")
for extra in ("fiber", "sodium", "caffeine", "alcohol"):
    c = tally[extra]
    print(f"| {extra} | {c['right']} | {c['wrong']} | {c['missing']} | {c['unverifiable']} |")
print()
print("| Line | Path | Fiber | Sodium | Caffeine | Alcohol |")
print("|---|---|---|---|---|---|")
for r in runs[0]:
    cells = []
    for e in ("fiber", "sodium", "caffeine", "alcohol"):
        t = r["truth"][e]; got = r["final"][e]; g = r["grades"][e]
        mark = {"right": "ok", "wrong": "WRONG", "missing": "blank", "unverifiable": "?", "n/a": "–"}[g]
        cells.append(f"{mark}: {'—' if got is None else round(got,1)} (truth {'—' if t is None else t})")
    print(f"| {r['line']} | {r['path']} | " + " | ".join(cells) + " |")
