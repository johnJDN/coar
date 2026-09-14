# 05: Habits: quantitative, weekly, dated targets

**What to build:** Quantitative habits ("20 pages a day") with a number sheet and quick-add chips that edit the single day's Check-in; week-period habits ("gym 3× a week") with week-met dots above the heatmap columns, weekly streaks, and a "2 of 3 this week" caption; and target + period as a dated change so raising a target never repaints history (ADR 0003).

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] Kind selector (yes/no | quantitative) and period selector (day | week) on the new-habit sheet
- [ ] Quantitative card control shows today's total; tapping opens a compact sheet with the total, a number pad, and `+N` chips; every path sets the one Check-in's amount (replace semantics)
- [ ] Quantitative cells colour by amount ÷ target-in-force in four buckets (≤25, ≤50, ≤75, ≥100 %); yes/no cells stay binary regardless of period
- [ ] Weekly habits: a `DotMatrix`-style dot per column, filled when that Monday–Sunday week met target; daily habits have no dot row
- [ ] Streak in the habit's period unit ("4 weeks"); current week counts once met, breaks only after Sunday unmet; weekly caption "2 of 3 this week"
- [ ] Detail page edits target amount and period together as a new dated record effective today; past Days render against the record in force then; a Day before the first record renders empty
- [ ] Tests (pure): bucket boundaries; weekly streak with pending-week rule; period switch day→week yields a clean seam in streak computation
- [ ] Tests (façade): target-in-force per Day for a Habit; nil before first record
