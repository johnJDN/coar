# 04: Habits: yes/no, daily

**What to build:** Create a yes/no daily habit (emoji, name); the Habits tab shows one card per habit with a `CheckToggle`, the streak as hero number, and a 7-row Monday-top heatmap with binary cells; tap into a detail page with a calendar to fix past days; reorder; archive rather than delete. Establishes the Habit/Check-in/Streak vocabulary from `CONTEXT.md`.

**Blocked by:** 01

**Status:** done

- [x] New-habit sheet: emoji (system keyboard), name, target amount, period; this ticket only needs target 1 / day but the fields exist
- [x] Habit card: emoji, name, `CheckToggle` (two states, no recorded miss), streak hero ("12 days"), heatmap in a `UICollectionView`: 7 rows Monday on top, ~26 columns, `surfaceSunken` empty cells, `accentGreen` done cells with bloom
- [x] Toggling on creates the day's Check-in (amount 1); toggling off deletes it; at most one Check-in per Habit per Day
- [x] Detail page with a month calendar; tapping a past day toggles that day's Check-in
- [x] Manual reorder persists via `sortOrder`
- [x] Archive from detail; an Archived section at the bottom of the tab with Restore and Delete permanently (cascades Check-ins)
- [x] Tests (façade): check-in create/replace/delete per Day; archived habits absent from the active list; delete-permanently removes Check-ins
- [x] Tests (pure): streak counts consecutive Days; today counts once met and does not break the streak until it ends unmet; a gap resets

## Comments

- 2026-09-13 (agent): Implemented. Façade (`Store+Habits.swift`): `createHabit` (writes the
  Habit at the end of the list plus its first dated target), `habits()` / `archivedHabits()`
  in `sortOrder`, `habit(_:)`, `reorderHabits(_:)`, `archiveHabit` / `restoreHabit` /
  `deleteHabitPermanently` (Core Data cascade takes the Check-ins and targets), and
  `checkIn(_:on:amount:)` (one per Habit per Day, writes replace the latest-`modifiedAt`
  row), `removeCheckIn`, `checkIn(_:on:)`, `checkIns(for:)`. Records: `HabitRecord`
  (with the target in force today), `HabitTargetRecord`, `CheckInRecord`; enums `HabitKind`,
  `HabitPeriod`. Pure rules: `Streak.days(met:today:)` (today counts once met, does not
  break until it ends unmet) and `Heatmap.cells(endingOn:columns:met:)` (column-major,
  Monday on top, last column is the current week, Days after today are `.future`); `Day`
  grew `advanced(by:)`, `weekday` (ISO), `startOfWeek`, `daysInMonth` on a fixed UTC
  Gregorian calendar. UI: `HabitsViewController` (compositional layout + diffable data
  source; sections active / Archived / empty; long-press to reorder, clamped to the active
  section), `HabitCardCell` (emoji, name, `CheckToggleView`, streak hero + unit, `HeatmapView`
  as a nested non-interactive `UICollectionView` with 26 columns, bloom fades in over
  200 ms), `ArchivedHabitCell` (Restore, Delete permanently with an action-sheet confirm),
  `HabitFormViewController` hosting `HabitForm` (emoji field forces the emoji keyboard and
  keeps one character, name, amount, Day | Week period; Save enabled when complete),
  `HabitDetailViewController` (streak card + `MonthCalendarView`; tapping a Day up to today
  toggles its Check-in; Archive in the `…` menu pops back). Verified in the simulator in
  light and dark: tab with three cards + Archived row, toggle on/off, detail calendar, form,
  empty state. Tests: 51 pass via
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test`.
  Left as deliberate, please confirm: (1) `Habit` gained an optional `id: UUID` attribute
  (additive, CloudKit-safe) because screens need a stable identity for a Habit and Body
  Weight's Day key does not carry over; the diffable data source keys on it. (2) The
  new-habit sheet stores a Week period and any whole target amount, but this ticket renders
  every Habit daily (streak in days, unit "days", binary cells); ticket 05 makes Week and
  amounts mean something. (3) A streak of 0 shows as a muted "0 days", not `—`: zero is a
  value, not missing data. (4) Archive does not confirm (it is reversible); Delete
  permanently does. (5) `Store.context` and `Store.save()` went from private to internal so
  `Store+Habits.swift` can live in its own file; "view controllers never touch a context" is
  now by convention (nothing outside `Store+*` uses them). (6) Reorder is long-press
  interactive movement rather than an Edit mode. (7) The detail title is inline "emoji
  name"; no large title on a pushed detail. (8) Restore puts the Habit at the end of the
  active list: its old slot has been renumbered away.
- 2026-09-13 (agent, after /code-review): today's calendar number now scales with Dynamic
  Type (`UIFontMetrics`, DESIGN.md §5); the streak unit is always days here rather than
  echoing a stored Week period (spec story 23 would have read "3 weeks" for 3 days); Restore
  lands at the end of the list with a test; the detail pops itself in `viewDidAppear` when
  the Habit is gone, never mid-transition; `HabitCardCell` resets its streak on reuse so a
  recycled cell does not cross-dissolve from another Habit's number; the long-press cancel
  no longer sets `state` (subclass-only API); future calendar Days no longer highlight.
  Duplication pulled out: `BloomView` (the one §6 bloom, used by the toggle, heatmap cells,
  and calendar days), `CardCell` (a card pinned in a cell; `HabitCardCell`,
  `ArchivedHabitCell`, `EmptyStateCell` subclass it), `StreakHeroView` (card and detail),
  `apply(reconfiguringExisting:)` on the diffable data source, `SectionHeaderView` moved to
  `Design/`. `HabitRecord.meets(amount:)` is the one place ticket 05 changes the "met" rule;
  `Heatmap.columns` replaces the view-owned constant. `CardView` takes an `iconTint` so the
  Streak flame is `accentAmber` (§3). `DayTests` covers leap day, year end, ISO weekday,
  start of week, days in month. 56 tests pass. Left as deliberate: `visibleMonth` stays a
  `(year, month)` tuple inside `MonthCalendarView` (one private user; a `Month` type can come
  when a second screen needs one); `formRow()` shared with Settings (the same row style, one
  definition).
