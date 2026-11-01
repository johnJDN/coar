# 02: Link a workout to its Watch workout by itself

**What to build:** John asked (2026-11-01) for links to be automatic. A finished Workout is
linked without a tap to the one Health Workout that overlaps it in time, whenever Coar reads its
Day: the Day page, the workout screen, Recent workouts and a Day's list. Not at Finish, since
the Watch can take minutes to save its workout to Health. Unlinking is remembered.

**Status:** done

- [x] `Workout.watchLinkDeclined` (Bool), set by Unlink, cleared by a link by hand
- [x] `HealthWorkout.autoLinks`: each finished, unlinked, not-declined Workout to its one-tap
      suggestion, only when no other such Workout has the same suggestion
- [x] `Store.autoLinkHealthWorkouts(on:among:)`; called from the Day page, the workout screen,
      and `WorkoutEffort.texts` (Recent workouts, a Day's list)
- [x] Tests (4): links the one overlap; none when two overlap it or it overlaps two Workouts; an
      unlinked Workout stays unlinked until linked by hand; an Active Workout never

## Comments

- 2026-11-01 (agent): Left as deliberate: several overlaps still leave the choice to John (the
  card's sheet); a Watch workout that only starts or ends near the Workout without overlapping
  isn't linked by itself; the inhaler mark of an unlinked Watch workout's note isn't moved to the
  Workout on linking. Two passes can race (the list renders twice): each reads the Workouts
  afresh after its Health read, so the one that loses still shows the link. Needs the same
  CloudKit schema deploy (new field). On a finished workout, "Used inhaler before" moved from
  the subtitle (cut off beside … and Edit) to its own line above the Apple Watch card; the
  workout screen's editing subtitle no longer shows it either (the menu tick does).
