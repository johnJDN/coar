# 06: Food: Items, Servings, Entries, timeline

**What to build:** The Food tab: a horizontally scrolling week date strip, a vertical hourly timeline with a "+" per hour, and Entries placed at their time. Create Food Items with one or more named Servings (macros, optional grams, one default); the "+" sheet's Foods segment filters your catalogue as you type and has a New food action; log an Entry as Serving × quantity. Entries snapshot everything (ADR 0003) and store an instant plus their Day (ADR 0005). Archive, don't delete.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Week strip (day number over weekday, today marked) scrolls through history; selecting a day loads its timeline
- [ ] Hourly timeline as a compositional `UICollectionView`; "+" per hour slot pre-fills that hour's time on the new Entry
- [ ] Food Item editor: name; Servings list with name, calories/protein/fat/carbs, optional grams, default marker, reorder
- [ ] "+" sheet with `SegmentedTabs` Foods / Meals (Meals segment present but empty until 07), type-to-filter over active Food Items, New food action; no Search segment
- [ ] Logging picks a Serving and a quantity and creates an Entry at the chosen time carrying name, Serving name, quantity, and the four macros; optional reference to the Food Item
- [ ] Entry detail edits time, quantity, and the snapshotted macros; delete removes only the Entry
- [ ] Archive Food Item: hidden from the sheet, existing Entries unchanged
- [ ] Tests (façade): editing a Food Item's Serving macros leaves prior Entries unchanged; Entry Day matches the local Day at write time regardless of read zone; archived items absent from the picker query
