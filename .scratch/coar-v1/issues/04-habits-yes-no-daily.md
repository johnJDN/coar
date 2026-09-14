# 04: Habits: yes/no, daily

**What to build:** Create a yes/no daily habit (emoji, name); the Habits tab shows one card per habit with a `CheckToggle`, the streak as hero number, and a 7-row Monday-top heatmap with binary cells; tap into a detail page with a calendar to fix past days; reorder; archive rather than delete. Establishes the Habit/Check-in/Streak vocabulary from `CONTEXT.md`.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] New-habit sheet: emoji (system keyboard), name, target amount, period; this ticket only needs target 1 / day but the fields exist
- [ ] Habit card: emoji, name, `CheckToggle` (two states, no recorded miss), streak hero ("12 days"), heatmap in a `UICollectionView`: 7 rows Monday on top, ~26 columns, `surfaceSunken` empty cells, `accentGreen` done cells with bloom
- [ ] Toggling on creates the day's Check-in (amount 1); toggling off deletes it; at most one Check-in per Habit per Day
- [ ] Detail page with a month calendar; tapping a past day toggles that day's Check-in
- [ ] Manual reorder persists via `sortOrder`
- [ ] Archive from detail; an Archived section at the bottom of the tab with Restore and Delete permanently (cascades Check-ins)
- [ ] Tests (façade): check-in create/replace/delete per Day; archived habits absent from the active list; delete-permanently removes Check-ins
- [ ] Tests (pure): streak counts consecutive Days; today counts once met and does not break the streak until it ends unmet; a gap resets
