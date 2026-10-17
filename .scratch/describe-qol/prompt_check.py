"""Live check of the typed-line prompt's size scaling and parts splitting.

Usage: python3 prompt_check.py out.json
Reads the prompt from the Swift source, sends each line with a small saved library, and
prints the match and the parts the model returns.
"""
import json, os, re, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = open(f"{ROOT}/Coar/Food/FoodEstimator.swift").read()
KEY = open(os.path.expanduser("~/.config/coar/openrouter-key")).read().strip()


def block(enum, name="system"):
    i = SRC.index(f"enum {enum}")
    m = re.search(rf'static let {name} = """\n(.*?)\n    """', SRC[i:], re.S)
    return "\n".join(l[4:] if l.startswith("    ") else l for l in m.group(1).split("\n"))


RULES = block("FoodExtrasPrompt", "rules")
SERVING_RULES = block("ServingSizePrompt", "rules")
SYSTEM = block("FoodEstimatePrompt").replace("\\(FoodExtrasPrompt.rules)", RULES).replace("\\(ServingSizePrompt.rules)", SERVING_RULES)
i = SRC.index("static func library(_ listing: String) -> String", SRC.index("enum FoodEstimatePrompt"))
LIB = re.search(r'"""\n(.*?)\n        """', SRC[i:], re.S).group(1)
LIB = "\n".join(l[8:] if l.startswith("        ") else l for l in LIB.split("\n"))
LISTING = 'f1 Pho: s1 "bowl"\nf2 Eggs: s1 "1 egg", s2 "100 g"\nf3 Fries: s1 "small", s2 "medium", s3 "large"\nf4 Iced latte: s1 "grande"'
NUM = {"type": ["number", "null"]}
SCHEMA = {"type": "object", "additionalProperties": False,
          "required": ["is_food", "name", "quantity", "unit", "grams", "calories", "protein", "fat", "carbs", "needs_lookup", "assumption", "match", "parts", "fiber_g", "sodium_mg", "caffeine_mg", "alcohol_drinks", "serving_name", "serving_grams", "piece_name"],
          "properties": {"is_food": {"type": "boolean"}, "parts": {"type": "array", "items": {"type": "string"}}, "name": {"type": "string"}, "quantity": {"type": "number"}, "unit": {"type": "string"},
                         "grams": NUM, "calories": {"type": "number"}, "protein": {"type": "number"}, "fat": {"type": "number"}, "carbs": {"type": "number"},
                         "needs_lookup": {"type": "boolean"}, "assumption": {"type": "string"},
                         "match": {"anyOf": [{"type": "null"}, {"type": "object", "additionalProperties": False, "required": ["food", "serving", "quantity"], "properties": {"food": {"type": "string"}, "serving": {"type": ["string", "null"]}, "quantity": {"type": "number"}}}]},
                         "fiber_g": NUM, "sodium_mg": NUM, "caffeine_mg": NUM, "alcohol_drinks": NUM, "serving_name": {"type": "string"}, "serving_grams": NUM, "piece_name": {"type": "string"}}}

# line -> what we expect: ("match", food, serving, quantity) or ("parts", n) or ("none",)
CASES = [
    ("pho", ("match", "f1", "s1", 1)), ("large pho", ("match", "f1", "s1", 1.5)), ("small pho", ("match", "f1", "s1", 0.75)),
    ("half a pho", ("match", "f1", "s1", 0.5)), ("2 large eggs", ("match", "f2", "s1", 2)), ("large fries", ("match", "f3", "s3", 1)),
    ("venti iced latte", ("match", "f4", "s1", 1.25)), ("pho with extra noodles", ("none",)),
    ("eggs, toast and coffee", ("parts", 3)), ("burger and fries", ("parts", 2)), ("2 eggs + bacon", ("parts", 2)),
    ("big mac and medium fries", ("parts", 2)), ("toast with butter", ("none",)), ("chicken burrito bowl", ("none",)),
    ("coffee with milk", ("none",)), ("rice and beans", ("parts", 2)), ("salt and pepper chicken wings", ("none",)),
]


def ask(line):
    body = {"model": "google/gemini-3.5-flash-lite", "temperature": 0,
            "messages": [{"role": "system", "content": SYSTEM + LIB.replace("\\(listing)", LISTING)}, {"role": "user", "content": line}],
            "response_format": {"type": "json_schema", "json_schema": {"name": "estimate", "strict": True, "schema": SCHEMA}},
            "provider": {"require_parameters": True}}
    req = urllib.request.Request("https://openrouter.ai/api/v1/chat/completions", data=json.dumps(body).encode(), headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    return json.loads(json.load(urllib.request.urlopen(req, timeout=60))["choices"][0]["message"]["content"])


with ThreadPoolExecutor(8) as pool:
    replies = list(pool.map(lambda c: ask(c[0]), CASES))
ok = 0
for (line, want), r in zip(CASES, replies):
    parts = r.get("parts") or []
    m = r.get("match")
    if want[0] == "parts":
        good = len(parts) == want[1]
    elif want[0] == "none":
        good = len(parts) < 2 and m is None
    else:
        good = len(parts) < 2 and m is not None and m["food"] == want[1] and (m["serving"] or "s1") == want[2] and abs(m["quantity"] - want[3]) <= 0.26
    ok += good
    print(f"{'ok ' if good else 'BAD'} {line:32} parts={parts} match={m}")
print(f"{ok}/{len(CASES)}")
json.dump([{"line": c[0], "expected": c[1], "reply": r} for c, r in zip(CASES, replies)], open(sys.argv[1], "w"), indent=1)
