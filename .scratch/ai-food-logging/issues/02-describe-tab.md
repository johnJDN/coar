# 02: Describe tab: typed lines to Entries

**What to build:** The Food "+" sheet gets `SegmentedTabs` Describe / Foods / Meals, opening on
Describe.
- John types one food per line. Each line is estimated by the text model 2 s after its last
  edit, or at once on Return, and shows name, portion, calories, P/F/C and "Estimated".
- **Log** ("Log 3 · 740 kcal") logs every filled line as an Entry with no Food Item or Meal
  behind it, at the sheet's time, and removes those lines.
- Failed lines, impossible numbers and a missing, rejected or exhausted key are all visible
  errors.

The draft is in memory only here; ticket 03 keeps it on the iPhone. Spec: stories 1–4, 6–10,
24–26, "Estimating" steps 3 and the sanity rules.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Façade: `logEntry(name:servingName:quantity:macros:at:in:)` logs an Entry with no reference
- [ ] `FoodEstimator` protocol, `OpenRouterFoodEstimator`, and a fake:
  - text model `google/gemini-3.1-flash-lite` with strict `json_schema`,
    `provider.require_parameters`, and `temperature 0`;
  - cost logged from `usage`;
  - model IDs are constants in one file
- [ ] `DescribeDraft`:
  - lines with id, text, state (empty / checking / filled / failed) and result;
  - editing clears the result;
  - a reply for stale text is dropped;
  - Log takes only filled lines
- [ ] Sanity rules:
  - failed: negative, non-finite, over 5,000 kcal, over 3,000 g;
  - flagged: calories vs 4P + 4C + 9F off by more than max(40, 20%)
- [ ] Describe tab UI:
  - Reminders-style rows: Return adds a line below, backspace on an empty line removes it;
  - a caption per row with the result and its source, or its state;
  - a coral warning on failed rows, and tapping one retries;
  - the Log button, disabled with nothing filled;
  - the filter field hidden on this tab
- [ ] `WarningCard` for no key (button opens Settings), key rejected, and limit reached
- [ ] CONTEXT.md:
  - **Entry** widened to "a Food Item, a Meal, or a food described on its own with its own
    macros";
  - new **Estimate** (the name, portion and macros a model gives before logging; logging makes
    an Entry and keeps nothing of the Estimate), with its _Avoid_ words
- [ ] DESIGN.md §11 Food: the "+" sheet is Describe / Foods / Meals
- [ ] Tests:
  - façade: an Entry with no reference shows in `entries(on:)` and `dailyTotals`;
  - pure: reply parsing, sanity rules, draft transitions, error mapping
- [ ] Check by hand in the simulator with John's key: "2 eggs", "toast with butter", "large coffee with oat milk" fill in and log onto the timeline
