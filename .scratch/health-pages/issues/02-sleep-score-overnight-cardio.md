# 02: Sleep Score, overnight readings, and cardio fitness

**What to build:** John (2026-10-15), from the Health app: sleep score, respiratory rate
(sleep), blood oxygen, VO2 max, resting heart rate, Recovery HRV, HRV. "build all of it
including the sleep score".

**Status:** done

- [x] Checked the iOS 27 SDK: every one is readable except Apple's Sleep Score; Recovery HRV
      is `heartRateVariabilityRMSSD` (iOS 27 only)
- [x] Coar's own Sleep Score (`SleepScore`): duration 50, bedtime 30, interruptions 20, on
      the Night card with its parts; `SleepNightDetail` gains interruptions and awake time
- [x] Overnight card (`OvernightVitals`): each reading against the average of up to 30
      earlier nights (needs 5), flagged on the side that matters, one summary line
- [x] Cardio fitness card on Steps: latest VO2 max, change over 3 months, a year's line
- [x] Their own Apple Health ask (`vitalsReadTypes`, "Show overnight readings"), so Home's
      tiles don't go back to Connect; usage text updated
- [x] Fake data for `-FakeHealthData`; tests (6)

## Comments

- 2026-10-15 (agent): Checked in the simulator with fake data (the last night runs hot, so the
  card shows its warning). Left as deliberate:
  - **The score is Coar's, not Apple's** (apps can't read Apple's). Same three parts Apple
    describes; the goal is the Sleep habit's target, else 8h; bedtime is against the usual
    of the 14 nights before (11:30 PM until there are 3). It won't match Apple's number.
  - **Readings are from the main sleep only**; resting heart rate is Apple's daily value.
  - **Only the bad side is flagged**: resting heart rate > usual + 3, HRV and Recovery HRV
    < 80% of usual, breathing > usual + 1/min, blood oxygen > 2 points below usual. When two
    or more are off, the line says it often means poor recovery.
  - **Recovery HRV shows only on iOS 27** and only once the Watch has recorded it.
  - **VO2 max sits on the Steps page** (the Watch measures it on walks and runs), not Train.
  - Nothing is stored; no schema change.
