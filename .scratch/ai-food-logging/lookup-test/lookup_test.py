"""Compare web-search lookup models on lines with known labels.

Usage: python3 lookup_test.py truth.json out.json [model ...]
"""
import json, os, re, sys, time, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor

ROOT = "/Users/johnnguyen/Developer/coar"
KEY = open(os.path.expanduser("~/.config/coar/openrouter-key")).read().strip()

src = open(f"{ROOT}/Coar/Food/FoodEstimator.swift").read()
i = src.index("enum FoodLookupPrompt")
m = re.search(r'static let system = """\n(.*?)\n    """', src[i:], re.S)
CURRENT_PROMPT = "\n".join(l[4:] if l.startswith("    ") else l for l in m.group(1).split("\n"))

STRICT_PROMPT = """You look up the published nutrition of one restaurant or packaged food that someone ate, described in a single line of a food log. Search the web for the brand's official nutrition information (the brand's or restaurant's own site first) and give the numbers for the whole portion described.

- found: true only if you found published nutrition for this exact product (same brand, same product, same flavor or variety). If you only found a similar product, or nothing, found is false and the numbers are null.
- product: the exact name of the product your numbers are for, as the source names it, or "" if not found.
- source_url: the page the numbers come from, or "".
- name: what the food is, short, with the brand.
- quantity and unit: the portion as the person counts it; the unit is singular ("bowl", "bar", "g").
- grams: the whole portion's weight if published, else null.
- calories in kcal; protein, fat and carbs in grams; null for any you did not find published.
- assumption: one short sentence naming where the numbers come from and anything assumed.
- is_food is false only if the line is not something eaten or drunk."""

STRICT_SCHEMA = {
    "type": "object", "additionalProperties": False,
    "required": ["is_food", "found", "product", "source_url", "name", "quantity", "unit", "grams", "calories", "protein", "fat", "carbs", "assumption"],
    "properties": {
        "is_food": {"type": "boolean"}, "found": {"type": "boolean"},
        "product": {"type": "string"}, "source_url": {"type": "string"},
        "name": {"type": "string"}, "quantity": {"type": "number"}, "unit": {"type": "string"},
        "grams": {"type": ["number", "null"]},
        "calories": {"type": ["number", "null"]}, "protein": {"type": ["number", "null"]},
        "fat": {"type": ["number", "null"]}, "carbs": {"type": ["number", "null"]},
        "assumption": {"type": "string"},
    },
}

# The strict prompt's fields, asked for as text, for a model that won't search under a schema.
FIELDS_PROMPT = STRICT_PROMPT + """

Reply with only this JSON object, filled in, and no other text:
{"is_food": true, "found": false, "product": "", "source_url": "", "name": "", "quantity": 1, "unit": "", "grams": null, "calories": null, "protein": null, "fat": null, "carbs": null, "assumption": ""}"""

# label -> (model, prompt style, web search engine: None (the model's own, Perplexity), "native", or "exa")
# Gemini decides for itself whether to Google, and with this prompt it never did; Exa always searches.
MODELS = {
    "sonar (now)": ("perplexity/sonar", "current", None),
    "sonar-pro-search": ("perplexity/sonar-pro-search", "strict", None),
    "gemini-3.5-flash-lite + Exa": ("google/gemini-3.5-flash-lite", "strict", "exa"),
    "gemini-3.8-flash + Exa": ("google/gemini-3.8-flash", "strict", "exa"),
    "gpt-6-luna + OpenAI search": ("openai/gpt-6-luna", "strict", "native"),
    "grok-4.3 + xAI search": ("x-ai/grok-4.3", "strict", "native"),
    "gemini-3.5-flash-lite, memory only": ("google/gemini-3.5-flash-lite", "strict", None),
    # Cheap search engines (2026-10-04): engine and mode.
    "gemini-3.5-flash-lite + Parallel fast": ("google/gemini-3.5-flash-lite", "strict", ("parallel", "fast")),
    "gemini-3.5-flash-lite + Parallel basic": ("google/gemini-3.5-flash-lite", "strict", ("parallel", "basic")),
    "gemini-3.5-flash-lite + Perplexity search": ("google/gemini-3.5-flash-lite", "strict", "perplexity"),
    "gpt-6-luna + Parallel fast": ("openai/gpt-6-luna", "strict", ("parallel", "fast")),
    "muse-spark-1.3 + Meta search": ("meta/muse-spark-1.3", "strict", "native"),
}
PROMPTS = {"current": CURRENT_PROMPT, "strict": STRICT_PROMPT, "fields": FIELDS_PROMPT}


def first_object(text):
    start = text.find("{")
    if start < 0:
        return None
    depth, in_str, esc = 0, False, False
    for j in range(start, len(text)):
        c = text[j]
        if esc:
            esc = False
        elif c == "\\":
            esc = in_str
        elif c == '"':
            in_str = not in_str
        elif not in_str and c == "{":
            depth += 1
        elif not in_str and c == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(text[start:j + 1])
                except Exception:
                    return None
    return None


