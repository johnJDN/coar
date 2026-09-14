# 05: Habits: quantitative, weekly, dated targets

**What to build:** Quantitative habits ("20 pages a day") with a number sheet and quick-add chips that edit the single day's Check-in; week-period habits ("gym 3× a week") with week-met dots above the heatmap columns, weekly streaks, and a "2 of 3 this week" caption; and target + period as a dated change so raising a target never repaints history (ADR 0003).

**Blocked by:** 04

**Status:** ready-for-human

- [x] Kind selector (yes/no | quantitative) and period selector (day | week) on the new-habit sheet
- [x] Quantitative card control shows today's total; tapping opens a compact sheet with the total, a number pad, and `+N` chips; every path sets the one Check-in's amount (replace semantics)
- [x] Quantitative cells colour by amount ÷ target-in-force in four buckets (≤25, ≤50, ≤75, ≥100 %); yes/no cells stay binary regardless of period
- [x] Weekly habits: a `DotMatrix`-style dot per column, filled when that Monday–Sunday week met target; daily habits have no dot row
- [x] Streak in the habit's period unit ("4 weeks"); current week counts once met, breaks only after Sunday unmet; weekly caption "2 of 3 this week"
- [x] Detail page edits target amount and period together as a new dated record effective today; past Days render against the record in force then; a Day before the first record renders empty
- [x] Tests (pure): bucket boundaries; weekly streak with pending-week rule; period switch day→week yields a clean seam in streak computation
- [x] Tests (façade): target-in-force per Day for a Habit; nil before first record

## Comments

- 2026-09-13 (agent): Implemented. Façade (`Store+Habits.swift`): `HabitRecord` now carries
  the whole dated target series (`targets`, earliest first, latest-modified record standing
  when a Day starts several) with `target(inForceOn:)` (nil before the first record), and
  `setHabitTarget(_:amount:period:effectiveFrom:)` writes a new dated record (no-op when
  the same target is already in force that Day; replaces a record that Day already starts,
  mirroring `setTarget`). Pure rules: `Heatmap.level(amount:target:)` (four buckets: ≤25 %,
  ≤50 %, short of the target, met), `Heatmap.weeks(endingOn:columns:)` (the Monday of each
  column), `Heatmap.cells` now takes a `[Day: Level]`; `Streak.weeks(met:today:)` shares the
  pending-current-Period walk with `Streak.days`. `HabitCardModel` is the one place the
  records become "met": each Day is judged against the target in force on it, each week
  against the target in force on its Sunday, and the Streak is counted in the Period in
  force today, so a switch day→week starts the weekly Streak at the week of the switch
  (Periods judged under the other Period never count); it also yields `levels`, `weekDots`,
  `weekCaption` ("2 of 3 this week"), `todayAmount`, `editableFrom`. UI: `HabitTargetSection`
  (Kind Yes / no | Amount, Period Day | Week, amount field that hides for a daily yes/no
  Habit and reads "Days a week" / "Amount a day" / "Amount a week") shared by `HabitForm`
  and the new `HabitTargetForm` + `HabitTargetViewController` (Change Target sheet, Save
  enabled only when something changed); `AmountControlView` (DESIGN.md §7 `AmountControl`,
  new row) on quantitative cards; `HabitAmountViewController` (number sheet: hero field,
  "of 20", three `+N` glass chips that write at once, Done writes the typed total, 0 removes
  the Check-in); `HeatmapView` gained the `DotMatrix`-style week row (hidden for daily
  Habits) and bucket fills; `StreakHeroView` a caption; `MonthCalendarView` renders levels
  and makes Days before the first target inert; the detail gained a Target card with Change
  and opens the number sheet for a quantitative Day. Verified in the simulator (seeded
  through a throwaway test, since removed) in light and dark: tab with yes/no daily,
  quantitative daily, yes/no weekly, and quantitative weekly cards, both detail kinds, the
  number sheet, the Change Target sheet, the new-habit form. 81 tests pass via
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test`.
  Left as deliberate, please confirm: (1) the third bucket runs from just over 50 % up to
  just under 100 %, so only reaching the target is `done` (full accent + bloom); the
  ticket's "≤75 %" boundary would have drawn a 90 % Day identically to a met one.
  (2) A week is judged against the target in force on its Sunday, so raising a weekly
  target mid-week applies to the current week and never to finished ones; a Day is judged
  against the target in force on it. (3) Quantitative weekly cells bucket each Day's amount
  against the weekly target (spec: "amount ÷ the period's target"), so the dot row, not the
  cells, says whether the week was met. (4) The `AmountControl` turns green when the
  current Period is met: on a weekly quantitative Habit that can be a green `—` (week met,
  nothing logged today). (5) Chips write the Check-in immediately and keep the sheet open;
  Done writes the typed total; there is no Cancel (swiping down discards only unsaved typing).
  (6) Quantitative targets and amounts may be fractional (2.5 km); yes/no weekly targets are
  whole and at most 7. (7) Days before the first target are inert on the calendar, not just
  empty, so a tap cannot create a Check-in nothing renders. (8) Kind is fixed at creation;
  the Change Target sheet edits amount and Period only. (9) The Target card shows the value
  and unit ("20 a day", "3 days a week") with no "since" date.
- 2026-09-13 (agent, after /code-review): the detail calendar hides future Days again (the
  cell now takes "future" from the Day, not from a level the model never emits); a daily
  yes/no Habit is met by any Check-in whatever amount its target stores (a ticket-04 Habit
  saved with amount 2 showed green cells and a 0 streak, and Change Target could not repair
  it), with a test; the number sheet says "of 20 this week" for a weekly target; the
  heatmap's VoiceOver value refreshes when the dot row changes; the amount control's bloom
  fades in on a change instead of popping, and resets on cell reuse like the streak hero;
  "log"/"logged" copy became "check in"/"entered" (CONTEXT.md avoids "log" for Check-ins).
  Duplication pulled out: `CapsuleControlView` (bloom, capsule, spring, highlight; `CheckToggle`
  and `AmountControl` subclass it), `UIConfigurationTextAttributesTransformer.cardTitle`.
  `Heatmap.Level.threeQuarters` is now `.mostly` (it runs to just under 100 %). 82 tests
  pass. Left as deliberate: the three `(kind, period)` string tables stay separate switches
  (each is one screen's copy); `summary(for:)` returns a `(value, unit)` tuple; dot row
  geometry (6 pt dots, 10 pt row) is drawing, not spacing, so it is not a §4 token;
  `setHabitTarget` reads the target in force through `HabitRecord` so the series logic has
  one home.
