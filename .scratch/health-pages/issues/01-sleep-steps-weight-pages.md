# 01: Fuller Sleep, Steps, and Body Weight pages

**What to build:** John (2026-10-14): "anything else we can add to the sleep, steps, and
weight pages? they are very simple right now" → "you can go ahead and add all of those".

**Status:** done

Weight
- [x] Weigh-ins card (latest five) and an All weigh-ins list; tap opens the log sheet, which
      now has a Day and Delete weigh-in; swipe to delete in the list; Undo on a glass toast
- [x] Rate a week from Trend Weight over four weeks (`TrendWeight.weeklyRate`)
- [x] 1M / 3M / 1Y / All range
- [x] Goal Weight (new `GoalWeight` entity, deduped to one) with "to go · around <date> at
      this pace" (`TrendWeight.progress`) and a dashed rule on the chart

Sleep
- [x] Night card: bedtime – wake time, Time Asleep, stages bar (`SleepNight.detail`)
- [x] Usual times: asleep around / up around ± spread over 14 nights (`SleepPattern`)
- [x] Target rule on the chart and "Met 5 of the last 7 nights · 3 in a row"
- [x] Tap a bar to see that night

Steps
- [x] Target rule and "Met 18 of the last 30 days · 4 in a row"
- [x] Last 7 days against the week before (`HealthSummary.week`)
- [x] By hour for today or the tapped Day (`HealthReader.hourlySteps`)

Also: `-FakeHealthData` debug reader, a longer `-SeedSampleData` weight history, tests (17).

## Comments

- 2026-10-14 (agent): Checked in the simulator with fake Health data. Left as deliberate:
  - **The sleep and steps target is your tracked Habit's**, not a new setting: one number
    in one place. With none, Set a target opens New Habit on that metric. Only an "at
    least" Habit counts; the first one in your order wins.
  - **Goal Weight is a new iCloud record type** (`GoalWeight`), so this build needs a
    CloudKit schema deploy before upload. Set on the page with a stock alert.
  - **The goal line only shows when the chart's axis reaches it**, so a far goal doesn't
    flatten a month of data; the Progress card always says how far it is.
  - **Rate needs two weeks** of weigh-ins and looks back four; it follows Trend Weight.
  - **"Around <date>"** goes by the current rate; heading away or flat says so instead;
    within a quarter kilo counts as reached. Past two years says "more than two years".
  - **Usual times use the main sleep** (spans under an hour apart are one sleep; the
    longest wins), so a nap doesn't move bedtime. They need 3 nights of the last 14.
  - **Stages show only when recorded** (Apple Watch); an iPhone-only night says so.
  - **Steps' week and target leave out today**, which isn't over; Sleep's include last night.
  - **Deleting a weigh-in also removes Coar's sample from Apple Health**; a scale's own
    reading stays (HealthKit only lets an app delete its own).
  - The first weigh-in written after a fresh install shows Apple's Health prompt; the
    screen now updates before that, not after.
