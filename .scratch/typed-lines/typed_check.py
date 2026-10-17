"""Live check of awkward typed lines (sharing, drink and chain customizations, saved food
with a change, cooking fat, vague amounts, time words, corrections, typos, one dish listed
with its ingredients).

Usage: python3 typed_check.py out.json [runs]
Mimics the app: the typed-line prompt with a small saved library, then the web lookup when
the model asks for one (a lookup that finds no complete label leaves the estimate). Prompts
are read from the Swift source. Each case has its own check of the final reply.
"""
import json, os, re, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = open(f"{ROOT}/Coar/Food/FoodEstimator.swift").read()
KEY = open(os.path.expanduser("~/.config/coar/openrouter-key")).read().strip()
MODEL = "google/gemini-3.5-flash-lite"


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
LOOKUP = block("FoodLookupPrompt").replace("\\(ServingSizePrompt.rules)", SERVING_RULES)
LISTING = 'f1 Pho: s1 "bowl"\nf2 Eggs: s1 "1 egg", s2 "100 g"\nf3 Fries: s1 "small", s2 "medium", s3 "large"\nf4 Iced latte: s1 "grande"\nf5 Usual smoothie: s1 "cup"'
NUM = {"type": ["number", "null"]}
EXTRAS = {"fiber_g": NUM, "sodium_mg": NUM, "caffeine_mg": NUM, "alcohol_drinks": NUM, "serving_name": {"type": "string"}, "serving_grams": NUM, "piece_name": {"type": "string"}}
TEXT_SCHEMA = {"type": "object", "additionalProperties": False,
               "required": ["is_food", "name", "quantity", "unit", "grams", "calories", "protein", "fat", "carbs", "needs_lookup", "assumption", "match", "parts"] + list(EXTRAS),
               "properties": {"is_food": {"type": "boolean"}, "parts": {"type": "array", "items": {"type": "string"}}, "name": {"type": "string"}, "quantity": {"type": "number"}, "unit": {"type": "string"},
                              "grams": NUM, "calories": {"type": "number"}, "protein": {"type": "number"}, "fat": {"type": "number"}, "carbs": {"type": "number"},
                              "needs_lookup": {"type": "boolean"}, "assumption": {"type": "string"},
                              "match": {"anyOf": [{"type": "null"}, {"type": "object", "additionalProperties": False, "required": ["food", "serving", "quantity"], "properties": {"food": {"type": "string"}, "serving": {"type": ["string", "null"]}, "quantity": {"type": "number"}}}]},
                              **EXTRAS}}
LOOKUP_SCHEMA = {"type": "object", "additionalProperties": False,
                 "required": ["is_food", "found", "product", "source_url", "name", "quantity", "unit", "grams", "calories", "protein", "fat", "carbs", "assumption"] + list(EXTRAS),
                 "properties": {"is_food": {"type": "boolean"}, "found": {"type": "boolean"}, "product": {"type": "string"}, "source_url": {"type": "string"},
                                "name": {"type": "string"}, "quantity": {"type": "number"}, "unit": {"type": "string"}, "grams": NUM, "calories": NUM,
                                "protein": NUM, "fat": NUM, "carbs": NUM, "assumption": {"type": "string"}, **EXTRAS}}


