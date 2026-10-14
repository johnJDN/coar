# 01: Link a workout to its Watch workout

**What to build:** An Apple Watch card on a finished Workout that links it to a Health Workout
and shows its Effort (active calories, average heart rate) read live from Apple Health; Effort
on the Workout cards in Recent workouts and a Day's list; Unlink in the `…` menu. Spec:
`../spec.md`.

**Status:** done

- [x] `Workout.healthWorkoutID` (optional UUID), `WorkoutRecord.healthWorkoutID`
- [x] `Store.linkHealthWorkout` (finished Workouts only; one Health Workout per Workout),
      `linkedHealthWorkoutIDs(excluding:)`
- [x] `HealthWorkout` and the pure rule: candidates by overlap then nearness, the one-tap
      suggestion only when exactly one overlaps
- [x] `HealthWorkoutReader` on `HealthKitAccess` (workouts, active energy, heart rate through
      `HKWorkout` statistics; its own permission), a fake, and `-FakeHealthWorkouts` for the
      simulator
- [x] `WatchLinkCardControl` on the detail; `HealthWorkoutPickerViewController` sheet; Unlink
      in the menu
- [x] Effort line on `WorkoutCardControl` in Recent workouts and a Day's list
- [x] Tests: the rule, the link, one-per-Workout, active Workouts can't link
- [x] CONTEXT.md (Health Workout, Effort), ADR 0002, DESIGN.md, brief

## Comments

- 2026-10-14 (agent): Implemented and checked in the simulator with `-SeedSampleData
  -FakeHealthWorkouts`: the card offers "Link 318 kcal" for the one overlapping session, links
  in one tap, the sheet lists both sessions with a check on the linked one, the `…` menu
  offers Unlink, and Recent workouts shows "🔥 318 kcal · 118 bpm". The real reader (HealthKit
  on a Watch) can only be checked on John's phone.
  Left as deliberate:
  - **Numbers are not copied** (see the spec): a deviation from what John approved, forced by
    ADR 0002. If Health loses the workout the link shows "isn't in Apple Health right now".
  - The one-tap offer is on the detail screen, not on Finish, since the Watch takes minutes
    to hand a workout to the iPhone.
  - The sheet lists every unlinked Health Workout on the Workout's Day, best match first, so
    a roughly timed past workout can still be linked by hand. A session that started the day
    before or after (past midnight) isn't listed.
  - A Health Workout linked to one Workout isn't offered for another; link it there to move it.
  - Kind names cover the common Watch types ("Strength training", "Run", "Pickleball", …);
    anything else reads "Workout".
  - A read Health refused looks the same as nothing recorded (HealthKit never says); the empty
    sheet names both, and where to check.
