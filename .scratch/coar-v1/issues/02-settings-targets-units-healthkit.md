# 02: Settings sheet: Targets, units, HealthKit access

**What to build:** An avatar button on Home opens Settings as a sheet holding exactly three things: macro Targets, the weight unit, and HealthKit access. Targets are a dated series — editing creates a new entry effective today, so past days keep the target that applied then (ADR 0003). The unit toggle changes every displayed weight app-wide (ADR 0004).

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Avatar `UIBarButtonItem` on Home presents a `UISheetPresentationController` sheet with grabber; content is a SwiftUI form hosted per ADR 0001
- [ ] Targets section edits calories, protein, fat, carbs; saving when values changed creates a new Target effective today; unchanged save creates nothing
- [ ] Façade exposes "Target in force on Day" returning nil when no Target applies (empty series, or Day precedes the first effective-from)
- [ ] Units row toggles lbs/kg; stored as a preference; a displayed weight anywhere reflects the change immediately
- [ ] HealthKit row shows status and triggers the system authorisation prompt
- [ ] No iCloud toggle; no name field
- [ ] Tests: target-in-force for a Day before/on/after effective dates; nil before first; a change today leaves yesterday's lookup unchanged
