# 03: A chart for every metric, with ranges and scrubbing

**What to build:** John (2026-10-15): "for all of these, can i view a chart for each of
them, select different time windows, and scrub through them?" → "yes".

**Status:** done

- [x] `MetricHistoryView` / `MetricHistoryViewController`: one page for Time Asleep, Sleep
      Score, Steps, each overnight reading, and VO2 max
- [x] W / M / 6M / Y (`HistoryRange`): daily points for W and M, weekly averages for 6M,
      monthly for Y (`MetricHistory.points`); the hero is the range's average a Day
- [x] Scrubbing with `chartXSelection`: rule, hero shows the point and its dates, haptic
- [x] Usual band behind overnight readings (`MetricHistory.usualBand`)
- [x] Entry points: History on the Sleep and Steps overview, the Sleep Score, each Overnight
      row (chevron), the Cardio fitness card (→)
- [x] Body Weight chart scrubs in place (it already had ranges)
- [x] Tests (5)

## Comments

- 2026-10-15 (agent): Checked in the simulator with fake data: scrubbing Time Asleep shows
  "6h 43m · Thursday, Oct 1"; 6M shows weekly bars; resting heart rate shows the band with
  last night's spike above it; the weight chart scrubs with a capsule. Left as deliberate:
  - **The Sleep and Steps pages' own charts still pick a Day on tap** (it drives the Night
    and By hour cards), so their history is behind a History button rather than the chart.
  - **A year is read once per page open** and grouped per range in memory; longer than a
    year isn't offered.
  - **6M and Y are averages a Day** of the Days with data, as the Health app does.
  - **The usual band is today's usual**, drawn across the whole range, not a moving one.
  - **Weight keeps its own 1M / 3M / 1Y / All** and scrubs in place instead of a new page.
