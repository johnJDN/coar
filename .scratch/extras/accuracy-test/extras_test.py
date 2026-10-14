"""Accuracy of the four Extras the app asks for, on lines with known values.

Usage: python3 extras_test.py extras-truth.json out.json
Mimics the app: the text model first (FoodEstimatePrompt); when it asks for a lookup,
Gemini 3.5 Flash-Lite reading an Exa search (FoodLookupPrompt); a lookup that finds nothing
leaves the text model's reading standing. Prompts are read from the Swift source.
"""
import json, os, re, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
KEY = open(os.path.expanduser("~/.config/coar/openrouter-key")).read().strip()
SRC = open(f"{ROOT}/Coar/Food/FoodEstimator.swift").read()


def swift_block(enum, name="system"):
    i = SRC.index(f"enum {enum}")
    m = re.search(rf'static let {name} = """\n(.*?)\n    """', SRC[i:], re.S)
    return "\n".join(l[4:] if l.startswith("    ") else l for l in m.group(1).split("\n"))


RULES = swift_block("FoodExtrasPrompt", "rules")
TEXT_PROMPT = swift_block("FoodEstimatePrompt").replace("\\(FoodExtrasPrompt.rules)", RULES)
LOOKUP_PROMPT = swift_block("FoodLookupPrompt")
NUM = {"type": ["number", "null"]}
EXTRAS_PROPS = {"fiber_g": NUM, "sodium_mg": NUM, "caffeine_mg": NUM, "alcohol_drinks": NUM}
EXTRAS_REQ = list(EXTRAS_PROPS)
TEXT_SCHEMA = {
    "type": "object", "additionalProperties": False,
    "required": ["is_food", "name", "quantity", "unit", "grams", "calories", "protein", "fat", "carbs", "needs_lookup", "assumption", "match"] + EXTRAS_REQ,
    "properties": {"is_food": {"type": "boolean"}, "name": {"type": "string"}, "quantity": {"type": "number"}, "unit": {"type": "string"},
                   "grams": NUM, "calories": {"type": "number"}, "protein": {"type": "number"}, "fat": {"type": "number"}, "carbs": {"type": "number"},
                   "needs_lookup": {"type": "boolean"}, "assumption": {"type": "string"}, "match": {"type": "null"}, **EXTRAS_PROPS},
}
LOOKUP_SCHEMA = {
    "type": "object", "additionalProperties": False,
    "required": ["is_food", "found", "product", "source_url", "name", "quantity", "unit", "grams", "calories", "protein", "fat", "carbs", "assumption"] + EXTRAS_REQ,
    "properties": {"is_food": {"type": "boolean"}, "found": {"type": "boolean"}, "product": {"type": "string"}, "source_url": {"type": "string"},
                   "name": {"type": "string"}, "quantity": {"type": "number"}, "unit": {"type": "string"}, "grams": NUM, "calories": NUM,
                   "protein": NUM, "fat": NUM, "carbs": NUM, "assumption": {"type": "string"}, **EXTRAS_PROPS},
}
MODEL = "google/gemini-3.5-flash-lite"


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
    try:
        return json.loads(r["choices"][0]["message"]["content"]), cost, None
    except Exception as e:
        return None, cost, repr(e)


def normalise(x):
    out = {"fiber": x.get("fiber_g"), "sodium": x.get("sodium_mg"), "caffeine": x.get("caffeine_mg"), "alcohol": x.get("alcohol_drinks")}
    for k in ("caffeine", "alcohol"):
        if out[k] == 0:
            out[k] = None
    return out


def run(item):
    text, c1, e1 = call(TEXT_PROMPT, item["line"], TEXT_SCHEMA)
    result = {"line": item["line"], "kind": item["kind"], "text_reply": text, "cost": c1, "error": e1, "path": "text"}
    final = normalise(text) if text else {k: None for k in ("fiber", "sodium", "caffeine", "alcohol")}
    if text and text.get("needs_lookup"):
        look, c2, e2 = call(LOOKUP_PROMPT, item["line"], LOOKUP_SCHEMA, web=True)
        result["cost"] += c2
        result["lookup_reply"] = look
        result["lookup_error"] = e2
        nums = [look.get(k) for k in ("calories", "protein", "fat", "carbs")] if look else []
        complete = look and look.get("found") and look.get("is_food", True) and all(isinstance(n, (int, float)) for n in nums)
        if complete:
            final = normalise(look)
            result["path"] = "lookup"
        else:
            result["path"] = "text (lookup found nothing)"
            # The app's rule: a brand food nobody found a label for keeps caffeine and
            # alcohol (estimates with a stated assumption) but not guessed fiber or sodium.
            final = dict(final, fiber=None, sodium=None)
    result["final"] = final
    return result


TOL = {"fiber": (1.0, 0.20), "sodium": (30.0, 0.15), "caffeine": (10.0, 0.15), "alcohol": (0.15, 0.0)}


def grade(truth, got, extra):
    t = truth.get(extra)
    if t is None:
        return "unverifiable" if got is not None else "n/a"   # brand didn't publish it
    if t == 0 and extra in ("caffeine", "alcohol"):
        return "right" if got is None else "wrong"            # none: nothing recorded
    if got is None:
        return "missing"
    absolute, relative = TOL[extra]
    return "right" if abs(got - t) <= max(absolute, relative * t) else "wrong"


if __name__ == "__main__":
    truth = json.load(open(sys.argv[1]))
    with ThreadPoolExecutor(6) as pool:
        results = list(pool.map(run, truth))
    for r, t in zip(results, truth):
        r["grades"] = {e: grade(t, r["final"].get(e), e) for e in TOL}
        r["truth"] = {e: t.get(e) for e in TOL}
    json.dump(results, open(sys.argv[2], "w"), indent=1)
    print("done", len(results), "spend $%.3f" % sum(r["cost"] for r in results))
