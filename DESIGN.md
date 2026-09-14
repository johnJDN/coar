# Coar Design System

Bevel-inspired surfaces and data-viz vocabulary, iOS 26 Liquid Glass for chrome, and a
minimalist "one hero card per domain" density. Every screen is checked against this doc.

**Stack:** programmatic UIKit (no storyboards, no XIBs) with SwiftUI for leaf content.

- **UIKit owns** every screen, container, list, and interaction: the tab bar, navigation,
  sheets, the accessory bar, `UICollectionView`s (compositional layout + diffable data
  sources), text input, camera, and anything scroll-, layout-, or gesture-heavy (food
  timeline, habit heatmap, live workout logger, date strip, reordering).
- **SwiftUI is used for leaf content only:** Swift Charts, declarative drawing components
  (`StatRing`, `DotMatrix`, sparklines, gauges, bloom), cell/card bodies via
  `UIHostingConfiguration`, the Settings form, and any WidgetKit / watchOS target.
- **Boundary rule:** a hosted SwiftUI view is dumb. Values in, actions out via closures.
  It never owns navigation, never fetches data, and never keeps state UIKit also reads.
- **Tokens are exposed twice:** every colour and font token has a `UIColor`/`UIFont` form
  and a `Color`/`Font` form generated from the same source, so the halves cannot drift.
- Hosting: `UIHostingConfiguration` for cells (self-sizing); `UIHostingController` with
  explicit `sizingOptions` when embedded in a scroll view.

## 1. Principles

1. **Soft, rounded, layered.** No hard edges, no hairline borders, no divider lines.
   Separation comes from surface tone, radius, and shadow/highlight only.
2. **Numbers are the hero.** The biggest, boldest thing on any card is the value.
   Labels are small and gray.
3. **Muted by default, glowing when alive.** Inactive elements are desaturated gray.
   Active/filled elements are saturated and carry a soft bloom.
4. **Same layout in both modes.** Light and dark differ only by token values. Never
   branch layout on color scheme.
5. **Empty is a state, not an error.** Missing data shows a muted dash (`—`, `-%`,
   `No data`) in the exact slot the value would occupy. Cards never disappear or
   collapse because data is missing.
6. **Minimal.** One card per domain on Home: full-width for the two you act on (habits,
   macros), a square in a grid for the ones you only read. If a card doesn't change a
   decision the user makes today, it isn't on Home.

## 2. Chrome: native Liquid Glass (do not rebuild)

| Element | Implementation |
|---|---|
| Tab bar | `UITabBarController` with `UITab` items. `tabBarMinimizeBehavior = .onScrollDown`. |
| Coach / rest-timer bar | `UITabAccessory` assigned to `UITabBarController.bottomAccessory` (Apple Music mini-player slot). Docks above the tab bar; moves inline when the bar minimizes. |
| Page titles | `UINavigationController` with `navigationBar.prefersLargeTitles = true`; native collapse to inline. Subtitle via `navigationItem.subtitle`. |
| Toolbar buttons | `UIBarButtonItem`s; glass is automatic. Adjacent items share one glass group; use `UIBarButtonItemGroup` / fixed spaces to split groups. |
| Custom buttons / chips | `UIButton.Configuration.glass()` (capsule) or `.prominentGlass()`. Arbitrary views: `UIVisualEffectView` with `UIGlassEffect`; group adjacent glass views with `UIGlassContainerEffect`. |
| Sheets | `UISheetPresentationController` with `detents` and `prefersGrabberVisible = true`. |
| "+" quick action | `UIButton` with `.glass()` configuration, `cornerStyle = .capsule`, square so it renders circular, bottom-trailing. Opens a sheet grid of actions. |

