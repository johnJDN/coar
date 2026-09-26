# 08: Train: Exercises, Plans, Supersets

**What to build:** The Exercise catalogue (name, primary Muscle Group from a fixed list, optional equipment, optional rest default) and the Plan editor: an ordered list of Exercises, each with ordered Planned Sets carrying a target weight (kg, shown in the display unit) and a min–max rep range, with adjacent Exercises groupable as a Superset. Train root lists Plans. Archive, don't delete.

**Blocked by:** 01

**Status:** done

- [x] Exercises chip opens the catalogue; editor with name, Muscle Group picker (fixed enum), equipment text, rest default seconds; archive
- [x] Train root shows a Plans section (cards with name and "n exercises") and the chips row
- [x] Plan editor: add Exercises from the catalogue picker (archived hidden), reorder, remove; per Exercise an ordered list of Planned Sets with weight and repMin/repMax (single number entered as min = max, shown as one number)
- [x] Superset: link two or more adjacent Exercises into one group; unequal set counts allowed; link icon shown between grouped cards
- [x] Archive Plan from its editor; Archived section with restore
- [x] Tests (façade): Plan exercise and set ordering persists through save/reload; superset group membership persists; archived Exercises absent from the picker; Planned Set weight stored kg when lbs entered

## Comments

- 2026-09-15 (agent): Implemented. Model: `Exercise`, `Plan`, `PlanExercise` and `PlannedSet`
  gained an optional `id: UUID` (additive, CloudKit-safe), as Habits and Food did. Façade
  (`Store+Train.swift`): `createExercise` / `updateExercise` / `exercises` (active, by name) /
  `archivedExercises` / `archiveExercise` / `restoreExercise`, and `createPlan` /
  `updatePlan` / `plans` / `archivedPlans` / `archivePlan` / `restorePlan`; rows and sets
  reconcile by id through `Store.reconcile`, so reordering keeps identity. Records
  (`TrainRecords.swift`): `MuscleGroup` (fixed list of 11), `RepRange` (min = max shows as one
  number), `ExerciseRecord`, `PlanRecord` → `PlanExerciseRecord` (holds its `ExerciseRecord`
  live plus `supersetGroup`) → `PlannedSetRecord`; drafts mirror them and
  `PlannedSetDraft(weight:in:reps:)` converts the display unit to kilograms (ADR 0004).
  `PlanDraft` keeps the Superset rule: links are boundaries between adjacent rows, groups
  are renumbered 1, 2, … after every link / unlink / reorder / remove, and a row left alone
  has none. Screens: the Exercises chip is live and pushes the catalogue (tap to edit in a
  sheet, `+` for a new one, Archived section with tap-to-restore); the Exercise sheet has
  name, Muscle Group menu, equipment, rest seconds, and Archive for an existing Exercise;
  the Train root lists Plans as cards (name, "n exercises", the exercise names) with a
  glass New plan button and an Archived section with Restore; the Plan editor is a
  reorderable list with a link button per row (lavender once linked), A1/A2 labels, swipe
  to remove, Add exercise → picker (archived hidden, "New exercise" inline), and `…` →
  Archive; tapping a row opens its Planned Sets as `SetRow`-style pills (set #, weight in
  the display unit, min – max), swipe to delete, Add set repeats the last set, Save
  disabled while any set lacks reps or has max below min. Tests: `TrainTests` (10, façade:
  ordering through save and read-back, superset persistence, archived Exercises absent
  from the picker query and kept in Plans, 135 lb stored as 61.235 kg, archive/restore,
  name sort) and `PlanDraftTests` (11, seam 2: link / unlink / reorder / remove renumbering,
  labels, rep range text, typed set validation). Verified visually in the simulator via a
  throwaway screenshot test (since removed) in light and dark: root with and without
  Plans, catalogue with and without Exercises, editor new and existing, Planned Sets,
  Exercise sheet, picker. 140 tests pass via
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test`.
  Left as deliberate, please confirm: (1) the Superset link is a button on each row (not
  the last) rather than an icon drawn between cards; the editor's rows are one merged list
  block with no gap to draw in, and the between-cards icon belongs to the logger's
  `ExerciseCard`s (ticket 09/10). (2) Grouped rows are labelled A1 / A2, B1 / B2 in the
  scheme line. (3) The picker offers "New exercise" (pre-filled with the filter) so a first
  Plan can be built without leaving the editor. (4) An added Exercise starts with 3 × 8–12
  and no weight; Add set repeats the last set. (5) A Plan needs a name and at least one
  Exercise to save; a row may have zero sets. (6) Weight left empty stores 0 kg and shows
  `—` (no weight lifted); reps typed as one number are min = max; a max below the min
  disables Save rather than being swapped. (7) Archive from the Plan editor's `…` menu
  and from the Exercise sheet does not confirm (reversible), matching Habits and Food; it
  discards unsaved edits in the editor. (8) Plans and Exercises list by name, no manual
  order. (9) The Exercises chip's subtitle is the active count; `—` when there are none.
  (10) The Train root still rebuilds its Plans stack on each appearance (no diffable
  animation); ticket 09 restructures the root anyway.
- 2026-09-15 (agent, after /code-review): "bodyweight" copy replaced (CONTEXT.md avoids
  it); New plan is a glass capsule (DESIGN §2/§7: glass when floating); the Planned Sets
  list stops at the keyboard layout guide so the last rows and Add set stay reachable;
  a rep max below the min now disables Save; the chip reads are separate so a Body
  Weight failure no longer blanks the Exercises count. Duplication pulled out:
  `Double(typed:)` (the locale parser the Body Weight and Habit amount sheets each had),
  `UIListContentConfiguration.addRow(_:)` (six "Add …" rows across Food and Train),
  `IndexPath.reorderTarget(original:proposed:lastReorderable:)` (the three editors' clamp);
  `PlanExerciseRecord` holds its `ExerciseRecord` instead of five copied fields;
  `PlannedSetFields` is top-level; `TrainText.sets` is `scheme(of:in:)`. Left as is: the
  root's stack rebuild (see (10)); `SectionHeaderView` is a reusable view so the root's
  stack uses plain labels; `PlanCardControl` and `EmptyStateCell` share a shape but not a
  type. 140 tests pass.

## Changed during human testing (2026-09-26)

The app-wide saving rule, equipment menu and secondary muscles, recency order. Details under this ticket's Results in `.scratch/coar-v1/human-testing.md`; where they differ from the text above, they win.
