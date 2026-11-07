# 02: Walks on the Train calendar

**What to build:** John wants walking workouts on the Train calendar, looking different from
lifts. Every walk the Watch recorded, indoors or out, rings its Day in `accentAmber`; lifting
Days stay filled `accentGreen`, and a Day with both is green with the ring.

**Status:** done

- [x] `MonthCalendarView`: `ringedDays`, `ringDescription` (VoiceOver), `shownMonth`,
      `onMonthChange`
- [x] `CalendarWalks`: walks by Day (not those linked to a Workout), and what a tap opens
- [x] Train reads the shown month's walks quietly, on appear and on changing month
- [x] Tapping: one walk opens its note; one Workout opens it; several open the Day's list; an
      empty Day offers to log a past Workout
- [x] The Day's list shows walks too (`WalkCardControl`), in time order
- [x] The note shows treadmill numbers for indoor walks only; an outdoor walk gets the inhaler
- [x] Tests (2)

## Comments

- 2026-11-06 (agent): Left as deliberate: a walk linked to a Workout isn't ringed, since it is
  that Workout (as on the Day page); walks don't count toward a workout-days Habit, and the
  Walks page stays indoor only; a walk-only Day no longer offers to log a past Workout from the
  calendar (Log past workout under Recent workouts still does); with no Health access no rings
  show, and Train doesn't prompt for it. No new fields, so no CloudKit deploy.
