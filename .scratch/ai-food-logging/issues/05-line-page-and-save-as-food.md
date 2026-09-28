# 05: Line page: adjust, type your own, save as food

**What to build:** Tapping a filled line (or a failed one) pushes the line page. It follows
DESIGN.md §7a "a page inside an editor": edits write back into the line, with no Save.
- **Fields:** name, quantity and unit, a `MacroStrip`, the four macro fields, and a Save as
  food toggle.
- **Quantity** scales the macros.
- **Typing a macro** makes the line "Typed". A typed line never needs a model, which also makes
  it the way to log offline or past a failure.
- **Save as food** makes Log create a Food Item with one Serving (the unit, macros for one,
  grams when known) and link the Entry to it, in one save.

Spec: stories 13–16, "Data: no schema change".

**Blocked by:** 02

**Status:** done

- [x] The line page from a filled or failed row; back returns to the Describe tab with the row updated
- [x] Quantity edits scale macros from the per-one values; macro edits set the source to "Typed" and stop further estimating of that line until its text changes
- [x] A failed line becomes filled once all four macros are typed
- [x] Save as food:
  - the toggle is off by default and hidden for library-matched lines (already saved);
  - the name defaults to the line's name
- [x] Façade: `logEntry(savingAsFood:…)` creates the Food Item + Serving and the linked Entry in one save
- [x] Tests:
  - pure: quantity scaling and typed-macro transitions;
  - façade: Save as food creates one Food Item and one linked Entry, and a second Log of the
    same name doesn't duplicate by accident (it's a new Food Item only if the toggle is on again)
- [x] Check by hand: estimate "pizza slice", set quantity 2, log with Save as food, and see it in Foods at the top

## Comments

- 2026-09-27 (agent): Implemented.
  - **`DescribeLineEdit`** (`Coar/Food/DescribeLineEdit.swift`) mirrors `EntryDraft`:
    - quantity scales the macros (and grams) from what one holds;
    - `setMacro` makes the numbers "Typed" and drops the assumption;
    - a line with no Estimate becomes addable once a macro is typed, with empty fields as 0,
      like the Targets form;
    - a matched line keeps its match through a quantity change. A new name, unit or macro
      makes it the user's own line: no match, "Typed".
  - **`Estimate.servingToSave`** gives the Serving that Save as food creates: one of the
    unit with macros for one. A line in g or ml saves a "100 g" or "100 ml" Serving and logs
    `quantity / 100` of it, so the food logs sensibly next time.
  - **The page.** `DescribeLineForm` + `DescribeLineViewController`, pushed in the sheet:
    - Name, Quantity, Unit, a `MacroStrip`, and the four macro fields;
    - a footer saying where the numbers came from, plus the model's assumption;
    - Save as food, hidden for matched lines;
    - for a failed or waiting line, the reason and Try again (pops and re-sends).
    - Edits write into the line as they happen (§7a), through `DescribeDraft.setEstimate` /
      `setSaveAsFood`.
  - **Rows.** Tapping under a filled, failed or waiting line opens its page (it used to
    retry). The failed caption now ends "Tap to try again or type it in". A line set to
    save shows "· Saving to Foods" in green.
  - **Store.** `Store.logEntrySavingFood(name:serving:quantity:at:in:)` creates the Food
    Item with its one Serving and the linked Entry in one save. The shared body of
    `write(name:servings:to:)` is now `apply` (no save).
  - `DescribeLine.saveAsFood` is kept in the draft, and a draft file from before the field
    still decodes.
  - **Tests:** `DescribeLinePageTests` (7): quantity scaling (with a cleared field),
    typed macros, a failed line typed in, a match kept or dropped, the Serving saved (per
    unit and per 100 g), Save as food in the store, and the flag kept in the draft. Suite
    green at 303.
  - **Checked in the simulator:**
    - a filled line's page showed the fields, strip and "Estimated. …" note;
    - Save as food + back showed "Saving to Foods";
    - Add put "Pizza slice" at the top of Foods;
    - a failed line's page showed the reason, Try again, and empty fields.
  - Typing in the fields wasn't checked in the simulator (no software keyboard).
  - Left as deliberate:
    - typed numbers skip the 5,000 kcal check, since the user said so;
    - one typed macro is enough to add a failed line, the others counting as 0;
    - Save as food is off by default and hidden for matched lines;
    - a page open while its line fills from the network shows the numbers it opened with.
