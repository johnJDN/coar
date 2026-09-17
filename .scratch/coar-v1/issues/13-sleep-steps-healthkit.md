# 13: Sleep and Steps from HealthKit

**What to build:** Last night's time asleep and today's steps, read live from HealthKit and never stored (ADR 0002), each with a 30-day detail screen. A night belongs to the Day you woke; the value sums asleep stages and excludes awake and in-bed, matching the Health app. Missing authorisation shows `No data` with a tap-through.

**Blocked by:** 01

**Status:** done

- [x] A HealthKit reader protocol (sleep for a wake Day, steps for a Day, 30-day series of each) with a live implementation and a test fake; a writer protocol already used by 03 shares the same authorisation flow
- [x] Home shows two placeholder squares, Sleep and Steps, in a 2-column grid (full Home layout lands in 14); each pushes its detail within Home's stack
- [x] Sleep detail: one bar per wake Day for 30 Days in `accentTeal`; steps detail: one bar per Day
- [x] Unauthorised or empty: `No data` in the value slot, card stays; tapping the value slot runs the authorisation prompt
- [x] Tests (pure, using the fake): night attribution across midnight; core+deep+REM+unspecified summed, awake and in-bed excluded; a nap the same afternoon counts toward that wake Day

## Comments

- 2026-09-16 (agent): Implemented. Reader: `HealthReader` protocol (`timeAsleep(wakingOn:)`
  and `steps(on:)`, each for any `[Day]` with single-Day conveniences; a Day absent from the
  result has no data) with `HealthKitAccess` as the live implementation beside the ticket 03
  writer, so both hang off ticket 02's one authorisation flow; `FakeHealthReader` in tests
  holds samples and step counts and applies the same rule. Rule: `SleepNight` (pure): a
  night's window runs 6 PM the evening before to 6 PM the wake Day (the Health app's sleep
  day), asleep-stage samples (core, deep, REM, unspecified) are clipped to it and summed,
  awake and in-bed are excluded, overlapping spans from two sources count once, no asleep
  sample is nil. Steps come from HealthKit's own cumulative-sum statistics per Day (which
  already merge a watch and a phone). UI: `HealthMetric` (title, symbol, accent, captions,
  text, chart units) drives `HealthSquareControl` (Home's 2-column grid, replacing the
  ticket 01 placeholder card) and `HealthDetailViewController` (hero for the current Day,
  30-day average caption, `DailyBarChart` hosted per ADR 0001; subtitle "Last 30 days").
  `HeroNumberLabel` gained `onTapEmpty`: while the Apple Health prompt has never been shown,
  tapping `No data` runs it (Home and detail); a VoiceOver custom action does the same on the
  square. DESIGN.md: §3 names Sleep and Steps on teal and amber; §8 gains the one-bar-per-Day
  row. Verified in the simulator in light and dark: squares with values and with `No data`
  + "Tap to connect Apple Health", both details with 30 bars (gaps for missing Days, latest
  bar bloomed) and empty. Tests: 11 new (8 through the fake, 3 text), suite green via
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test`.
  Notes for the human: HealthKit never says whether a read was granted, so a denied read
  and an empty night both show `No data`; the detail caption points at the Health app once
  the prompt has been shown. Left as deliberate (see `human-testing.md`): the 6 PM boundary;
  overlap merging; in-bed-only nights are `No data`, not 0; Steps on amber; the value-slot
  tap only prompts while the prompt has never been shown (afterwards the whole square opens
  the detail, since HealthKit would not show it again); past bars muted at 70%; a nap's
  minutes are added to the night it follows; `HealthMetric.read` returns a `Double` for both.
- 2026-09-16 (agent, after /code-review): CONTEXT.md gains Night, Time Asleep, and Steps
  under "Sleep and steps"; ADR 0006 records the 6 PM to 6 PM Night; DESIGN §5 notes the
  half-width square hero may shrink to fit. `HealthMetric` derives its `Color` from the one
  `UIColor` switch (`uiAccent` / `accent`, the `Macro` precedent); `SleepNight.timeAsleep
  (wakingOn: [Day])` is the one per-Day reduction the live reader and the fake share;
  `HealthAccess.connect()` is the one log-and-carry-on prompt call for Home, the detail, and
  Settings; the hero tap's `cancelsTouchesInView` is explicit. Left as deliberate: the rule
  is tested through the fake because the ticket asks for it that way (the fake now holds
  samples and calls the shared reduction, not a copy); the single-Day reader conveniences
  stay because the ticket names them; the detail's card assembly mirrors Body Weight's
  rather than sharing a component (two copies, not three, and ticket 14 may reshape it);
  the caption cascade stays in the screens; after a denial the value slot no longer prompts
  (HealthKit shows the sheet once) and the caption points at the Health app instead.
