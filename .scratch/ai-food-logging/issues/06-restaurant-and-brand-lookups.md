# 06: Restaurant and brand lookups

**What to build:** When the text model marks a line `needsLookup` (a restaurant chain, a brand,
a packaged product), Coar asks `perplexity/sonar`, which searches the web for the published
numbers. A good answer replaces the estimate and is labelled "Looked up". A failed lookup keeps
the text model's estimate, labelled "Estimated".

Spec: stories 17–18, "Estimating" step 4.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] The text model's schema and prompt define `needsLookup` (true only for named chains, brands, packaged products)
- [ ] Sonar request:
  - the prompt asks for the estimate JSON (no `response_format`: Sonar doesn't support it on OpenRouter);
  - cost logged
- [ ] Lenient parse: strip code fences and take the first `{…}` object; a failure keeps the estimate
- [ ] Sanity rules apply to the looked-up numbers as well
- [ ] The line shows "Checking…" through both requests; a stale reply from either is dropped
- [ ] Tests (pure): lenient parse (fenced, prose around it, no JSON), lookup fallback, routing only when `needsLookup`
- [ ] Check by hand: "Chipotle chicken burrito bowl with white rice, black beans, fajita veggies, salsa" and "Quest cookie dough bar" come back "Looked up" with plausible published numbers
