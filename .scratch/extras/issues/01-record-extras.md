# 01: Record fiber, sodium, caffeine, and alcohol on an entry

**What to build:** The four Extras end to end per `../spec.md`: the data, the AI prompts and
schemas, scaling through foods, meals, Save as food and Undo, and the entry, line, and serving
pages.

**Status:** done

- [x] `Extras` / `Extra`; optional attributes on `Entry`, `EntryComponent`, `Serving`
- [x] Carried through logging (food item, meal, standalone, Save as food), editing, Undo, meals
- [x] `Estimate.extras` read leniently; text, photo, and lookup prompts and strict schemas
- [x] `ExtraRows` on the entry page, the Describe line page, and the serving editor
- [x] Tests (24): the value, the store, replies, old saved drafts and cache, the editors
- [x] CONTEXT.md, DESIGN.md, brief, spec
- [x] Accuracy test on labelled foods and drinks (`../accuracy-test.md`)

## Comments

- 2026-10-14 (agent): Implemented; tests 375 pass; the line and entry pages checked in the
  simulator with fake estimates (`-FakeFoodEstimates` now gives fiber and sodium, caffeine for
  "coffee", an alcohol drink for "beer"/"wine").
  Left as deliberate:
  - **Never guessed, and tested** (`../accuracy-test.md`): a brand food nobody found a label for
    keeps caffeine and alcohol but loses fiber and sodium, which the text model had guessed
    (Celsius sodium 150, label 5). Lookups that find the label are exact.
  - **Blanks over guesses:** a lookup that finds the product but not an Extra leaves it blank,
    though the text model usually knew it (4 of 5 right, one wrong), so it isn't used to fill.
  - **Rows show only for Extras held**, on the entry and a Describe line's page; to add one to
    an entry that has none, save it on the food's serving, or type it where the food already has
    one. Not added: an "add extra" menu.
  - **Zero caffeine or alcohol is nothing** (stored as blank); a zero fiber or sodium is kept.
  - **Old entries stay blank**; the next TestFlight build needs the CloudKit schema deployed.
  - **Estimate decoding is lenient** so an older saved Describe draft and the line cache still
    load.
  - Alcohol is stored in drinks (14 g) and shown in drinks; the grams are not kept.
