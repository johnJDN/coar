# 11: Train: Exercise Progression

**What to build:** An Exercise detail page with a Progression chart — Estimated 1RM per Workout from that Workout's best completed set (Epley, w × (1 + r/30)) — and a list of recent sets below it.

**Blocked by:** 09

**Status:** ready-for-agent

- [ ] Tapping an Exercise (catalogue, or an `ExerciseCard` header) pushes the detail page
- [ ] Swift Charts line hosted per ADR 0001: one point per Workout containing the Exercise, 2 pt accent stroke, bloom on last point, axis labels `textTertiary`, no gridlines, no legend
- [ ] A single Workout renders one bloomed point and no line; no Workouts renders `No data` in the chart slot
- [ ] Recent sets list: per Workout, Day and each Logged Set's weight × reps in the display unit
- [ ] Tests (pure): Epley on known pairs; best-of-Workout picks the highest e1RM among completed sets only; uncompleted sets ignored
