# 0005. Day-keyed records store the local calendar day, not an instant

**Status:** accepted (2026-09-13)

Check-ins, Body Weight, Workouts, and Progress Photos are facts about a day the user
lived, so they store the calendar day as it was in the user's time zone when recorded,
and that day is never recomputed. Food Entries need a position on an hourly timeline, so
they store an instant *and* the local day they were logged into. Chosen over "store UTC
and derive the day at read time" because deriving shifts a late-night check-in to the
next day after a flight, which silently rewrites streaks, heatmaps, and daily totals.
This is the time-axis counterpart of ADR 0003.
