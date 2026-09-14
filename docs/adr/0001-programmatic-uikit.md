# 0001. Programmatic UIKit for the app UI

**Status:** accepted (2026-09-09)

## Context

The app targets iOS 26 only. SwiftUI was the initial choice, and the design doc was
first written against SwiftUI/Liquid Glass APIs. The owner prefers UIKit for its control
and flexibility (custom layouts, fine-grained animation, mature navigation and text
handling, imperative escape hatches everywhere). UIKit on iOS 26 has full Liquid Glass
support (`UITabBarController.tabBarMinimizeBehavior`, `UITabAccessory`, `UIGlassEffect`,
glass `UIButton.Configuration`s), so the chrome plan in `DESIGN.md` survives the switch.

## Decision

The app is built in programmatic UIKit: no storyboards, no XIBs. UIKit owns every screen,
container, list, and interaction. Lists and grids use `UICollectionView` with
compositional layouts and diffable data sources.

SwiftUI is used for **leaf content only**, where it is objectively better or the only
option: Swift Charts, declarative drawing components (rings, dot matrices, sparklines),
cell/card bodies via `UIHostingConfiguration`, the Settings form, and WidgetKit / watchOS
targets. A hosted SwiftUI view takes values in and reports actions out via closures; it
never owns navigation, never fetches data, and never keeps state UIKit also reads.
Design tokens are exposed in both `UIColor`/`UIFont` and `Color`/`Font` forms from one
source.

## Consequences

- More code per screen than SwiftUI, and UI state must be synchronised imperatively
  (diffable snapshots are the mechanism; ad-hoc `reloadData` is not).
- Screens have no SwiftUI previews; leaf components written in SwiftUI do, which is
  where most visual iteration happens.
- SwiftData's `@Query` is unavailable, which drives ADR 0002.
- Design tokens are `UIColor(dynamicProvider:)` / asset-catalog colours and `UIFont`
  helpers; light and dark come from trait collections for free.
- Any future widget or watch surface is a separate SwiftUI target sharing the model
  layer, not the UI layer.