def call(system, line, schema, web=False):
    body = {"model": MODEL, "temperature": 0, "usage": {"include": True},
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": line}],
            "response_format": {"type": "json_schema", "json_schema": {"name": "x", "strict": True, "schema": schema}},
            "provider": {"require_parameters": True}}
    if web:
        body["plugins"] = [{"id": "web", "engine": "exa", "max_results": 5}]
    req = urllib.request.Request("https://openrouter.ai/api/v1/chat/completions", data=json.dumps(body).encode(),
                                 headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    try:
        r = json.load(urllib.request.urlopen(req, timeout=90))
    except Exception as e:
        return None, 0, repr(e)
    u = r.get("usage") or {}
    cost = (u.get("cost") or 0) + (((u.get("cost_details") or {}).get("upstream_inference_cost") or 0) if u.get("is_byok") else 0)
    return json.loads(r["choices"][0]["message"]["content"]), cost, None


def run(line):
    text, cost, err = call(SYSTEM + LIB.replace("\\(listing)", LISTING), line, TEXT_SCHEMA)
    out = {"line": line, "text": text, "error": err, "path": "text"}
    final = dict(text or {})
    if text and text.get("needs_lookup") and len(text.get("parts") or []) < 2 and not text.get("match"):
        look, c2, _ = call(LOOKUP, line + " nutrition facts", LOOKUP_SCHEMA, web=True)
        cost += c2
        out["lookup"] = look
        if look and look.get("found") and all(isinstance(look.get(k), (int, float)) for k in ("calories", "protein", "fat", "carbs")):
            final = dict(look, parts=[], match=None)
            out["path"] = "lookup"
    out["final"], out["cost"] = final, cost
    return out


MALA = "malatang bowl with tomato broth, 4 peeled shrimp, 3 fish ball with roe, 4 slices of marinated red beef, 4 slices of fatty beef, 5 pieces of chicken, a tiny bit of sweet potato noodle, 2 quail eggs, 2 tomatoes"

def one(r): return len(r.get("parts") or []) < 2
def cal(lo, hi): return lambda r: lo <= (r.get("calories") or 0) <= hi
def both(*fs): return lambda r: all(f(r) for f in fs)

# line -> (what's expected, check of the final reply)
CASES = [
    (MALA, "one line, 500-800", both(one, cal(500, 800))),
    (MALA + ", about 450 g before broth, drank a little of the broth", "one line, 580-760", both(one, cal(580, 760))),
    ("salad with grilled chicken, avocado and ranch", "one line", one),
    ("burrito with rice, beans and steak", "one line", one),
    ("split a large pepperoni pizza with 2 friends", "a third of a large: 600-1000", both(one, cal(600, 1000))),
    ("shared a large mcdonalds fries with my sister", "half a large: 180-320", both(one, cal(180, 320))),
    ("taro milk tea with boba", "baseline", lambda r: True),
    ("taro milk tea with boba, 25% sugar", "less than the baseline", None),
    ("starbucks venti iced latte with oat milk", "baseline", lambda r: True),
    ("starbucks venti iced latte with oat milk, 2 pumps vanilla", "baseline + 30-90", None),
    ("chipotle bowl, double chicken, no rice, extra guac", "protein >= 55, carbs <= 60", lambda r: (r.get("protein") or 0) >= 55 and (r.get("carbs") or 0) <= 60),
    ("pho but no noodles", "own estimate, not the saved bowl; < 400", both(one, lambda r: not r.get("match"), cal(100, 400))),
    ("my usual smoothie plus a banana", "two lines (smoothie, banana)", lambda r: len(r.get("parts") or []) == 2),
    ("2 eggs fried in butter", "190-280", cal(190, 280)),
    ("homemade fried rice, 1 cup", "220-380", cal(220, 380)),
    ("a few bites of cake", "60-250", cal(60, 250)),
    ("most of a chipotle chicken burrito", "600-1000", cal(600, 1000)),
    ("a handful of almonds", "120-220", cal(120, 220)),
    ("3 pork dumplings, actually 5", "5 dumplings: 200-400", cal(200, 400)),
    ("yesterday: tonkotsu ramen", "one line, food, 450-900", both(one, cal(450, 900))),
    ("breakfast: 2 eggs and toast", "two lines, no 'breakfast'", lambda r: len(r.get("parts") or []) == 2 and not any("breakfast" in p.lower() for p in r.get("parts") or [])),
    ("chikn breast 6oz grilled", "250-340", cal(250, 340)),
    ("tteokbokki", "250-650", cal(250, 650)),
    ("2 soju shots", "alcohol > 0", lambda r: (r.get("alcohol_drinks") or 0) > 0),
    ("eggs, toast and coffee", "three lines", lambda r: len(r.get("parts") or []) == 3),
    ("burger and fries", "two lines", lambda r: len(r.get("parts") or []) == 2),
    ("large pho", "matches Pho x1.5", lambda r: (r.get("match") or {}).get("food") == "f1" and abs(r["match"]["quantity"] - 1.5) < 0.3),
]

if __name__ == "__main__":
    runs = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    jobs = [c[0] for c in CASES for _ in range(runs)]
    with ThreadPoolExecutor(8) as pool:
        results = list(pool.map(run, jobs))
    by = {}
    for r in results:
        by.setdefault(r["line"], []).append(r)
    base = {}
    ok = total = 0
    for line, want, check in CASES:
        for r in by[line]:
            f = r["final"]
            if check is None:
                ref = by[line.rsplit(",", 1)[0]]
                ref_cal = sum((x["final"].get("calories") or 0) for x in ref) / len(ref)
                if "pumps" in line:
                    good = 30 <= (f.get("calories") or 0) - ref_cal <= 90
                else:
                    good = (f.get("calories") or 0) < ref_cal
            else:
                good = check(f)
            ok += good; total += 1
            m = f.get("match")
            print(f"{'ok ' if good else 'BAD'} {line[:60]:60} | {r['path']:6} | {f.get('calories')} cal P{f.get('protein')} F{f.get('fat')} C{f.get('carbs')} | q {f.get('quantity')} {f.get('unit')} | parts {len(f.get('parts') or [])} | match {m and m.get('food')}x{m and m.get('quantity')} | want: {want}")
    print(f"{ok}/{total}  spend ${sum(r['cost'] for r in results):.3f}")
    json.dump(results, open(sys.argv[1], "w"), indent=1)
