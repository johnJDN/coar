# 14: Home

**What to build:** The finished Home: "Hello John" and today's date as the title; a full-width habits card with inline check-in; a full-width macros `DotMatrix` card against the Target in force (no-target state per `.scratch/data-model/issues/02`); a 2-column grid of Sleep | Steps and Body Weight | Last Workout squares; every tap routes per the spec; nothing collapses when data is missing.

**Blocked by:** 03, 05, 07, 09, 13

**Status:** ready-for-agent

- [ ] Large title "Today, September 13" style with greeting subtitle via `navigationItem.subtitle`; avatar button from 02 present
- [ ] Habits card: `MetricRow` per active habit with `CheckToggle` or amount control; check-ins from here behave exactly as on the Habits tab; card tap opens the Habits tab
- [ ] Macros card: four `DotMatrix` rows in the fixed accents against target-in-force; with no Target, metric numbers with `— target` captions, no dot rows, and a "Set targets" link to Settings; card tap opens Food on today
- [ ] Sleep and Steps squares (from 13) push their details in Home's stack
- [ ] Body Weight square shows Trend Weight (or raw, or `—`); tap switches to Train and pushes the weight screen
- [ ] Last Workout square shows Plan name (or "Workout") and relative Day; tap switches to Train and pushes that Workout; `—` when none
- [ ] Every card has exactly one hero number; none disappear on missing data; verified in light and dark
- [ ] Tests (façade): the Home snapshot model with no Target, no Body Weight, no Workouts, and unauthorised HealthKit (fake) yields the empty forms rather than zeros
