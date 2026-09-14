# 03: Body Weight

**What to build:** From Train, a Body Weight chip opens a screen whose hero is Trend Weight, with a chart of raw daily points and a smoothed trend line, and a log sheet. One Body Weight per Day; logging again replaces it. Stored in kg, displayed in the chosen unit, written to HealthKit (write-only). First real exercise of the Day-keyed, one-per-Day, kg-canonical shapes.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Train root shows a row of three `PillChip`s under a placeholder grid area: Exercises, Body Weight, Progress Photos (only Body Weight is live in this ticket)
- [ ] Weight screen: hero number is Trend Weight (or the raw value with a `—` trend caption when fewer than 2 points), Swift Charts line hosted per ADR 0001 with raw points and trend, no gridlines, bloom on last point
- [ ] Log sheet accepts a weight in the display unit; saves kg; logging on a Day that already has a value replaces it
- [ ] Each Body Weight is written to HealthKit as a body-mass sample; nothing is read back
- [ ] Empty state shows `—` in the hero slot; the card does not collapse
- [ ] Tests (façade): Day-keying — a write at 23:30 in one zone reads back with the same Day in another; one-per-Day replace; kg stored when lbs entered
- [ ] Tests (pure): Trend Weight smoothing on a fixed series, and <2 points yields no trend
