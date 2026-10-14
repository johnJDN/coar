# Extras: fiber, sodium, caffeine, alcohol

John's call (2026-10-14): record four optional extras on an entry, for a future coach to read.
He chose alcohol in **drinks**, and **nothing outside the entry**: no day line, no Home card,
no timeline hint, no targets, no totals. Water was skipped.

## What

| Extra | Unit | Best source |
|---|---|---|
| Fiber | g | Labels, brand lookups; plain whole foods the model knows |
| Sodium | mg | Labels, brand lookups; plain whole foods |
| Caffeine | mg | Brand lookups and labels; a few well-known drinks |
| Alcohol | US standard drinks (14 g) | Label or menu; else a stated assumption |

## Rules

- **Absent, not zero.** An Entry stores nil for an Extra nobody recorded. Caffeine and
  alcohol of 0 are stored as nil (none is nothing to show); a recorded 0 fiber or sodium is a
  fact and stays.
- **Never guessed.** The models are told to give a number only where they can stand behind it
  (plain whole foods they know, or a published figure) and null for a restaurant, brand, or
  mixed dish they're unsure of. An alcohol estimate names the strength it assumed.
- **Scaled with the portion**, like the macros; a Meal sums what its lines recorded and keeps
  each line's in its breakdown; Undo and Save as food carry them.
- **Shown only on an Entry's page** (and a Describe line's page), only the ones held, each
  editable; a saved food's serving editor lists all four, optional. Typing an Extra on a line
  that matched a saved food makes it the user's own, as editing a macro does.
- **Counts only undercount.** Totals (for the coach) sum what was recorded.

## Data

Four optional Doubles on `Entry`, `EntryComponent`, and `Serving`: a CloudKit schema deploy
before the next TestFlight upload. Old entries stay blank. `Estimate` gains `extras`, read
leniently so a saved Describe draft and the estimate cache from an older build still load.

## AI

All three prompts (typed text, photo, brand lookup) and their strict schemas gain
`fiber_g`, `sodium_mg`, `caffeine_mg`, `alcohol_drinks` (number or null). Accuracy tested on
labelled foods and drinks: `.scratch/extras/accuracy-test.md`.

## Not now

Targets or totals for any Extra; showing them on the Food day, Home, or the timeline;
water; vitamins and minerals; the coach itself.
