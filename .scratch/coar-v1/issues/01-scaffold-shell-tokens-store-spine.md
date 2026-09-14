# 01: Scaffold: project, shell, tokens, store spine

**What to build:** The app launches to four Liquid Glass tabs — Home, Habits, Food, Train — each an empty screen with a large title, correct in light and dark, and a test target that proves the store and a rule function can be exercised without CloudKit. This is the one foundation ticket; every later ticket is a vertical slice on top of it. Respect ADR 0001 (programmatic UIKit, SwiftUI leaf-only), ADR 0002 (CloudKit-safe model), ADR 0004 (kg canonical), ADR 0005 (Day-keyed dates).

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] Xcode 26 project using buildable folders builds from `xcodebuild` with no project edits needed for new files; iOS 26 minimum
- [ ] `UITabBarController` with four `UITab`s, `tabBarMinimizeBehavior = .onScrollDown`; each tab a `UINavigationController` with large titles; no storyboards or XIBs
- [ ] Colour and font tokens from `DESIGN.md` §3–§5 defined once and exposed in both `UIColor`/`UIFont` and `Color`/`Font` forms; the four tab screens use `background` and render correctly in both modes
- [ ] `Card` component per `DESIGN.md` §7 with the §6 elevation, shown once on Home as a placeholder
- [ ] Core Data model + `NSPersistentCloudKitContainer` wired to the private database with every attribute optional/defaulted, every relationship optional with inverse, no unique constraints, no ordered relationships
- [ ] An in-memory container variant using the same model for tests
- [ ] A store façade type through which all reads/writes go; view controllers never touch a managed object context
- [ ] `modifiedAt` set by the façade on every write; a `Day` value type (local calendar day, never recomputed); kg↔lbs conversion with one-decimal display rounding
- [ ] Test target: one façade test against the in-memory container and one pure-function test (kg↔lbs round-trip) pass via `xcodebuild test`
