# 07: Food: Meals, summary row, no-target state

**What to build:** Create a Meal from Food Items in fixed quantities; log it from the Meals segment as one Entry on the timeline with a quantity multiplier, keeping the component breakdown in its detail; and a compact summary row above the timeline showing consumed / target with a thin bar per macro against the Target in force that Day — with `—` and empty bars when no Target applies (`.scratch/data-model/issues/02`).

**Blocked by:** 06, 02

**Status:** ready-for-human

- [x] Meal editor: name; components as Food Item + Serving + quantity; reorder; archive
- [x] Meals segment lists active Meals with summed macros as subtitle; logging creates one Entry with the Meal's name, summed macros × multiplier, and a component snapshot
- [x] Meal Entry detail shows the breakdown; editing the Entry's macros or multiplier never touches the Meal
- [x] Summary row: four thin bars (calories, protein `accentBlue`, fat `accentPink`, carbs `accentOrange`), "consumed / target" labels, target from "in force on Day"
- [x] No Target for the Day: label reads "1,240 / —", bar track drawn, no fill; row never collapses
- [x] Tests (façade): meal snapshot survives editing the Meal or its Items; a Day before the first Target reports nil target and the row model renders the empty form
- [x] Tests (pure): summed macros × multiplier

## Comments

- 2026-09-15 (agent): Implemented. Model: `Meal` and `MealComponent` gained an optional
  `id: UUID` (additive, CloudKit-safe). Façade (`Store+Meals.swift`):
  `createMeal(name:components:)` / `updateMeal(_:name:components:)` take
  `[MealComponentDraft]` (Food Item id, Serving id, quantity) and sync lines by id (update,
  insert, delete the ones left out); `meals()` (active, by name, case-insensitive),
  `archivedMeals()`, `meal(_:)`, `archiveMeal`, `restoreMeal`; `logEntry(meal:quantity:at:in:)`
  makes one Entry with the Meal's name, Serving name "meal", the summed macros × the
  multiplier, a reference to the Meal, and an `EntryComponent` per line (name, Serving name,
  quantity, and macros for one of the Meal) (ADR 0003, 0005). Records: `MealRecord` (with
  `macros`, the lines summed), `MealComponentRecord` (names and macros read live from the
  Serving; `servingID` nil and zero macros once the Serving is gone), `MealComponentDraft`,
  `EntryComponentRecord`; `EntryRecord` gained `mealID` and `components`. Pure rules:
  `Macros.sum`, `MacroSummary` (per macro: consumed and target as whole numbers with
  grouping, fraction clamped to 1; no Target, or a 0 target for that macro, gives `—` and a
  nil fraction), `MealDraft` (upsert / remove / reorder; complete when named with at least
  one line that has a Serving). UI: `MacroSummaryView` between the week strip and the
  timeline (four columns: title in `textSecondary`, "1,240 / 2,100" with the consumed part
  in `textPrimary`, a 4pt `ThinBarView` on a `surfaceSunken` track filled in the macro's
  accent, moved with the §9 layout spring; the row stays in place with `—` and empty tracks
  when no Target is in force), the "+" sheet's Meals segment (`ListRow`s with
  "340 kcal · P 16 · F 10 · C 44", a square "+" that logs the Meal × 1 and closes, a "New
  meal" row, archived Meals under a matching filter to restore, long-press Edit / Archive),
  `LogMealViewController` + `LogMealForm` (quantity "× meal", time, the four macros the Entry
  will carry, and the "Made of" lines scaled by the multiplier; `…` menu Edit / Archive),
  `MealEditorViewController` (name field; lines as rows "Eggs" / "2 × 1 egg · 140 kcal" with
  a drag handle, swipe to delete, tap to change the Serving or quantity; "Add food" pushes
  `FoodItemPickerViewController` (filter over active Food Items) then
  `MealComponentFormViewController` + `MealComponentForm` (Serving picker, quantity); the
  section header shows the drafted total), and the Entry detail's "Made of" section on a
  Meal Entry (`BreakdownRow`, scaled by the quantity being typed). Verified through a
  throwaway screenshot test (since removed) in light and dark: the tab with and without a
  Target, both sheet segments, the editor, the log page, the Entry detail. 119 tests pass via
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test`.
  Left as deliberate, please confirm: (1) a Meal Entry's Serving name is "meal", so the
  card reads "0.5 × meal · P 8 · F 5 · C 22". (2) The calories bar uses `accentAmber`, the
  colour its tile already uses; DESIGN.md names no bar colour for calories. (3) Over the
  target, the bar is simply full: no colour change, no overflow. (4) A macro whose Target is
  0 (say fat left blank) renders as no target for that bar. (5) The summary row shows whole
  numbers with grouping ("1,240 / 2,100"), no units; the column title carries the meaning.
  (6) `EntryComponent`s store the lines for one of the Meal; the detail and log page scale
  them by the multiplier being typed, so overtyping a macro on the detail makes the
  breakdown and the totals disagree, as they must. (7) A line whose Serving was removed from
  its Food Item stays in the Meal with zero macros ("Serving removed · tap to pick another"
  in the editor) and Save is disabled until another is picked; logging such a Meal snapshots
  the line with an empty Serving name, shown as `—`. (8) Meals list by name, no manual order;
  lines within a Meal reorder by drag. (9) The Food Item picker inside the Meal editor lists
  active Food Items only and has no "New food" action; create the food from the Foods
  segment first. (10) A new Meal goes straight to its log page, as a new Food Item does.
  (11) The "No meals yet" placeholder from ticket 06 is gone; an empty Meals segment shows
  just "New meal". (12) The summary row is computed from the Day's Entries on every render
  and reads the Target in force on the selected Day, so paging to a past Day judges it
  against the Target that applied then.
