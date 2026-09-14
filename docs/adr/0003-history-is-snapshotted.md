# 0003. History is snapshotted, never resolved live

**Status:** accepted (2026-09-13)

## Context

Three kinds of record describe something that happened on a date and are derived from
something the user can later edit: a food **Entry** comes from a Food Item or Meal, a
**Workout** comes from a Plan, and a day's macro progress is judged against a **Target**.
If those records reference their source live, editing "Eggs" from 70 to 78 kcal rewrites
six months of food history, swapping an exercise in a Plan rewrites every past Workout,
and raising a calorie target after a cut repaints three months of successful days as
failures.

## Decision

History records carry their own copy of everything needed to display them, taken at the
moment they were created:

- An **Entry** stores the name, the Serving name, the quantity, and the four macros. It
  keeps an optional reference to its Food Item or Meal only for re-logging and grouping.
  A Meal Entry also keeps its component breakdown for display.
- Starting a **Workout** deep-copies the Plan into the Workout's own exercise and set
  rows (Planned Set targets copied in; Logged Sets recorded alongside). The Workout keeps
  a plain reference to the Plan for grouping. Mid-workout edits touch only the Workout.
- A **Target** is a dated series (effective-from date), and a day is rendered against the
  Target in force on that day. Settings shows and edits only the current one.

The same rule applies to any future record of this shape.

## Considered options

- **Live references** (normalised): least storage, simplest writes, but history becomes a
  view over current definitions and silently changes. Rejected.
- **Versioned catalogue items** (a new Food Item version on every edit): equivalent
  outcome with more machinery and a harder UI. Rejected.

## Consequences

- Editing a Food Item, Plan, or Target never changes the past; correcting a past day means
  editing that Entry, Workout, or Target series directly.
- Duplicate data on disk; irrelevant at single-user scale.
- The catalogue is free to change shape (Servings added, Plans reworked) without a
  migration touching history.
