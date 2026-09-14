# 09: Train: Workout logger and lifecycle

**What to build:** Start a Workout from a Plan (or empty), which deep-copies the Plan into the Workout (ADR 0003); log weight, reps, and completion per `SetRow` on `ExerciseCard`s pre-filled from the Planned Sets; add/remove sets and Exercises mid-Workout; Finish drops uncompleted sets and offers to write today's weights back to the Plan. Exactly one Active Workout, persisted from the first tap and surfaced in the accessory bar elsewhere; a Workout left active 12+ hours prompts finish/discard on launch. The month grid and recent Workouts make history browsable.

**Blocked by:** 08

**Status:** ready-for-agent

- [ ] Start button on Train root: choose a Plan or "Empty workout"; the Workout is saved immediately with its own exercise rows (name snapshot, Exercise reference, supersetGroup, rest default) and Planned Set targets copied in
- [ ] Logger screen: one `ExerciseCard` per row with `SetRow`s (set #, weight, reps, ✓) pre-filled from targets; completing a set floods the row `accentGreen` with the §9 spring; add set; add Exercise from picker; remove either
- [ ] Editing the Plan after starting does not change the Workout; editing the Workout does not change the Plan
- [ ] Finish: deletes Logged Sets not marked complete, sets `finishedAt`, then offers "Update plan targets with today's weights?" — accepting writes completed weights by position to the Plan's Planned Sets, never reps or exercise list; declining changes nothing
- [ ] At most one Workout with `finishedAt == nil`; Start while one is active resumes it; leaving the logger shows the Active Workout in the `UITabAccessory` and tapping it returns to the logger
- [ ] Launch with an Active Workout older than 12 hours presents Finish / Discard; Discard deletes it
- [ ] Month grid on Train root marks Days with a Workout; tapping opens that Day's Workout, or a list when several; recent Workouts section below Plans
- [ ] Tests (façade): copy independence both directions; finish drops uncompleted; write-back touches weights only; single-active invariant; multiple finished Workouts on one Day allowed
