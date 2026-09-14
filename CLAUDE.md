# Coar

A minimalist personal health tracker for iOS 26: habits, food (calories/protein/fat/carbs),
strength training (exercises, plans, workouts, progression), body weight, progress photos,
plus sleep and steps read from HealthKit. Single user, no accounts; the Apple ID is the
identity. AI features (food photo → macros, a chat coach over the user's data) come later.

## Stack

- Programmatic UIKit shell; SwiftUI for leaf content only (see `DESIGN.md` → Stack).
- Core Data + `NSPersistentCloudKitContainer` for app-authored data (ADR 0002).
- HealthKit for sleep and steps, read live, never persisted in the app store.
- iOS 26 minimum. Units default to lbs. Light and dark mode are both first-class.
- Build with Xcode 26 via `xcodebuild` from the terminal; project files use Xcode
  buildable folders so new source files need no project edits.

## Read before working

- `DESIGN.md`: the design system (tokens, chrome rules, components, viz vocabulary).
  Every screen is checked against it.
- `docs/brief.md`: the product brief (what each tab does, open questions).
- `CONTEXT.md`: the domain glossary. Use its terms; it lists the words to avoid.
- `docs/adr/`: decisions and their reasons.

## Agent skills

### Issue tracker

Local markdown under `.scratch/<feature-slug>/` (no remote yet). See `docs/agents/issue-tracker.md`.

### Triage labels

The five default roles (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`), unchanged. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` at the root and ADRs in `docs/adr/`. See `docs/agents/domain.md`.
