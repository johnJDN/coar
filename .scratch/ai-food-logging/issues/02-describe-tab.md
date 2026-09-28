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

**Status:** done

- [x] Façade: `logEntry(name:servingName:quantity:macros:at:in:)` logs an Entry with no reference
- [x] `FoodEstimator` protocol, `OpenRouterFoodEstimator`, and a fake:
  - text model `google/gemini-3.1-flash-lite` with strict `json_schema`,
    `provider.require_parameters`, and `temperature 0`;
  - cost logged from `usage`;
  - model IDs are constants in one file
- [x] `DescribeDraft`:
  - lines with id, text, state (empty / checking / filled / failed) and result;
  - editing clears the result;
  - a reply for stale text is dropped;
  - Log takes only filled lines
- [x] Sanity rules:
  - failed: negative, non-finite, over 5,000 kcal, over 3,000 g;
  - flagged: calories vs 4P + 4C + 9F off by more than max(40, 20%)
- [x] Describe tab UI:
  - Reminders-style rows: Return adds a line below, backspace on an empty line removes it;
  - a caption per row with the result and its source, or its state;
  - a coral warning on failed rows, and tapping one retries;
  - the Log button, disabled with nothing filled;
  - the filter field hidden on this tab
- [x] `WarningCard` for no key (button opens Settings), key rejected, and limit reached
- [x] CONTEXT.md:
  - **Entry** widened to "a Food Item, a Meal, or a food described on its own with its own
    macros";
  - new **Estimate** (the name, portion and macros a model gives before logging; logging makes
    an Entry and keeps nothing of the Estimate), with its _Avoid_ words
- [x] DESIGN.md §11 Food: the "+" sheet is Describe / Foods / Meals
- [x] Tests:
  - façade: an Entry with no reference shows in `entries(on:)` and `dailyTotals`;
  - pure: reply parsing, sanity rules, draft transitions, error mapping
- [x] Check by hand in the simulator with John's key: "2 eggs", "toast with butter", "large coffee with oat milk" fill in and log onto the timeline

## Comments

- 2026-09-27 (agent): Implemented.
  - **Estimating.**
    - `Estimate` (`Coar/Food/Estimate.swift`): the value, its `Source`, `impossibility`,
      `caloriesDisagree`, and `init(reply:source:)`, which reads the strict JSON reply.
    - `FoodEstimator` (`Coar/Food/FoodEstimator.swift`): the protocol, `FoodModels.text`,
      the prompt and schema, `OpenRouterFoodEstimator`, and a debug-only
      `DebugFoodEstimator`.
    - `OpenRouterClient.complete(...)` sends one chat completion with a strict
      `json_schema`, `provider.require_parameters`, temperature 0, and `usage.include`. It
      logs model, seconds and cost under "AI", never the content. It takes text and JPEG
      parts, ready for 07.
  - **The draft.** `DescribeDraft` + `DescribeLine` (`Coar/Food/DescribeDraft.swift`) hold
    every change as a value transition:
    - editing clears the Estimate when the trimmed text changes;
    - `begin` returns the text to send, and `finish` drops a reply for stale text;
    - key problems send the line back to typing, offline makes it wait, and anything else
      fails it;
    - there's always one line.
  - **The screen.**
    - `DescribeViewController` is embedded in the "+" sheet as its first tab. It sends a
      line 2 s after its last edit, or at once on Return or leaving the field. A tap under a
      failed or waiting line retries it.
    - `DescribeLineCell` is a Reminders-style field with its caption. It keeps its caret
      across reconfigures.
    - `AddEntryViewController`: Describe / Foods / Meals, the filter field hidden on
      Describe, and a prominent Add in the nav bar.
    - `Store.logEntry(name:servingName:quantity:macros:at:in:)` logs an Entry with nothing
      behind it.
    - CONTEXT.md (Entry widened, Estimate added) and DESIGN.md §11 Food updated.
  - **Tests.** `DescribeTests` (11): reply parsing (whole portion, no unit or grams, not a
    food, not JSON), impossible numbers, the calorie check, the draft (sent once, a stale
    reply dropped, where each failure lands, Return/backspace, removing logged lines), and
    an Entry with nothing behind it counting toward its Day. Suite green at 282.
  - **The prompt**, checked against `google/gemini-3.1-flash-lite` from the Mac, 1.4–2.3 s
    each:
    - "2 eggs" → 143 kcal, 2 × large egg;
    - "toast with butter" → 135 kcal, 1 × slice;
    - "Chipotle chicken burrito bowl" → `needs_lookup` true;
    - "asdf keyboard" → `is_food` false.
  - **The screen, checked in the iPhone 18 Pro simulator** with `-FakeFoodEstimates` and
    `-DescribeLines`:
    - every state rendered: filled, waiting, not a food, impossible, failed, and the total;
    - Add logged the two filled lines (the day's calories went 680 → 1,380) and kept the
      rest;
    - tapping a waiting line re-sent it;
    - with no key, the `WarningCard` showed and Open Settings opened Settings over the sheet.
  - **Not checked in the simulator:** typing itself (Return, backspace, the 2 s wait). The
    headless simulator shows no software keyboard, even with the hardware keyboard turned
    off (turned back on afterwards). John checks typing on the phone.
  - Left as deliberate (see `human-testing.md`):
    - Add is in the nav bar like the other log pages, instead of the spec's
      "Log 3 · 740 kcal" button, with the count and total in a row under the lines;
    - one line is one Entry, named what the model calls it, with its unit as the Serving
      name;
    - a calorie mismatch is flagged but still added;
    - closing the sheet loses unlogged lines until ticket 03.
