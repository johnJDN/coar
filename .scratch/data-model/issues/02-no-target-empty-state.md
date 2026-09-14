# "No target yet" is an explicit empty state, not a zero

Status: ready-for-agent

A fresh install has no macro Target, and DESIGN.md principle 5 says empty is a state:
the value shows, the missing part shows `—` in the slot it would occupy, nothing
collapses. Today's docs assume a Target always exists. Specify each surface:

- **Home macro card (`DotMatrix`)**: a `DotMatrix` needs a total to draw. With no
  Target, show consumed values as metric numbers with `— target` captions and no dot
  rows; a "Set targets" link opens Settings. Never render a matrix against an implied 0.
- **Food summary row (thin bars)**: `1,240 / —` per macro, bar track drawn, no fill.
- **Target series lookup**: "target in force on Day D" returns nil when the series is
  empty or D precedes the first effective-from date; callers must handle nil, never
  substitute 0. A day before the first target renders as no-target, not as 0% of it.
- **Habits**: not applicable; a Habit's target is required at creation.
- **Trend Weight**: with fewer than 2 Body Weights, hero shows the raw value and the
  trend caption is `—`.
- **Progression**: a single Workout renders one bloomed point, no line.
- **Sleep / Steps with HealthKit not authorised**: `No data` in the value slot and a
  tap-through to authorise; the card stays.
