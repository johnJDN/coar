# Human testing: run once after ticket 15

A running list, appended by each ticket's agent, of everything only John can check: on-device
behaviour, visual checks against `DESIGN.md`, and judgement calls to confirm or reverse.
Tickets 01–03 were confirmed one by one and are not repeated here.

Each entry: `[ ]` to test, `[?]` a judgement call to confirm (say "keep" or what to change).

## 04: Habits: yes/no, daily

- [ ] Tap `+` on Habits: the emoji keyboard opens first; typing a second emoji replaces the first; Save stays disabled until emoji and name are filled.
- [ ] Toggle a habit on: capsule springs to green with bloom, today's heatmap cell lights up, streak updates; toggle off reverses it.
- [ ] Heatmap: 7 rows, Monday on top, this week is the rightmost column, days after today are blank; check in both light and dark.
- [ ] Long-press a card and drag to reorder; kill and relaunch the app: the order persists. Dragging below the Archived section snaps back into the active list.
- [ ] Tap a card: detail shows the streak and this month's calendar; tap a past day to add or remove its check-in; `‹` goes to earlier months, `›` is muted on the current month; future days do nothing.
- [ ] Detail `…` menu → Archive: pops back, habit appears under Archived; Restore puts it at the end of the active list; Delete permanently asks first and removes it.
- [ ] Empty state: with no habits at all the tab shows one card with `—` and "Tap + to add your first habit."
- [ ] Dynamic Type (Settings → Accessibility → Larger Text): cards, calendar numbers and the streak hero all scale; nothing clips.
- [?] `Habit` has an optional `id: UUID` attribute (additive, CloudKit-safe) as the screen-facing identity.
- [?] The new-habit sheet accepts a Week period and any whole target amount, but until ticket 05 every habit renders daily (streak in days, binary cells).
- [?] A streak of 0 shows as a muted "0 days", not `—` (zero is a value, not missing data).
- [?] Archive does not ask for confirmation (reversible); Delete permanently does.
- [?] `Store.context` and `Store.save()` are internal so `Store+<Domain>.swift` files can exist; nothing outside `Store+*` uses them, by convention.
- [?] Reorder is long-press drag, not an Edit mode.
- [?] The detail title is inline "emoji name" (no large title on a pushed detail).
- [?] Restore places the habit at the end of the active list rather than its old slot.
- [?] Heatmap cells before the habit existed render as empty `surfaceSunken`, not blank; "before the first target renders empty" (dated targets) is ticket 05.
