# Merge rule for records CloudKit lets duplicate

Status: ready-for-agent

ADR 0002 forbids unique constraints (CloudKit can't enforce them), but the model has
four invariants that two devices syncing offline can violate:

| Invariant | Key | How a duplicate arises |
|---|---|---|
| One Check-in per Habit per Day | habit + day | Tap ✓ on phone and watch/iPad before sync |
| One Body Weight per Day | day | Weigh in, log on two devices |
| At most one Active Workout | (global) | Start a workout on two devices |
| One default Serving per Food Item | food item | Edit servings on two devices |

Without a rule the app shows two rows, streaks count a day twice, and "one active
workout" logic picks arbitrarily.

## Rule (decided 2026-09-13)

- Every entity carries an app-set `modifiedAt` (not Core Data's transient state).
- On `NSPersistentStoreRemoteChange`, run a dedupe pass per invariant: group by key,
  keep the row with the latest `modifiedAt`, delete the rest. Deterministic, so every
  device converges on the same survivor.
- Active Workout is the exception because the loser has data: keep the one with the
  later `startedAt` active; the older one is *finished* (kept as history) if it has any
  Logged Set, deleted if it has none.
- The same pass runs once on launch, so a device that missed a notification still heals.

## Comments

- 2026-09-13: "latest `modifiedAt` wins" confirmed for every invariant, including
  quantitative Check-ins (no per-kind rule, no summing). Active Workout is the sole
  exception, as above.
