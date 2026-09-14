# 02: Settings sheet: Targets, units, HealthKit access

**What to build:** An avatar button on Home opens Settings as a sheet holding exactly three things: macro Targets, the weight unit, and HealthKit access. Targets are a dated series — editing creates a new entry effective today, so past days keep the target that applied then (ADR 0003). The unit toggle changes every displayed weight app-wide (ADR 0004).

**Blocked by:** 01

**Status:** done

- [x] Avatar `UIBarButtonItem` on Home presents a `UISheetPresentationController` sheet with grabber; content is a SwiftUI form hosted per ADR 0001
- [x] Targets section edits calories, protein, fat, carbs; saving when values changed creates a new Target effective today; unchanged save creates nothing
- [x] Façade exposes "Target in force on Day" returning nil when no Target applies (empty series, or Day precedes the first effective-from)
- [x] Units row toggles lbs/kg; stored as a preference; a displayed weight anywhere reflects the change immediately
- [x] HealthKit row shows status and triggers the system authorisation prompt
- [x] No iCloud toggle; no name field
- [x] Tests: target-in-force for a Day before/on/after effective dates; nil before first; a change today leaves yesterday's lookup unchanged

## Comments

- 2026-09-13 (agent): Implemented. Façade: `Store.target(inForceOn:)` (nil when the series
  is empty or the Day precedes the first `effectiveFrom`) and `Store.setTarget(_:effectiveFrom:)`
  (default today; writes nothing when the values in force are unchanged; a second edit on the
  same Day replaces that Day's entry rather than starting a second one, a rule the ticket did
  not state but which keeps "one entry per effective-from Day"). Unit: `Preferences.massUnit`
  (UserDefaults, lbs default) posts `Preferences.massUnitDidChange`; nothing displays a weight
  yet, so ticket 03's weight screen must observe it to satisfy "reflects the change
  immediately". Health: `HealthAccess` protocol + `HealthKitAccess` is the one authorisation
  flow (sleep + steps read, Body Weight write, requested together so HealthKit prompts once);
  tickets 03 and 13 should hang their reader/writer off it rather than add a second flow.
  Verified in the simulator in light and dark: avatar button, grabber sheet, icon tiles,
  segmented lbs/kg, Health status row. Notes for the human: (1) the HealthKit entitlement and
  usage strings are added; Xcode's automatic signing must enable the HealthKit capability on
  the App ID before a device build. (2) Tests run with
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test` (14 pass).
- 2026-09-13 (agent, after /code-review): added a `Macro` enum (title, unit, key path) with its
  accent and symbol in one place so the fixed per-metric accents are not re-spelled per
  screen; `MacroTarget.macros` get/set; one `Logger(category:)` subsystem; icon tiles pastel
  by mixing toward white rather than opacity; the Health tile moved into the §3 tile palette
  (green). Left as-is: the "Weight" row label (the unit covers lifted and Body Weight, so the
  unqualified word is intended); `.limited` status names Body Weight sharing before ticket 03
  ships the write, because the permission is already requested.
