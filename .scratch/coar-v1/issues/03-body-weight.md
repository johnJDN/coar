# 03: Body Weight

**What to build:** From Train, a Body Weight chip opens a screen whose hero is Trend Weight, with a chart of raw daily points and a smoothed trend line, and a log sheet. One Body Weight per Day; logging again replaces it. Stored in kg, displayed in the chosen unit, written to HealthKit (write-only). First real exercise of the Day-keyed, one-per-Day, kg-canonical shapes.

**Blocked by:** 01

**Status:** done

- [x] Train root shows a row of three `PillChip`s under a placeholder grid area: Exercises, Body Weight, Progress Photos (only Body Weight is live in this ticket)
- [x] Weight screen: hero number is Trend Weight (or the raw value with a `—` trend caption when fewer than 2 points), Swift Charts line hosted per ADR 0001 with raw points and trend, no gridlines, bloom on last point
- [x] Log sheet accepts a weight in the display unit; saves kg; logging on a Day that already has a value replaces it
- [x] Each Body Weight is written to HealthKit as a body-mass sample; nothing is read back
- [x] Empty state shows `—` in the hero slot; the card does not collapse
- [x] Tests (façade): Day-keying — a write at 23:30 in one zone reads back with the same Day in another; one-per-Day replace; kg stored when lbs entered
- [x] Tests (pure): Trend Weight smoothing on a fixed series, and <2 points yields no trend

## Comments

- 2026-09-13 (agent): Implemented. Façade: `Store.bodyWeights()` (Day order) beside the
  existing `logBodyWeight(kilograms:on:)` / `bodyWeight(on:)`; the re-log path edits the
  latest-`modifiedAt` row for that Day, so a pre-dedupe duplicate is edited deterministically
  (collapsing duplicates stays with ticket 15). Log path: `BodyWeightLogger` takes the value
  in the display unit, stores kg for today, then writes Apple Health through the
  `BodyWeightWriter` protocol; a Health failure is logged and the record stands.
  `HealthKitAccess` is the writer (hangs off ticket 02's one authorisation flow, prompting on
  first write if never shown); it deletes Coar's own body-mass samples for that Day before
  saving, so Health also holds one per Day; a Body Weight logged today is stamped now, an
  earlier Day gets noon. Trend Weight: exponential smoothing, factor 0.1, gaps not weighted;
  fewer than 2 points is no trend. UI: `TrainViewController` (placeholder grid card + a
  horizontally scrolling glass `PillChipView` row inside a `UIGlassContainerEffect`;
  Exercises and Progress Photos are disabled at 50%), `BodyWeightViewController` (hero +
  caption + hosted `BodyWeightChart`; observes `Preferences.massUnitDidChange`),
  `BodyWeightLogViewController` (medium-detent sheet, one field, prefilled). Body Weight's
  accent is teal (DESIGN.md §3 updated). Verified in the simulator in light and dark: Train
  root, weight screen with 14 points / 1 point / none (card keeps its shape, `—` hero), log
  sheet. Tests: 26 pass via
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test`.
  Notes for the human: (1) the Apple Health write is only exercised through the fake; on a
  device, log a Body Weight, accept the prompt, and check the Health app shows one sample
  for today. (2) The log sheet logs today only; back-dating waits for a ticket that needs it.
