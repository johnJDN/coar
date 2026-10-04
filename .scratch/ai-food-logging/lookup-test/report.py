"""Summarise lookup_test.py output: python3 report.py truth.json results.json [results2.json ...]"""
import json, statistics, sys
from collections import defaultdict

truth = {t["line"]: t for t in json.load(open(sys.argv[1]))}
runs = [json.load(open(p)) for p in sys.argv[2:]]
results = [r for run in runs for r in run["results"]]

by_model = defaultdict(list)
for r in results:
    by_model[r["model"]].append(r)

print("| Model | Right | Wrong numbers | Not found (keeps estimate) | Traps refused | Errors | Median time | ≈ $ per lookup |")
print("|---|---|---|---|---|---|---|---|")
for model, rs in by_model.items():
    real = [r for r in rs if truth[r["line"]]["kind"] != "trap"]
    traps = [r for r in rs if truth[r["line"]]["kind"] == "trap"]
    count = lambda g, xs: sum(1 for r in xs if r["grade"] == g)
    costs = [r["cost"] for r in rs if r["cost"] is not None]
    print(f"| {model} | {count('right', real)}/{len(real)} | {count('wrong numbers', real)} | {count('not found', real)} | "
          f"{count('right (not found)', traps)}/{len(traps)} | {sum(1 for r in rs if r['error'])} | "
          f"{statistics.median(r['seconds'] for r in rs):.1f} s | {statistics.mean(costs):.4f} |")

print()
models = list(by_model)
print("| Line | Label kcal / P / F / C | " + " | ".join(models) + " |")
print("|---|---|" + "---|" * len(models))
for line, t in truth.items():
    label = "trap" if t["kind"] == "trap" else f"{t['calories']} / {t['protein']} / {t['fat']} / {t['carbs']}"
    cells = []
    for m in models:
        rs = [r for r in by_model[m] if r["line"] == line]
        cell = []
        for r in rs:
            a = r["answer"]
            mark = {"right": "✓", "right (not found)": "✓ none", "not found": "–", "wrong numbers": "✗", "wrong (made up)": "✗ made up"}[r["grade"]]
            cell.append(mark if a is None else f"{mark} {a['calories']:g}/{a['protein']:g}/{a['fat']:g}/{a['carbs']:g}")
        cells.append("; ".join(cell))
    print(f"| {line} | {label} | " + " | ".join(cells) + " |")

usda = [u for run in runs for u in run.get("usda", [])]
if usda:
    print("\nUSDA Branded (best word match of top 10):")
    for u in usda:
        a = u.get("answer")
        numbers = "" if not a else "{:g}/{:g}/{:g}/{:g}".format(a["calories"], a["protein"], a["fat"], a["carbs"])
        print(f"- {u['line']}: {u['grade']} — {u.get('product')} {numbers}")
