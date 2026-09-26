# 11: Train: Exercise Progression

**What to build:** An Exercise detail page with a Progression chart — Estimated 1RM per Workout from that Workout's best completed set (Epley, w × (1 + r/30)) — and a list of recent sets below it.

**Blocked by:** 09

**Status:** done

- [x] Tapping an Exercise (catalogue, or an `ExerciseCard` header) pushes the detail page
- [x] Swift Charts line hosted per ADR 0001: one point per Workout containing the Exercise, 2 pt accent stroke, bloom on last point, axis labels `textTertiary`, no gridlines, no legend
- [x] A single Workout renders one bloomed point and no line; no Workouts renders `No data` in the chart slot
- [x] Recent sets list: per Workout, Day and each Logged Set's weight × reps in the display unit
- [x] Tests (pure): Epley on known pairs; best-of-Workout picks the highest e1RM among completed sets only; uncompleted sets ignored

## Comments

- 2026-09-16 (agent): Implemented. Rule (`Progression.swift`, Seam 2, pure):
  `estimatedOneRepMax(kilograms:reps:)` (Epley, w × (1 + r/30)), `best(of:)` (the highest
  Estimated 1RM among completed sets; a completed set with no weight or no reps is skipped;
  nil when none counts), `points(for:in:)` (one `Point` per Workout containing the Exercise,
  every row of the Exercise pooled; a Workout with no counting set contributes none), and
  `WorkoutRecord.loggedSets(of:)`. Façade (`Store+Workouts.swift`): `workouts(containing:)`,
  every Workout with a row for the Exercise, earliest first, the Active Workout included.
  Chart: `ProgressionChart` (SwiftUI leaf, ADR 0001): one `accentLime` point per Workout, a
  2 pt monotone line once there are two, bloom on the last point, `No data` when empty. The
  chrome the two trend charts share (about four date labels, three trailing values in
  `textTertiary`, no gridlines, padded value axis, `No data`, the height) moved out of
  `BodyWeightChart` into `TrendChartChrome` (`Design/TrendChart.swift`) with a shared
  `TrendPoint` and a `bloom(_:in:)` chart modifier; the chrome now pulls the end date labels
  inward (the last one used to truncate) and hides both axes when the series is empty (Body
  Weight gains both). Screen: `ExerciseDetailViewController` (title the name, subtitle
  "Chest · Dumbbell · Rest 150 s", Edit in the bar over the Exercise sheet): a Progression
  card with the latest Estimated 1RM as the hero ("117 lbs", whole), "Estimated 1RM · Sep 16"
  under it, the chart; then Recent sets, one card per Workout (latest first, up to 10) titled
  by Day with "Push · 7:28 PM" and each completed Logged Set as "88.2 lbs × 10" via the
  `UIView.setLine` shared with the Workout detail. Entry points: tapping an active Exercise in
  the catalogue pushes the page (editing moved to the page's Edit; archived rows still
  restore); the `ExerciseCard` gained the DESIGN §7 footer split "Progression | Add set" and
  a tappable header, both opening the page over the logger (the accessory bar stays hidden
  as under the picker). Tests: `ProgressionTests` (6: Epley on known pairs, best among
  completed only, nothing completed, no-weight/no-reps skipped, one point per Workout in
  order with rows pooled, Workouts without a counting set skipped) and one façade test in
  `WorkoutTests`. Verified visually in the simulator via a throwaway screenshot test (since
  removed) in light and dark: several Workouts, one Workout, none, and the logger footer.
  174 tests pass via
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`.
  Left as deliberate, please confirm: (1) The accent is `accentLime`, matching the Exercises
  chip, rather than `accentBlue`'s "generic progression dot" (DESIGN §3 also forbids blue
  for anything but protein). (2) The Active Workout contributes its completed sets to the
  chart and the list, so today's point appears mid-Workout. (3) A completed set with 0 kg
  or 0 reps never counts; a Workout with only such sets has no point. (4) Reps of 1 follow
  Epley literally (w × 1.033), not w. (5) The hero Estimated 1RM is a whole number; the
  chart's values keep one decimal. (6) Two rows of the same Exercise in one Workout pool
  into one point; the recent-sets card lists them as one run of sets. (7) Recent sets shows
  10 Workouts at most and skips a Workout with no completed set of the Exercise. (8) The
  catalogue no longer opens the edit sheet on tap; Edit lives on the detail page. (9) The
  Workout detail's cards do not open Progression (not in the ticket). (10) The line is
  monotone-interpolated (no overshoot between Workouts) where Body Weight keeps Catmull-Rom.
  (11) A single point's value axis reads in halves (48.5 … 50.0) because the shared padding
  floor is 1, as for Body Weight.
- 2026-09-16 (agent, after /code-review): Fixed: DESIGN §3's accent table now names
  Progression on `accentLime`'s row and drops `accentBlue`'s "progression dot" note, so the
  doc and the code agree (reverse both if lime is the wrong call); CONTEXT.md avoid-words
  ("bodyweight", "deleted") went from the comments. Duplication pulled out:
  `HeroNumberLabel` (the §5 hero font and the §9 cross-dissolve, now shared with Body
  Weight), `CardView.setHistory(title:subtitle:sets:in:)` (the Logged Set card shared by the
  Workout detail and Recent sets; the misnamed `SetLineView.swift` went with it),
  `trendChartChrome(over:)` takes the points rather than two parallel arrays; a no-op
  spacing line that reached into the card's header, a stray `alignment` on the horizontal
  footer, and a lazy sequence walked twice went. Left as is: the section header is
  hand-built like the Train root's; `TrendPoint` keys by date (two Workouts started the same
  instant cannot happen); "Add set" keeps the logger's existing casing. Flagged by the Spec
  review, please confirm: (12) Recent sets lists completed sets only, so the Active Workout's
  unticked sets are left out until ticked (finished Workouts hold only completed sets
  anyway). (13) The shared chrome changes Body Weight's chart too: end date labels pulled
  inward, axes hidden when empty (this is a behaviour change, not a pure refactor; it is on
  the human-testing list). 174 tests pass.
