# 14: Home

**What to build:** The finished Home: "Hello John" and today's date as the title; a full-width habits card with inline check-in; a full-width macros `DotMatrix` card against the Target in force (no-target state per `.scratch/data-model/issues/02`); a 2-column grid of Sleep | Steps and Body Weight | Last Workout squares; every tap routes per the spec; nothing collapses when data is missing.

**Blocked by:** 03, 05, 07, 09, 13

**Status:** done

- [x] Large title "Today, September 13" style with greeting subtitle via `navigationItem.subtitle`; avatar button from 02 present
- [x] Habits card: `MetricRow` per active habit with `CheckToggle` or amount control; check-ins from here behave exactly as on the Habits tab; card tap opens the Habits tab
- [x] Macros card: four `DotMatrix` rows in the fixed accents against target-in-force; with no Target, metric numbers with `— target` captions, no dot rows, and a "Set targets" link to Settings; card tap opens Food on today
- [x] Sleep and Steps squares (from 13) push their details in Home's stack
- [x] Body Weight square shows Trend Weight (or raw, or `—`); tap switches to Train and pushes the weight screen
- [x] Last Workout square shows Plan name (or "Workout") and relative Day; tap switches to Train and pushes that Workout; `—` when none
- [x] Every card has exactly one hero number; none disappear on missing data; verified in light and dark
- [x] Tests (façade): the Home snapshot model with no Target, no Body Weight, no Workouts, and unauthorised HealthKit (fake) yields the empty forms rather than zeros

## Comments

- 2026-09-16 (agent): Implemented. Model: `HomeSnapshot` (façade + `HealthReader` in, display
  forms out) is the one read for the screen: `habits` (a `HabitCardModel` per active Habit,
  the done count as the hero, `—` with none), `macros` (a `MacroRow` per macro with
  `MacroDots` against the Target in force; `— target` and no dots without one), and one
  `HomeSquare` each for Sleep, Steps, Body Weight (Trend Weight, raw with "Sep 15 · Trend —"
  for one point, `—` with none), and Last Workout (relative Day as the hero, Plan name or
  "Workout" as the caption, `—` with none). Rule: `MacroDots` (pure) draws one dot per 5 g or
  50 kcal, stepping to a coarser unit past two rows of 24; filled by what was eaten, every
  dot once over. UI: `Coar/Home/` holds `HomeViewController` (moved from Shell), the
  `HabitsCardControl` (`MetricRow` + `CheckToggle` / `AmountControl` per Habit, writing
  through the same façade calls as the Habits tab, now `Store.setCheckedIn`), the
  `MacrosCardControl` (hero calories, metric numbers in accent, hosted `DotMatrix` rows, an
  in-card Set targets capsule that opens Settings), and `HomeSquareControl` (the ticket 13
  `HealthSquareControl` made generic). New Design components: `MetricRowView` and the SwiftUI
  `DotMatrix`. Routing: `RootTabBarController.select(_:)` hands a tab's stack to Home, which
  pops to the Habits root, pops Food to its root and calls `showToday()` (the week strip
  gained `select(_:)`), or pops Train to its root and pushes Body Weight or the Workout's
  screen (logger while active, detail once finished). Title "Today, September 16" with the
  greeting subtitle "Good evening, John", refreshed on the significant-time-change
  notification; the unit change re-renders the Body Weight square. Verified in the simulator
  in light and dark, at narrow (iPhone 17) and wide (Pro Max) widths and at an accessibility
  text size, with a `-SeedSampleData` debug launch argument (`DebugSeed`, in-memory store,
  never CloudKit) and empty. Tests: 6 pure (`MacroDotsTests`) + 5 through the façade with the
  Health fake (`HomeSnapshotTests`, including the ticket's all-empty case), suite green via
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test`.
  Notes for the human: the name in the greeting is a constant (`HomeText.name`), since the
  spec keeps a name field out of v1; the native large title truncates at accessibility text
  sizes (UIKit never shrinks it). Left as deliberate (see `human-testing.md`): the greeting
  varies by time of day rather than reading "Hello John"; the habits hero is the done count;
  Last Workout is the last finished one (the Active Workout already has the accessory bar);
  its hero is the relative Day and the caption the Plan name; the dot unit ladder; a target
  of 0 for one macro renders that row as no-target; `— target` captions in `textTertiary`;
  card titles shrink to fit in the squares; the Home cards are `UIControl`s so inline controls
  take their own taps and the card takes the rest.
