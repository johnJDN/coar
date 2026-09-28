# 04: Your library wins

**What to build:** A line that means one of John's Food Items or Meals uses it: its macros, and
an Entry linked to it through the existing log calls.
- **Exact names** ("protein shake", "2 eggs", "½ post-workout shake") match locally with no
  model call.
- **Looser wording** ("my usual shake") is matched by the text model through short library
  handles. The macros still come from the library, and a handle that doesn't resolve falls
  back to the estimate.
- Filled rows say "Your food" or "Your meal".

Spec: stories 11–12, "Estimating" steps 1 and 3.

**Blocked by:** 02

**Status:** done

- [x] Exact local match:
  - normalised text equals an unarchived Food Item or Meal name, with a trailing "s" folded;
  - a leading quantity multiplies the default Serving (or the Meal)
- [x] Library handles:
  - `f1`, `s1`, `m1` in the text model's prompt, mapped back locally;
  - archived items left out;
  - the prompt stays small (names and Serving names only)
- [x] The reply schema gains an optional `match: {handle, serving, quantity}`
- [x] A resolving match wins over the estimate; an unresolved handle is ignored and the estimate stands
- [x] Log routes library lines through `logEntry(foodItem:serving:quantity:)` / `logEntry(meal:quantity:)`, so "recently used" order updates
- [x] A Meal that isn't loggable (a line lost its Serving) doesn't match; the line is estimated instead
- [x] Tests:
  - pure: exact matching (quantity, plural, fractions, archived excluded) and handle mapping (valid, unknown, archived);
  - façade: a library-matched Log links the Entry to the Food Item or Meal
- [x] Check by hand: "2 eggs" with Eggs saved fills instantly with no request in the Food log; "my usual shake" matches the saved shake

## Comments

- 2026-09-27 (agent): Implemented.
  - **`FoodLibrary`** (`Coar/Food/FoodLibrary.swift`) holds the unarchived Food Items that
    have a Serving and the loggable unarchived Meals.
  - **`exactMatch`** reads a leading quantity ("2", "1.5", "½", "1/2", "1½", "2x", "3 x")
    and compares the rest with each name, allowing a plural "s" or "es".
    - It checks Food Items first, then Meals, and uses the default Serving.
    - It runs before the key check, so saved foods fill in with no key and offline.
  - **The model's side.**
    - `promptListing` shows the catalogue as `f1 Eggs: s1 "1 egg", s2 "100 g"` /
      `m1 Overnight oats (meal)`.
    - `FoodEstimatePrompt.library(_:)` appends it to the rules.
    - The strict schema gains a nullable `match {food, serving, quantity}`.
    - `resolve` maps handles back: an unknown food → nil (the estimate stands); an unknown
      or null serving → the default; a nonsense quantity → 1.
  - **Estimate additions.** `Estimate.match` (`LibraryMatch`) and the sources `.food` ("Your
    food") and `.meal` ("Your meal"). `Estimate.parse` returns the model's pick alongside.
  - **Logging and caching.**
    - Add logs a match through `logEntry(foodItem:serving:quantity:)` or
      `logEntry(meal:quantity:)`.
    - A match archived or deleted in the meantime (`Store.NotFound`) is logged on its own
      with the numbers shown, rather than lost.
    - `CachingFoodEstimator` doesn't keep matches.
  - **Prompt checks** against Gemini Flash-Lite:
    - "my usual shake" → the Post-workout shake meal;
    - "a couple of eggs" → 2 × "1 egg";
    - "200g eggs" → 2 × "100 g";
    - "chobani" → the saved yogurt;
    - "banana" and "eggs and toast" → no match.
    - "protein shake with milk" matched the plain shake until the prompt said not to match
      when the line adds something. Now it doesn't.
  - **Tests:** `FoodLibraryTests` (8): exact names (quantity forms, plural, extra words,
    archived), a Meal match, an unloggable Meal left to the model, the listing, resolving
    picks, a reply read with its match, matches not cached, and a matched log linking the
    Entry. Suite green at 296.
  - **Checked in the simulator with no key:** "2 eggs" and "rice" filled in as "Your food"
    from the sample catalogue, while "banana" waited under the no-key card. Add logged them
    (the day went 680 → 1,020 kcal).
  - Left as deliberate:
    - an exact name wins over the model even when another food's name contains it;
    - a Food Item and a Meal with the same name: the Food Item wins;
    - the catalogue is read afresh for every line sent.
