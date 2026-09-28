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

**Status:** ready-for-agent

- [ ] The line page from a filled or failed row; back returns to the Describe tab with the row updated
- [ ] Quantity edits scale macros from the per-one values; macro edits set the source to "Typed" and stop further estimating of that line until its text changes
- [ ] A failed line becomes filled once all four macros are typed
- [ ] Save as food:
  - the toggle is off by default and hidden for library-matched lines (already saved);
  - the name defaults to the line's name
- [ ] Façade: `logEntry(savingAsFood:…)` creates the Food Item + Serving and the linked Entry in one save
- [ ] Tests:
  - pure: quantity scaling and typed-macro transitions;
  - façade: Save as food creates one Food Item and one linked Entry, and a second Log of the
    same name doesn't duplicate by accident (it's a new Food Item only if the toggle is on again)
- [ ] Check by hand: estimate "pizza slice", set quantity 2, log with Save as food, and see it in Foods at the top
