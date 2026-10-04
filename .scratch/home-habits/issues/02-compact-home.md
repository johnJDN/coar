# 02: Compact Home on one screen

**What to build:** Mock A from 2026-10-03, with nutrition first. The macros card becomes a
calorie `StatRing` (kcal left, or over, as the hero) beside a labelled bar each for protein,
fat, and carbs. The habits card shows "3 of 7 done" in its header and lists only check-in
Habits still to do; done ones hide behind Show done / Hide done, and a checked row fades
out once its control settles. The four squares become one row of compact tiles: Sleep,
Steps, Weight (Trend Weight), and Training (workout days this week, "1/3" against the weekly
workouts Habit). Last Workout is gone.

**Blocked by:** 01

**Status:** done

- [x] `HomeSnapshot`: macros as ring + bars, habits as to-do / done, four `HomeTile`s
- [x] `StatRing` (DESIGN.md §7, now built), `MacroRingSummary`, `HomeTileControl`, `CardView` detail slot and compact form
- [x] Habits card: Show done / Hide done, in place, animated with the screen
- [x] `DotMatrix`, `MacroDots` and the squares removed; DESIGN.md and the brief updated
- [x] Tests: the snapshot's empty forms, a day of records, over target, training against the habit

## Comments

- 2026-10-03 (agent): Implemented and checked in the simulator, light and dark, with
  `-SeedSampleData`: everything fits above the tab bar; checking Run fades it out and the
  card shrinks; Show 2 done brings both back with Hide done.
  Left as deliberate:
  - Show done is remembered only while the app runs; it starts hidden each launch.
  - Weight is the Trend Weight number with the unit as its caption; the "Sep 15 · Trend —"
    caption for a single weigh-in is gone (the tile shows the raw value).
  - Training with no weekly workouts Habit shows just the count ("1"); tapping it opens
    Train's root, not the last Workout.
  - A Health tile with nothing reads "—" with "Connect" in its accent while Apple Health
    was never asked; tapping it asks. Otherwise "—" with its name, and tapping opens the
    detail.
  - The ring's track is `surfaceSunken` as DESIGN.md says for in-card wells; it is faint
    in dark mode.
