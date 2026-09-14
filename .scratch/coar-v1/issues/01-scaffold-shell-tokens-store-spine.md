# 01: Scaffold: project, shell, tokens, store spine

**What to build:** The app launches to four Liquid Glass tabs — Home, Habits, Food, Train — each an empty screen with a large title, correct in light and dark, and a test target that proves the store and a rule function can be exercised without CloudKit. This is the one foundation ticket; every later ticket is a vertical slice on top of it. Respect ADR 0001 (programmatic UIKit, SwiftUI leaf-only), ADR 0002 (CloudKit-safe model), ADR 0004 (kg canonical), ADR 0005 (Day-keyed dates).

**Blocked by:** None (can start immediately)

**Status:** ready-for-human

- [x] Xcode 26 project using buildable folders builds from `xcodebuild` with no project edits needed for new files; iOS 26 minimum
- [x] `UITabBarController` with four `UITab`s, `tabBarMinimizeBehavior = .onScrollDown`; each tab a `UINavigationController` with large titles; no storyboards or XIBs
- [x] Colour and font tokens from `DESIGN.md` §3–§5 defined once and exposed in both `UIColor`/`UIFont` and `Color`/`Font` forms; the four tab screens use `background` and render correctly in both modes
- [x] `Card` component per `DESIGN.md` §7 with the §6 elevation, shown once on Home as a placeholder
- [x] Core Data model + `NSPersistentCloudKitContainer` wired to the private database with every attribute optional/defaulted, every relationship optional with inverse, no unique constraints, no ordered relationships
- [x] An in-memory container variant using the same model for tests
- [x] A store façade type through which all reads/writes go; view controllers never touch a managed object context
- [x] `modifiedAt` set by the façade on every write; a `Day` value type (local calendar day, never recomputed); kg↔lbs conversion with one-decimal display rounding
- [x] Test target: one façade test against the in-memory container and one pure-function test (kg↔lbs round-trip) pass via `xcodebuild test`

## Comments

- 2026-09-13 (agent): Implemented. Project is hand-written `Coar.xcodeproj` (objectVersion 77,
  two `PBXFileSystemSynchronizedRootGroup`s: `Coar/`, `CoarTests/`) with a shared `Coar`
  scheme. Build/test from the terminal:
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test`.
  Notes for the human: (1) `DEVELOPMENT_TEAM` is unset; set it in Signing & Capabilities
  before running on a device. The CloudKit container is `iCloud.com.johnnguyen.coar` and
  must exist in the developer account. (2) The Core Data model covers every entity in the
  spec's Implementation Decisions (19 entities) so later tickets add façade methods, not
  schema; schema changes stay additive. (3) The façade exposes only Body Weight log/read in
  this ticket (one-per-Day replace is in the write path; ticket 03 adds its tests and
  HealthKit). (4) Verified in the simulator in light and dark: Liquid Glass tab bar, large
  titles, `background` ground, one `Card` with the §6 elevation on Home.
- 2026-09-13 (agent, after /code-review): fixed the caption token name mismatch (now `label`
  on both sides), `lbs`, `Day(rawValue:)` rejects impossible dates, the unit-test host uses
  the in-memory store so no test run touches CloudKit, removed unused generality
  (`Habit.createdAt`, `Codable`, `CaseIterable`, `startDate`). DESIGN.md §3 now says tokens
  live in `Tokens.swift` (ADR 0001) rather than an asset catalog. Left for ticket 09 to
  decide: `LoggedSet` carries its Planned Set target on the same row rather than a separate
  target-row entity; a separate entity can be added additively if the logger needs it.
