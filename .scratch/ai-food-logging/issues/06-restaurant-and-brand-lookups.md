# 06: Restaurant and brand lookups

**What to build:** When the text model marks a line `needsLookup` (a restaurant chain, a brand,
a packaged product), Coar asks `perplexity/sonar`, which searches the web for the published
numbers. A good answer replaces the estimate and is labelled "Looked up". A failed lookup keeps
the text model's estimate, labelled "Estimated".

Spec: stories 17–18, "Estimating" step 4.

**Blocked by:** 02

**Status:** done

- [x] The text model's schema and prompt define `needsLookup` (true only for named chains, brands, packaged products)
- [x] Sonar request:
  - the prompt asks for the estimate JSON (no `response_format`: Sonar doesn't support it on OpenRouter);
  - cost logged
- [x] Lenient parse: strip code fences and take the first `{…}` object; a failure keeps the estimate
- [x] Sanity rules apply to the looked-up numbers as well
- [x] The line shows "Checking…" through both requests; a stale reply from either is dropped
- [x] Tests (pure): lenient parse (fenced, prose around it, no JSON), lookup fallback, routing only when `needsLookup`
- [x] Check by hand: "Chipotle chicken burrito bowl with white rice, black beans, fajita veggies, salsa" and "Quest cookie dough bar" come back "Looked up" with plausible published numbers

## Comments

- 2026-09-27 (agent): Implemented.
  - **Models and prompt.** `FoodModels.lookup` = `perplexity/sonar`. `FoodLookupPrompt`
    shows the reply as a filled-in JSON template, since Sonar can't be held to a schema on
    OpenRouter. The first wording listed the keys in prose, and Sonar invented key names
    ("calories (kcal)").
  - **Reading the reply.** `FoodLookupPrompt.object(in:)` takes the first balanced `{…}`
    (strings and escapes respected, so braces inside the assumption don't cut it short) out
    of any prose or code fence. It drops a `match` key, because Sonar sometimes fills it
    with a string.
  - **Routing.** In `OpenRouterFoodEstimator`, a resolved catalogue match wins. Otherwise
    `needs_lookup` sends the line to Sonar (25 s timeout), and the result is "Looked up".
    A failed request, a reply with no JSON, or impossible numbers keeps the text model's
    estimate ("Estimated"), with the reason logged. Both requests happen under one
    "Checking…".
  - **Tests:** `FoodLookupTests` (6): JSON inside prose and fences with braces in strings,
    no object, an everyday food never looked up, a chain food looked up and labelled, a
    failed, unreadable or impossible lookup keeping the estimate, and a saved food not
    looked up. The transport is stubbed per model. Suite green at 309.
  - **Real models, from the Mac.**
    - Flash-Lite flags "Quest cookie dough bar", "big mac and medium fries" and "starbucks
      grande oat milk latte", and not "homemade chili" or "banana".
    - Sonar returned the published numbers: Quest bar 190 kcal / 21 g protein; Big Mac +
      medium fries 900 kcal, itemised in the assumption; Starbucks grande oat latte 190
      kcal.
    - Each lookup took about 1.7 s and cost about $0.0053.
  - **Not checked in the simulator:** there's no key there, and the fake estimator doesn't
    route. John sees it on the phone.
  - Left as deliberate:
    - the lookup's own `needs_lookup` is ignored (never looked up twice);
    - Sonar's citations aren't shown;
    - a lookup can't match a saved food, since its reply is only ever an estimate.

- 2026-10-03 (agent): Bug from John: "kind protein bar strawberry cocoa" showed 0 kcal, P 0,
  F 0, C 0, "Looked up". The text model estimated it well (220 kcal) and asked for a lookup;
  Sonar found no strawberry cocoa KIND bar and sent the prompt's template back with every
  number 0, which passed the impossibility check and replaced the estimate. Sonar does the
  same for macros it can't find ("big mac": 580 kcal, P/F/C 0). Fix: a lookup is dropped,
  keeping the estimate, when every number is 0 for a food the estimate gave 10+ kcal (a diet
  drink at 0 still looks up), or when it has 10+ kcal with protein, fat, and carbs all 0.
  Tried and reverted: a template of nulls with "leave them null if not found". Sonar then
  left numbers null for foods it did find (Big Mac, Quest), so far fewer lookups survived.
  Not used: the calories-disagree check, which a real Quest bar fails (fiber, sugar alcohols).
  The bad answer was also in the line cache, so retyping the line gave the 0s back. The cache
  now skips, and never stores, a lookup with protein, fat, and carbs all 0
  (`Estimate.isLookupWithoutMacros`); a diet drink is just asked again each time.
- 2026-10-04 (agent): Lookup model switched from `perplexity/sonar` to
  `google/gemini-3.5-flash-lite` reading an Exa web search, with a strict schema that adds
  `found`, `product`, and `source_url` (`.scratch/ai-food-logging/lookup-test.md`: 11 setups
  compared on 15 verified labels). The lenient JSON-in-prose reader is gone. Sources in the
  note, which the model writes as Markdown links, are kept as plain text. The 0s guards stay.
  The client logs Google's own charge for BYOK requests, which OpenRouter reports as $0.
