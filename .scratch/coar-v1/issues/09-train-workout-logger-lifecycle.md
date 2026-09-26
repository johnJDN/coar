# 09: Train: Workout logger and lifecycle

**What to build:** Start a Workout from a Plan (or empty), which deep-copies the Plan into the Workout (ADR 0003); log weight, reps, and completion per `SetRow` on `ExerciseCard`s pre-filled from the Planned Sets; add/remove sets and Exercises mid-Workout; Finish drops uncompleted sets and offers to write today's weights back to the Plan. Exactly one Active Workout, persisted from the first tap and surfaced in the accessory bar elsewhere; a Workout left active 12+ hours prompts finish/discard on launch. The month grid and recent Workouts make history browsable.

**Blocked by:** 08

**Status:** done

- [x] Start button on Train root: choose a Plan or "Empty workout"; the Workout is saved immediately with its own exercise rows (name snapshot, Exercise reference, supersetGroup, rest default) and Planned Set targets copied in
- [x] Logger screen: one `ExerciseCard` per row with `SetRow`s (set #, weight, reps, ✓) pre-filled from targets; completing a set floods the row `accentGreen` with the §9 spring; add set; add Exercise from picker; remove either
- [x] Editing the Plan after starting does not change the Workout; editing the Workout does not change the Plan
- [x] Finish: deletes Logged Sets not marked complete, sets `finishedAt`, then offers "Update plan targets with today's weights?" — accepting writes completed weights by position to the Plan's Planned Sets, never reps or exercise list; declining changes nothing
- [x] At most one Workout with `finishedAt == nil`; Start while one is active resumes it; leaving the logger shows the Active Workout in the `UITabAccessory` and tapping it returns to the logger
- [x] Launch with an Active Workout older than 12 hours presents Finish / Discard; Discard deletes it
- [x] Month grid on Train root marks Days with a Workout; tapping opens that Day's Workout, or a list when several; recent Workouts section below Plans
- [x] Tests (façade): copy independence both directions; finish drops uncompleted; write-back touches weights only; single-active invariant; multiple finished Workouts on one Day allowed

## Comments

- 2026-09-15 (agent): Implemented. Model: `Workout`, `WorkoutExercise` and `LoggedSet`
  gained an optional `id: UUID` (additive, CloudKit-safe). Façade (`Store+Workouts.swift`):
  `startWorkout(from:at:in:)` (returns the Active Workout if one exists; else a deep copy
  of the Plan: name snapshot, Exercise reference, Superset group, rest default, each
  Planned Set as a Logged Set pre-filled with the target weight and `repMin`, its target
  kept alongside; empty when no Plan), `activeWorkout`, `workout(_:)`, mid-Workout edits
  (`addExercise` / `removeExercise` / `addLoggedSet` / `removeLoggedSet` /
  `updateLoggedSet`), `finishWorkout` (deletes uncompleted sets, stamps `finishedAt`),
  `updatePlanTargets(from:)` (rows pair by Exercise in order, completed weights write by
  position, weights only), `discardWorkout`, `workouts(on:)`, `workoutDays(from:to:)`,
  `recentWorkouts(limit:)`; `Store.activeWorkoutDidChange` is posted on start / finish /
  discard for the shell. Records (`WorkoutRecords.swift`): `WorkoutRecord` (with
  `isStale(at:)` at 12 h, `completedSetCount`, `supersetLabel(for:)`),
  `WorkoutExerciseRecord`, `LoggedSetRecord`, `SetTarget`. Screens: Train root has the
  month grid (a `MonthCalendarView` with the new `tappableDays`; Workout Days glow green
  and open the Workout, or the Day's list), the prominent Start button (menu of Plans +
  Empty workout; Resume with the Plan name and start time while one is active), Recent
  workouts under Plans; the logger (`WorkoutLoggerViewController`) is one `ExerciseCard`
  per row with `SetRow`s (four `fill` pills; complete floods `accentGreen` 18 % with the
  §9 spring), Add set, `…` → Remove exercise, long-press a row → Remove set, Add exercise
  over the picker, Finish (coral) and `…` → Discard; `WorkoutDetailViewController` is the
  read-only history view; `WorkoutsOnDayViewController` lists a Day with several. Shell:
  `RootTabBarController` owns the `ActiveWorkoutBar` in `bottomAccessory` (shown when a
  Workout is active and the user is away from the logger; tap returns to it) and the
  launch check (stale → Finish / Discard). Tests: `WorkoutTests` (13, façade: copy in both
  directions, empty start, resume, finish drops uncompleted, new Workout after finish,
  write-back by position and weights only, 0 kg skipped, discard, two on one Day, recent
  order, stale rule). Verified visually in the simulator via a throwaway screenshot test
  (since removed) in light and dark: root with history and with an Active Workout, logger
  with a completed set, detail, Day list, accessory bar. 153 tests pass via
  `xcodebuild -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`.
  Left as deliberate, please confirm: (1) Logged Sets pre-fill reps with the range's
  minimum; the range shows as the placeholder once the field is cleared. (2) Finish with no
  completed set offers Discard / Keep logging instead of finishing (history never holds an
  empty Workout by accident); the launch prompt does the same (Discard / Keep active).
  (3) Finish with uncompleted sets confirms first ("n sets you did not complete will be
  dropped"). (4) The logger's `…` has Discard workout (confirmed), so a mistaken Start
  has a way out; the ticket named Discard only for the launch prompt. (5) Write-back
  skips a completed set with 0 kg so a bodyweight set never blanks a target, and the
  offer is not shown when no completed set has a weight; rows pair by Exercise in order
  rather than by raw position, so a row added mid-Workout is ignored and a removed one
  does not shift the rest. (6) The launch prompt's Finish does not offer the write-back.
  (7) The Workout's title is the Plan's name read live (renaming the Plan retitles past
  Workouts); the row names are the snapshot; "Empty workout" when there is no Plan.
  (8) An Exercise added mid-Workout starts with 3 blank sets; Add set repeats the last
  set's numbers, uncompleted, with no target. (9) The month grid marks today as soon as a
  Workout starts; Recent workouts lists finished ones only (5). (10) Remove set is a
  long-press menu on the row; Remove exercise is in the card's `…`. (11) Weight and reps
  fields have a Done bar; a field that does not parse leaves the stored value alone.
  (12) Non-Workout Days in the grid draw as empty `surfaceSunken` circles like the Habits
  calendar; only Workout Days respond to a tap. (13) The Plan name in the Recent card and
  detail is live; equipment in the logger subtitle is read live too (not snapshotted).
- 2026-09-15 (agent, after /code-review): Fixed: tapping the accessory bar while the
  picker sat over the logger pushed a second logger (the bar now hides while the logger
  is anywhere in the Train stack and the tab is Train, and a tap pops back to it); the
  check symbol scales with Dynamic Type (DESIGN §5); "In progress" copy is "Active"
  (CONTEXT.md); the launch prompt and the logger's Finish now agree on a Workout with no
  completed set (see (2)); the bar's minute timer stops while hidden; a dead
  `propertiesToFetch` line went. Duplication pulled out: `SupersetLabel.text(at:groups:)`
  (PlanDraft and WorkoutRecord), `UIView.pill(_:)` (Planned Sets and SetRow),
  `UIButton.glassAction` + `GlassActionCell` (New plan, Add exercise),
  `CardView.emptyState` (three empty cards), `Store.bySortOrder` over a `SortOrdered`
  protocol (the six inline sort-order sorts); `SetRowView.Model` carries its id instead
  of a parallel array; the Start button has one action. Left as is: `finishWorkout`
  throws on a missing Workout where other writes return silently (it returns the record,
  so a miss must be an error); `MonthCalendarView` stays in Habits with the heatmap
  `Level` (moving it is a Design-folder reshuffle, not this ticket); the three
  `massUnitDidChange` observers follow the existing Body Weight pattern; the logger's
  weight/reps parsing mirrors `PlannedSetFields` but writes per field, not per set.
  153 tests pass.