Glass may be tinted (`UIGlassEffect.tintColor`, or a button's `baseBackgroundColor`) but
never made opaque. Set `isInteractive = true` on any glass effect the user can tap.

## 3. Color tokens

Defined once in `Coar/Design/Tokens.swift` as dynamic colours (ADR 0001) and exposed as
both `UIColor.<token>` and `Color.<token>`. Values below are eyeballed from Bevel and are
the starting point; tune in-simulator, but keep the *roles* fixed.

### Surfaces

| Token | Dark | Light | Role |
|---|---|---|---|
| `background` | `#0F1115` | `#F3F3F8` | Screen ground. Deep charcoal-navy, never pure black; cool lavender-tinted off-white, never pure white. |
| `surface` | `#1A1D24` | `#FFFFFF` | Standard card. |
| `surfaceRaised` | `#222630` | `#F8F8FC` | Nested/attached panel inside or beneath a card (e.g. insight strip under a stats card). |
| `surfaceSunken` | `#14161B` | `#ECECF2` | Inset wells: gauge tracks, unfilled dots, input fields. |
| `fill` | `#2A2E38` | `#E6E6EE` | Pill fields, secondary buttons, chip backgrounds. |

### Text

| Token | Dark | Light |
|---|---|---|
| `textPrimary` | `#FFFFFF` | `#111318` |
| `textSecondary` | `#9AA0AA` | `#7C818C` |
| `textTertiary` | `#5A606B` | `#B4B8C2` |

### Accents (same in both modes; light mode lowers glow opacity)

| Token | Hex | Used for |
|---|---|---|
| `accentGreen` | `#4CD48A` | Success, completed set, active status, habit done. |
| `accentAmber` | `#E9B94C` | Gold coin checks, strain-style effort, streak flames. |
| `accentBlue` | `#6F8CFF` | Protein. Also generic "info" progression dot. |
| `accentOrange` | `#F2A83B` | Carbs. |
| `accentPink` | `#F0609C` | Fat. |
| `accentTeal` | `#3FCFC4` | Chest / primary volume. Sleep. Body Weight (chart, chip tile, Settings unit tile). |
| `accentLime` | `#B6E857` | Secondary volume groups. |
| `accentLavender` | `#8C8DF5` | AI / coach. Gradient partner: `#B49CFF`. |
| `accentCoral` | `#E8735A` | Warm CTA (Finish workout), destructive-adjacent. |

Rule: one accent per metric, used consistently everywhere that metric appears
(chart, dot, label, ring). Never reuse protein-blue for anything but protein.

### Settings icon tiles

Pastel rounded squares (radius 8, ~34pt) with a white SF Symbol. One soft color per
row: teal, lavender, orange, yellow, green, blue. Use accent colors at ~85% saturation.

## 4. Shape and spacing

| Token | Value |
|---|---|
| `radiusCard` | 24 |
| `radiusInner` | 16 (pill fields, list rows inside cards, thumbnails) |
| `radiusTile` | 8 (icon tiles) |
| Buttons / chips | Full capsule |
| `spaceEdge` | 20 (screen horizontal margin) |
| `spaceCard` | 16 (between cards) |
| `spaceInner` | 16 (card padding) |
| `spaceTight` | 8 |
| `spaceSection` | 28 (above a section header) |

## 5. Typography (SF Pro, system, no custom fonts)

| Role | Style | Weight | Notes |
|---|---|---|---|
| Page title | `.largeTitle` | bold | e.g. "Today, September 3" |
| Page subtitle | `.subheadline` | regular, `textSecondary` | e.g. "Last 30 days" |
| Section header | `.title2` | semibold | e.g. "Nutrition" |
| Card title | `.headline` | semibold | leading icon optional |
| Hero number | `UIFont.systemFont(ofSize: 40, weight: .bold)` with `.rounded` descriptor design | | monospaced digits |
| Metric number | `.title3` | semibold | colored with metric accent |
| Body | `.body` | regular | |
| Caption / label | `.footnote` | regular, `textSecondary` | |
| Empty value | same style as the value it replaces, `textTertiary` | | `—` |

Styles are `UIFont.TextStyle` names. Build fonts with `UIFont.preferredFont(forTextStyle:)`
plus a weight override, or `UIFontMetrics(forTextStyle:).scaledFont(for:)` for custom sizes,
so every label respects Dynamic Type.

Rounded design (`.rounded`) only for hero numbers and the flip-counter digits.

## 6. Elevation, highlight, glow

- **Cards (dark):** `surface` fill, 1pt inner top highlight `white @ 6%`, shadow
  `black @ 40%`, y 8, blur 24.
- **Cards (light):** `surface` fill, shadow `#8A8AB0 @ 12%`, y 8, blur 24. No highlight.
- **Bloom:** filled dots, active chart points, ring end-caps get a second shadow in the
  accent color, `@ 55%` dark / `@ 30%` light, blur 8–12. Never bloom text.
- **Stacked panel:** a `surfaceRaised` strip attached to the bottom of a card shares the
  card's outer radius and has a faint lavender top glow (`accentLavender @ 10%`, blur 20).

## 7. Components

| Component | Description |
|---|---|
| `Card` | `surface` container, `radiusCard`, `spaceInner` padding, elevation above. Optional header row: icon + title + trailing `→` (navigates) or chevron (expands). |
| `StatRing` | Circular gauge. `surfaceSunken` track, accent arc, rounded caps, bloom on cap. Center: hero number; below: label. Hatched arc segment for projected/estimated portion. |
| `DotMatrix` | Grid of dots, one per unit (e.g. 5 g). Filled dots in metric accent with bloom, unfilled in `surfaceSunken`. Header: icon + value in accent. |
| `HeroCounter` | Large flip-style digits in individual `fill` boxes, unit label trailing. |
| `MetricRow` | Leading emoji or tinted icon, label, trailing value (`textSecondary`), optional square `→` button. Used for habits and journal-style entries. |
| `CheckToggle` | Two-state `— / ✓` capsule. Used for yes/no habit check-ins; there is no recorded "miss", an empty day is the miss. |
| `AmountControl` | Capsule showing today's total for a quantitative habit: `—` on `fill` when nothing has been entered, the amount on `fill` while short of the target, `accentGreen` with bloom once met. Tapping opens the number sheet (hero field, target beside it, `+N` glass chips). |
| `PillChip` | Capsule with leading icon tile, title, subtitle, trailing chevron. Glass when floating, `fill` when in-card. |
| `SetRow` | `[set #] [weight lbs] [reps] [✓]` — four pills in `fill`. Completed: all pills and text flood `accentGreen` at 18% fill / 100% text. |
| `ExerciseCard` | Thumbnail, name, "Equipment • n sets", timer + more buttons; `SetRow` list; footer split actions "Progression | Add Set". Superset link icon between cards. |
| `ListRow` (sheet) | Thumbnail, title, subtitle "310 kcal • 1 burger", trailing square `+` button. |
| `IconTile` | Pastel rounded square with white symbol (settings). |
| `EmptyValue` | `—` / `-%` / `No data` in `textTertiary`, same size as the value it stands in for. |
| `SegmentedTabs` | Text tabs with an underline indicator (e.g. Foods / Meals) at the top of sheets. |
| `ActionGrid` | 3×3 grid of circular `fill` buttons with labels, in a sheet, opened by the "+" button. |

## 8. Data-viz vocabulary

| Need | Use |
|---|---|
| Daily score / progress to goal | `StatRing` |
| Macro consumed vs target | `DotMatrix` (one per macro, colors fixed) where it is the hero (Home). A thin bar per macro where it is a compact header over other content (Food tab summary row). Same accents either way. |
| Streaks / consistency over weeks | Calendar heatmap, `surfaceSunken` cells, accent intensity by count |
| Trend over time | Swift Charts line hosted in a `UIHostingController`, 2pt stroke in accent, bloom on last point, no gridlines, axis labels in `textTertiary` |
| Distribution across categories | Radial sector chart (volume by muscle group) |
| Single total for a period | `HeroCounter` |
| Rest timer / in-progress | Mini-player bar in the bottom accessory slot |

Charts never show a legend when color already maps to a label on screen.

## 9. Motion

- Standard: `UIView.animate(springDuration: 0.4, bounce: 0.15)` for state toggles (set complete, habit check).
- Content transitions: `UIView.animate(springDuration: 0.5, bounce: 0)` for layout; number changes cross-dissolve via `UIView.transition(with:duration:options: .transitionCrossDissolve)`. `HeroCounter` uses its own rolling-digit animation.
- Diffable data source updates always animate (`apply(_, animatingDifferences: true)`).
- Bloom appears with a 200 ms fade, never pops.
- No bounce on sheets; native.

## 10. Do / Don't

- **Do** use SF Symbols; **do** use emoji as the leading icon for user-created habits.
- **Don't** draw borders, dividers, or cell separators (`showsSeparators = false` on list layouts; `separatorStyle = .none` on any table view).
- **Don't** use pure `#000000` or `#FFFFFF` for backgrounds.
- **Don't** put more than one hero number on a Home card.
- **Don't** add weather, stress, biology, referrals, paywalls, or any card that is not
  one of: sleep, steps, weight, macros, habits, training.
- **Don't** rebuild the tab bar, navigation bar, or sheets.

## 11. Screen map (settled 2026-09-13)

- **Home** — date title, then top to bottom: habits checklist (full-width, `MetricRow` +
  `CheckToggle`, taps go to Habits), today's macros (full-width `DotMatrix`, taps go to
  Food), a 2-column grid of squares: Sleep | Steps (push a 30-day detail in Home's own
  stack), Body Weight | Last Workout (switch to Train and push the screen).
- **Habits** — one card per habit: emoji, name, `CheckToggle` or amount, streak as the
  hero number, 7-row heatmap (Monday on top; yes/no cells binary, quantitative cells by
  intensity; weekly habits get a week-met dot per column). Detail page has a calendar
  for retroactive edits. Archived habits in a section at the bottom.
- **Food** — day view, macro summary, hourly timeline of entries, "+" sheet with Foods /
  Meals segments (Search is added only when a food database exists).
- **Train** — root: month grid of workout days → Start (from a Plan or empty) → Plans
  → Recent workouts; a row of three `PillChip`s under the grid pushes Exercises, Body
  Weight, and Progress Photos. Live logging with `ExerciseCard`s (supersets linked, no
  auto-advance) and the rest-timer accessory bar (auto-starts on set completion; after
  the last exercise of a superset group). Exercise detail: estimated-1RM progression
  chart plus recent sets.
- **Coach** — lives in the bottom accessory bar, not a tab (future).
- **Settings** — sheet from avatar button: targets, units (lbs default), HealthKit
  access. iCloud is always on and shown as read-only status at most.
