# 06: Food: Items, Servings, Entries, timeline

**What to build:** The Food tab: a horizontally scrolling week date strip, a vertical hourly timeline with a "+" per hour, and Entries placed at their time. Create Food Items with one or more named Servings (macros, optional grams, one default); the "+" sheet's Foods segment filters your catalogue as you type and has a New food action; log an Entry as Serving × quantity. Entries snapshot everything (ADR 0003) and store an instant plus their Day (ADR 0005). Archive, don't delete.

**Blocked by:** 01

**Status:** ready-for-human

- [x] Week strip (day number over weekday, today marked) scrolls through history; selecting a day loads its timeline
- [x] Hourly timeline as a compositional `UICollectionView`; "+" per hour slot pre-fills that hour's time on the new Entry
- [x] Food Item editor: name; Servings list with name, calories/protein/fat/carbs, optional grams, default marker, reorder
- [x] "+" sheet with `SegmentedTabs` Foods / Meals (Meals segment present but empty until 07), type-to-filter over active Food Items, New food action; no Search segment
- [x] Logging picks a Serving and a quantity and creates an Entry at the chosen time carrying name, Serving name, quantity, and the four macros; optional reference to the Food Item
- [x] Entry detail edits time, quantity, and the snapshotted macros; delete removes only the Entry
- [x] Archive Food Item: hidden from the sheet, existing Entries unchanged
- [x] Tests (façade): editing a Food Item's Serving macros leaves prior Entries unchanged; Entry Day matches the local Day at write time regardless of read zone; archived items absent from the picker query

## Comments

- 2026-09-15 (agent): Implemented. Model: `FoodItem`, `Serving`, and `Entry` gained an
  optional `id: UUID` (additive, CloudKit-safe, as `Habit` did). Façade (`Store+Food.swift`):
  `createFoodItem(name:servings:)` / `updateFoodItem(_:name:servings:)` take `[ServingDraft]`
  and sync Servings by id (update, insert, delete the ones left out; exactly one default: the
  first flagged, else the first); `foodItems()` (active, by name, case-insensitive),
  `archivedFoodItems()`, `foodItem(_:)`, `archiveFoodItem`, `restoreFoodItem`;
  `logEntry(foodItem:serving:quantity:at:in:)` snapshots name, Serving name, quantity, and the
  macros for the whole quantity (ADR 0003) and stores the local Day of the instant in the
  given calendar at write time (ADR 0005); `entries(on:)`, `entry(_:)`,
  `updateEntry(_:loggedAt:quantity:macros:)` (the Day never changes), `deleteEntry`. Records:
  `FoodItemRecord` (with `defaultServing`), `ServingRecord`, `ServingDraft`, `EntryRecord`.
  Pure rules: `EntryDraft` (changing the quantity scales the snapshotted macros to keep the
  per-one values; an emptied field remembers the last valid quantity; a macro typed sets as
  typed, empty is 0, negative is unsaveable), `FoodItemDraft` (upsert / remove / reorder keep
  one default), `FoodText` (amounts, "2 × 1 egg", "140 kcal", "70 kcal • 1 egg"). UI:
  `FoodViewController` (large title "Food" with the selected Day as the subtitle, `+` at the
  current time of day) with `WeekStripView` (one Monday–Sunday week per page, 104 weeks of
  history, today's number green with a dot, selected Day on a `fill` well, future Days muted
  and inert) and a compositional timeline whose 24 sections are the hours: `TimelineHourView`
  (hour in `textTertiary`, a dot on the rail that lights `accentGreen` with bloom when the hour
  has Entries, a `fill` "+" that pre-fills that hour) and `EntryCell` (name, "3 × 1 egg · P 18
  · F 15 · C 0" with the letters in their accents, calories as the metric number, `surface`
  card with the §6 elevation). `SegmentedTabsView` (new `Design/` component per §7).
  `AddEntryViewController` (the "+" sheet: Foods / Meals tabs, a filter field, `ListRow`s with
  the default Serving's "70 kcal • 1 egg" and a square "+" that logs it once and closes; a
  "New food" row; long-press menu Edit / Archive; Meals shows "No meals yet" until 07).
  `LogFoodViewController` + `LogFoodForm` (inline Serving picker with kcal, quantity, time, and
  a read-only preview of the four macros the Entry will carry; `…` menu Edit / Archive).
  `FoodItemEditorViewController` (UIKit list: name field, Serving rows with the default
  checkmark and a drag handle to reorder, swipe to delete, tap to edit, Add serving) pushing
  `ServingFormViewController` + `ServingForm` (name, optional grams, four macros for one,
  Default toggle). `EntryDetailViewController` + `EntryForm` (quantity, time-of-day, the four
  snapshotted macros, Delete entry with confirmation). Verified through a throwaway
  screenshot test (since removed) in light and dark: the tab with four Entries, the "+" sheet,
  the log page, the editor, the Serving form, the Entry detail. 103 tests pass via
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test`.
  Left as deliberate, please confirm: (1) the timeline shows all 24 hours from 12 AM with no
  auto-scroll; empty hours are compact rows. (2) An hour's "+" pre-fills hh:00; the toolbar
  "+" pre-fills the current time of day on the selected Day. (3) The log page previews the
  macros but does not edit them; macros are corrected on the Entry detail after logging, so
  the façade, not the form, does the snapshot. (4) An Entry's stored macros are for the whole
  quantity; on the detail, changing the quantity scales them and editing a field sets it as
  typed. (5) The detail edits the time of day only; the Entry's Day never changes, and the
  timeline places an Entry by its instant in the current calendar. (6) Archived Food Items
  show only under a matching filter, dimmed, and a tap offers Restore; there is no Archived
  section. (7) Archive (row long-press menu, or the log page's `…`) does not confirm, being
  reversible; Delete entry does. (8) The row's square "+" logs the default Serving × 1 at the
  sheet's time and closes the sheet. (9) Saving a new Food Item goes straight to logging it.
  (10) Food Items list by name; there is no manual order. (11) A Serving's empty macro field
  means 0; grams are optional; exactly one Serving is the default (the editor's toggle moves
  it; removing the default promotes the first). (12) The strip's "today" is fixed when the tab
  is created. (13) The rail is a `fill` bar with hour dots, read as a timeline axis rather
  than a divider (§1.1). (14) The sheet is titled "Add Entry" (CONTEXT.md's term).

