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

## 05: Habits: quantitative, weekly, dated targets

- [ ] New habit → Kind "Amount", Period "Day", amount 20: the card shows a `—` capsule; tap it: the sheet opens with the number pad, "of 20" beside the field, and +1 +5 +10 chips; tapping +10 updates the card behind the sheet at once; Done with a typed 25 saves 25; a typed 0 (or empty) removes the day's check-in.
- [ ] Quantitative heatmap and calendar: 5 / 10 / 15 / 20 of 20 show four rising greens, only 20+ blooms; check in light and dark.
- [ ] New habit → Kind "Yes / no", Period "Week", "Days a week" 3: the card has a dot row above the heatmap (filled only for weeks with 3 check-ins), streak reads "n weeks", caption "2 of 3 this week"; the current week's dot fills as soon as the third check-in lands; a daily habit has no dot row.
- [ ] Weekly streak: with last week met and this week at 2 of 3 on a Wednesday the streak still counts last week; a week that ended unmet breaks it.
- [ ] Detail → Target card → Change: switch a daily quantitative habit to Week or raise its amount; Save is disabled until something changes; after saving, earlier days keep their old colours and the streak unit follows the new period.
- [ ] Detail calendar on a quantitative habit: tapping a past day opens the number sheet for that day (subtitle shows the date); days before the habit's first target and future days do nothing.
- [ ] New-habit form: "Days a week" rejects 8; the amount row disappears for a daily yes/no habit; Save stays disabled until emoji, name and a valid target are set.
- [ ] Dynamic Type: the amount capsule, the week caption, the Target card row, the number sheet and chips all scale without clipping.
- [?] The third intensity bucket runs from just over 50 % to just under 100 %: only reaching the target draws the full accent with bloom, so a 90 % day never reads as met.
- [?] A week is judged against the target in force on its Sunday: raising a weekly target mid-week applies to the current week and never to finished ones.
- [?] Quantitative weekly cells bucket each day against the weekly target (so one 5 km day of a 20 km week is a quarter); the dot row says whether the week was met.
- [?] The amount capsule turns green when the current period is met, so a met weekly habit with nothing logged today shows a green `—`.
- [?] `+N` chips write immediately and keep the sheet open; Done writes the typed total; there is no Cancel on the number sheet.
- [?] Quantitative targets and amounts may be fractional; yes/no weekly targets are whole days, at most 7.
- [?] Calendar days before the first target are inert, not just empty.
- [?] Kind is fixed at creation; Change Target edits amount and period only.
- [?] The Target card shows "20 a day" / "3 days a week" with a Change button and no "since" date.
- [?] A daily yes/no habit is met by any check-in even if its stored target amount is 2 (ticket 04's form allowed it); the amount row no longer appears for that combination.

## 06: Food: Items, Servings, Entries, timeline

- [ ] Food tab: large title "Food" with "Today" under it; the week strip shows this Monday–Sunday week with today's number green and a dot; swipe right pages back a week at a time; tap a past day: the well moves, the subtitle shows the date, the timeline reloads; future days in this week are muted and do nothing.
- [ ] Tap `+` on the 7 AM row: the sheet's subtitle reads "Today at 7:00 AM"; the toolbar `+` reads the current time instead. Tap "New food", type a name, Add serving, fill it in, Save, Save: the log page for the new food opens; Add: the Entry lands on the 7 AM row, the hour's dot turns green, the card shows "1 × <serving>", the macro letters in blue / pink / orange, and the kcal on the right.
- [ ] Sheet row `+` (the square one): logs the default serving once at the sheet's time and closes the sheet at once.
- [ ] Log page: pick the other serving (checkmark moves, the preview macros change), type 1.5, change the time; Add is disabled while the quantity is empty or 0.
- [ ] Filter field: typing narrows the list as you type; "New food “chicken”" pre-fills the name; the Meals tab says "No meals yet".
- [ ] Long-press a food row → Edit: rename it, add a serving, drag the handle to reorder, swipe a serving left to delete, toggle Default on a serving (the checkmark moves), Save; a food with no servings cannot be saved. Reopen: the order and default stick.
- [ ] Long-press a food row → Archive: it leaves the list; its Entries on the timeline are unchanged; type its name in the filter: it appears dimmed with "Tap to restore"; tap → Restore brings it back.
- [ ] Edit a food's serving macros (e.g. egg 70 → 78 kcal): Entries already logged keep 70; new ones get 78.
- [ ] Tap an Entry: the detail opens with quantity, time, and the four macros; change 3 → 4: calories and grams scale; overtype a macro; Save is disabled until something changes; Save updates the card; Delete entry asks first and removes only that Entry.
- [ ] Log at 11:50 PM: the Entry sits on the 11 PM row of today and does not appear on tomorrow.
- [ ] Dynamic Type: the strip, hour rows, Entry cards, list rows and all three forms scale without clipping; check light and dark throughout, and that the tab bar minimises when the timeline scrolls.
- [?] The timeline starts at 12 AM with all 24 hours and no auto-scroll; say if it should open at 6 AM or the current hour.
- [?] The log page previews macros but does not edit them; corrections happen on the Entry detail.
- [?] Stored Entry macros are totals for the whole quantity; changing the quantity on the detail scales them.
- [?] The detail edits the time of day only; the Day never moves.
- [?] Archived foods surface only under a matching filter (dimmed, tap to restore); no Archived section.
- [?] Archive does not confirm; Delete entry does.
- [?] Saving a new food goes straight to its log page rather than back to the list.
- [?] Foods list alphabetically; no manual reorder.
- [?] A serving's empty macro field means 0; grams optional; the first serving is the default until another is toggled.
- [?] The strip's "today" is fixed when the tab is created (relaunch after midnight).
- [?] `FoodItem`, `Serving`, `Entry` each gained an optional `id: UUID` (additive).
- [?] The rail (a `fill` bar with hour dots) is a timeline axis, not a divider.
- [?] The sheet is titled "Add Entry" with a "Filter" field; the Meals segment is present but empty until ticket 07.

