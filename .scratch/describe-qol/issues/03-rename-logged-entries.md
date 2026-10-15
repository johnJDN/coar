# 03: Rename a logged entry and change its unit

**What to build:** John asked (2026-10-14) for gap 4 from the corrections list: a logged
entry's name and unit couldn't be changed, only its quantity, time, macros and extras. Gap 3
("ask the AI again with more detail") was declined.

**Status:** done

- [x] `PortionUnit`: the unit-change rules from 02, shared by `DescribeLineEdit` and
      `EntryDraft`; reads weights a unit states ("100 g", "serving (28 g)")
- [x] `EntryDraft`: name, unit (`setUnit`, `unitNeedsNumbers`, `setMacro` adopts), `isMeal`
- [x] Entry page: Name and Unit rows like the Describe line page; a Meal Entry has no Unit row
- [x] `Store.updateEntry(…name:servingName:)`; the sheet's title follows a rename; Save as
      food is re-checked against the new name
- [x] Tests (8, `EntryRenameTests`)

## Comments

- 2026-10-14 (agent): Checked in the simulator: renaming "Eggs" to "Eggs scrambled" retitles
  the sheet and the timeline card; changing the unit shows "The macros below are still for
  4 × 1 egg. Change them if … is different." Left as deliberate:
  - **A unit relabel saves even without new macros.** Unlike a Describe line (which waits for
    "Estimate again"), the entry is your own record and there's no AI step here, so the
    page warns and trusts you. It converts by weight when it can ("100 g" → g, g → oz).
  - **No "Estimate again" on entries** (gap 3 was declined).
  - **A renamed entry keeps its link to the food it came from**, and the food itself never
    changes. So Save as food is still not offered for an entry logged from Foods.
  - **A Meal Entry's unit stays "meal"**; its name can change.
  - An empty name or unit isn't saved; the last good one stays.
