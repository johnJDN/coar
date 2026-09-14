# 13: Sleep and Steps from HealthKit

**What to build:** Last night's time asleep and today's steps, read live from HealthKit and never stored (ADR 0002), each with a 30-day detail screen. A night belongs to the Day you woke; the value sums asleep stages and excludes awake and in-bed, matching the Health app. Missing authorisation shows `No data` with a tap-through.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] A HealthKit reader protocol (sleep for a wake Day, steps for a Day, 30-day series of each) with a live implementation and a test fake; a writer protocol already used by 03 shares the same authorisation flow
- [ ] Home shows two placeholder squares, Sleep and Steps, in a 2-column grid (full Home layout lands in 14); each pushes its detail within Home's stack
- [ ] Sleep detail: one bar per wake Day for 30 Days in `accentTeal`; steps detail: one bar per Day
- [ ] Unauthorised or empty: `No data` in the value slot, card stays; tapping the value slot runs the authorisation prompt
- [ ] Tests (pure, using the fake): night attribution across midnight; core+deep+REM+unspecified summed, awake and in-bed excluded; a nap the same afternoon counts toward that wake Day
