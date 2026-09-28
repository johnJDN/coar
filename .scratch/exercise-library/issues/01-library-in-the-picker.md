# 01: The library in the exercise picker and on Exercises

**What to build:** `ExerciseLibrary` (148 entries generated from `list.md`), shown in the
exercise picker under your exercises, grouped by muscle group and filterable by name or group.
Tapping an entry creates it through `createExercise` and picks it. Exercises → + opens the
picker in catalogue mode (New exercise, then the library, staying open as entries are added).
Entries you already have (by name, active or archived) are hidden. Spec: stories 1–6.

**Blocked by:** None

**Status:** done

- [x] `ExerciseLibrary.entries`, generated from `list.md`; integrity tests
- [x] Picker modes: plan/workout (your exercises + New + library) and catalogue (New + library, stays open, Done)
- [x] Library sections per muscle group with headers; filter by name or group title
- [x] Hide entries whose name matches an exercise you have (case-insensitive, archived included)
- [x] Exercises → + opens the catalogue picker; the list refreshes when it closes
- [x] Tests: integrity, "already have", filtering, adding creates an ordinary Exercise
- [x] Simulator: add three from Exercises → +, then add one from a plan's picker

## Comments

- 2026-09-27 (agent): Implemented.
  - **The data.** `ExerciseLibrary` (`Coar/Train/ExerciseLibrary.swift`): 148 entries
    generated from `list.md` by a one-off script, so the code matches the reviewed list.
  - **Helpers.**
    - `key` (case and spacing ignored), `entry(named:)`, and `details(of:)` (the same
      "Chest + Triceps · Dumbbell" line as your exercises).
    - `offered(excluding:filter:)` groups by primary group in `MuscleGroup` order, leaves out
      any name you have (active or archived), and matches the filter against the name or the
      primary group's title.
    - `add(_:to:)` goes through `createExercise`, with no rest default.
  - **The picker.** `ExercisePickerViewController` gains `Mode`:
    - `.pick` (plan and workout, unchanged call sites through a convenience init): your
      exercises, New exercise, then the library; a library tap adds and picks.
    - `.catalogue` (`catalogueSheet`, from Exercises → +): New exercise, then the library,
      with the ✓ Done button; each tap adds and re-renders, so the row disappears.
    - Library sections have headers, with the first reading "Library · Chest".
    - Library rows use the ListRow "+" (`QuickAddListCell`), and tapping the row does the
      same.
    - The filter field now says "Filter by name or muscle" and also matches your exercises
      by muscle group.
  - **Exercises → +** opens the library instead of the blank form. New exercise is its first
    row.
  - **Tests:** `ExerciseLibraryTests` (6): integrity (148, unique names, no primary repeated,
    known equipment, nothing under Other), all 14 of John's exercises present, owned names
    left out (archived too) in group order, filtering by name or group, and an added entry
    being an ordinary, renameable Exercise. Suite green at 321.
  - **Checked in the simulator** (sample data):
    - Exercises → + showed New exercise and "Library · Chest" without Bench press (already
      owned);
    - two taps added Incline dumbbell press and fly, each leaving the list;
    - Done showed both in Exercises with their groups and equipment;
    - Push → Add exercise listed your three, New exercise, then the library;
    - tapping Dumbbell bench press added it to the plan (3 × 8–12).
  - Left as deliberate:
    - library exercises have no rest default (the timer's 120 s applies);
    - no link back to the library, so later library changes don't touch your copies;
    - the catalogue sheet doesn't focus the filter (tapping through is the common use there),
      while the plan picker still does.
- 2026-09-27 (agent, after John: renaming library exercises "shouldn't be possible"): a
  library exercise now keeps its name. There's no schema change: `ExerciseLibrary.isLibraryName`
  recognises one by its name (case and spacing ignored), and the edit form shows that name as
  fixed text with a library icon. Its footer reads "From the library, so its name stays as it
  is. Its muscle groups and equipment are yours to change."; groups, equipment and rest still
  edit. Custom exercises rename as before. This also ends the duplicate risk from the last
  comment: a copy can't be renamed away from its library name. An exercise the user created
  under a library name counts as the library's. The store façade doesn't enforce the lock; the
  form is the only place a name is edited. Test `test_aLibraryExercise_isKnownByItsName_soItsNameIsKept`
  replaced the rename test; suite green at 329. Checked in the simulator: Exercises → Bench
  press → Edit showed the fixed name and note.