def ask(label, line):
    model, style, web = MODELS[label]
    body = {
        "model": model,
        "messages": [{"role": "system", "content": PROMPTS[style]},
                     {"role": "user", "content": line}],
        "usage": {"include": True},
    }
    if style == "strict":
        body["response_format"] = {"type": "json_schema", "json_schema": {"name": "lookup", "strict": True, "schema": STRICT_SCHEMA}}
    if web:
        engine, mode = web if isinstance(web, tuple) else (web, None)
        body["plugins"] = [{"id": "web", "engine": engine, **({"mode": mode} if mode else {})}]
    req = urllib.request.Request("https://openrouter.ai/api/v1/chat/completions", data=json.dumps(body).encode(),
                                 headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    t = time.time()
    try:
        r = json.load(urllib.request.urlopen(req, timeout=90))
        message = r["choices"][0]["message"]
        content = message.get("content") or ""
        citations = [a.get("url_citation", {}).get("url") for a in message.get("annotations") or [] if a.get("type") == "url_citation"]
        err = None
    except urllib.error.HTTPError as e:
        r, content, citations, err = {}, "", [], f"HTTP {e.code}: {e.read()[:300].decode(errors='replace')}"
    except Exception as e:
        r, content, citations, err = {}, "", [], repr(e)
    return {
        "model": label, "line": line, "seconds": round(time.time() - t, 1), "error": err,
        "cost": ((r.get("usage") or {}).get("cost") or 0) + (((r.get("usage") or {}).get("cost_details") or {}).get("upstream_inference_cost") or 0) if (r.get("usage") or {}).get("is_byok") else (r.get("usage") or {}).get("cost"),
        "searches": ((r.get("usage") or {}).get("server_tool_use_details") or {}).get("web_search_requests"), "raw": content, "reply": first_object(content),
        "provider": r.get("provider"), "citations": citations + (r.get("citations") or []),
        "tokens": [(r.get("usage") or {}).get("prompt_tokens"), (r.get("usage") or {}).get("completion_tokens")],
    }


def coar_answer(result):
    """What Coar would show after this lookup: the numbers, or None (keeps its estimate)."""
    o = result["reply"]
    if not o or not o.get("is_food", True):
        return None
    if "found" in o and not o["found"]:
        return None
    nums = [o.get(k) for k in ("calories", "protein", "fat", "carbs")]
    if any(not isinstance(n, (int, float)) for n in nums) or any(n < 0 for n in nums):
        return None
    cal, p, f, c = nums
    if cal > 5000:
        return None
    if p == 0 and f == 0 and c == 0 and cal >= 10:  # the 2026-10-03 rule (partial)
        return None
    # all-zero: kept only when the estimate is also ~0; diet drinks are the only such line here
    return {"calories": cal, "protein": p, "fat": f, "carbs": c}


def close(got, want, floor):
    return abs(got - want) <= max(floor, 0.1 * want)


def grade(truth, answer):
    if truth["kind"] == "trap":
        return "right (not found)" if answer is None else "wrong (made up)"
    if answer is None:
        return "not found"
    ok = close(answer["calories"], truth["calories"], 10) and all(close(answer[k], truth[k], 2) for k in ("protein", "fat", "carbs"))
    return "right" if ok else "wrong numbers"


def usda(line):
    q = urllib.parse.urlencode({"api_key": "DEMO_KEY", "query": line, "dataType": "Branded", "pageSize": 10})
    try:
        r = json.load(urllib.request.urlopen(f"https://api.nal.usda.gov/fdc/v1/foods/search?{q}", timeout=30))
    except Exception as e:
        return {"error": repr(e)}
    if not r.get("foods"):
        return {"answer": None}
    # Simple matching: the result sharing the most words with the line.
    words = set(re.findall(r"[a-z]+", line.lower()))
    f = max(r["foods"], key=lambda f: len(words & set(re.findall(r"[a-z]+", f"{f.get('brandName','')} {f.get('description','')}".lower()))))
    n = {x["nutrientName"]: x.get("value") for x in f.get("foodNutrients", [])}
    size = f.get("servingSize")
    unit = (f.get("servingSizeUnit") or "").lower()
    scale = (size / 100) if size and unit in ("g", "grm", "ml", "mlt") else None  # Branded values are per 100 g/ml
    if scale is None:
        return {"answer": None, "product": f.get("description"), "note": "no serving size"}
    get = lambda name: round((n.get(name) or 0) * scale, 1)
    return {"product": f"{f.get('brandName') or f.get('brandOwner')} {f.get('description')}", "fdcId": f.get("fdcId"),
            "answer": {"calories": get("Energy"), "protein": get("Protein"), "fat": get("Total lipid (fat)"), "carbs": get("Carbohydrate, by difference")}}


if __name__ == "__main__":
    truth = json.load(open(sys.argv[1]))
    models = sys.argv[3:] or list(MODELS)
    jobs = [(m, t) for m in models for t in truth]
    with ThreadPoolExecutor(8) as pool:
        results = list(pool.map(lambda j: ask(j[0], j[1]["line"]), jobs))
    for r, (_, t) in zip(results, jobs):
        r["answer"] = coar_answer(r)
        r["grade"] = grade(t, r["answer"])
    usda_results = []
    for t in truth:
        if t["kind"] != "restaurant":
            u = usda(t["line"])
            u["line"] = t["line"]
            u["grade"] = grade(t, u.get("answer")) if "error" not in u else "error"
            usda_results.append(u)
            time.sleep(1)
    json.dump({"results": results, "usda": usda_results}, open(sys.argv[2], "w"), indent=1)
    print("done", len(results))
