# 01: Home's habits card lists check-in habits only, done at the bottom

**What to build:** Home's habits card drops tracked Habits (their data is already on Home's
Macros card and Sleep / Steps / Last Workout squares, and you can't check them in). It lists
only check-in Habits, still to do first and done at the bottom, each group in the user's
order. A row that becomes done slides to the bottom once its control settles. The hero counts
check-in Habits only. Asked for by John on 2026-10-03, after the card grew to nine rows.

**Status:** done (superseded in part by 02: done habits hide instead of sinking)

- [x] `HomeSnapshot.habits`: tracked Habits left out; done rows after the rest
- [x] Done for Home = checked in today, or a weekly Habit whose week is already met (`HabitCardModel.isWeekMet`)
- [x] The card reorders rows in place with a spring (none with Reduce Motion), so the toggle's own animation isn't cut
- [x] Tests: tracked left out, the order, a met week counting as done, only-tracked caption
- [x] DESIGN.md §11 and the brief updated

## Comments

- 2026-10-03 (agent): Implemented and checked in the simulator with `-SeedSampleData`.
  Run's toggle checks in place, then Run slides under the other done row; unchecking moves it
  back up.
  Left as deliberate:
  - A weekly Habit whose week is already met counts as done (and sinks) even with no
    Check-in today, since nothing is left to do for it this week.
  - With only tracked Habits, the card stays (DESIGN.md §1.5) with `—` and "No check-in
    habits".
  - The move waits 0.3 s, so you see the check land before the row goes.
