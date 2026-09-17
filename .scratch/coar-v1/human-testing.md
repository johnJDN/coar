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
- [ ] Filter field: typing narrows the list as you type; "New food “chicken”" pre-fills the name.
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
- [?] The sheet is titled "Add Entry" with a "Filter" field.
- [?] The Entry row is a `surface` row with the inner radius and card shadow, not a full `Card` (no dark top highlight); rows have no thumbnail.
- [ ] Leave the app open across midnight (or change the clock): the strip's green mark and the selection move to the new day and the toolbar `+` logs onto it.


## 07: Food: Meals, summary row, no-target state

- [ ] Food tab with a Target set (Settings): the summary row sits between the week strip and the timeline with four columns; log an Entry: the numbers update and the bars slide (calories amber, protein blue, fat pink, carbs orange); check light and dark.
- [ ] Pick a Day before your first Target (or a fresh install): every column reads "1,240 / —" with an empty track; the row does not collapse or move; the timeline is where it always is.
- [ ] Eat past a target: that bar is full and stays full; nothing turns red.
- [ ] `+` → Meals → New meal: name it, Add food → pick a food (the filter narrows as you type) → pick a serving, type 2, Save: the line reads "Eggs / 2 × 1 egg · 140 kcal" and the header total updates; add a second food; drag the handle to reorder; swipe a line left to delete; Save is disabled until there is a name and at least one line; Save: the log page for the new meal opens.
- [ ] Meals segment: each meal's subtitle sums its lines ("340 kcal · P 16 · F 10 · C 44"); the square `+` logs it once at the sheet's time and closes; tap the row: the log page shows Quantity "1 × meal", the time, the four macros, and "Made of" lines; type 0.5: the macros halve and the lines read "1 × 1 egg"; Add lands one Entry on the timeline named after the meal.
- [ ] Tap the meal Entry on the timeline: the detail has a "Made of" section between the quantity and the macros; change 1 → 2: both the lines and the macros double; overtype a macro: the lines stay; Save; reopen the meal from the sheet: it is unchanged.
- [ ] Edit a food's serving macros after logging a meal that uses it: the meal's subtitle in the Meals segment changes; the Entry already logged does not.
- [ ] Long-press a meal row → Edit: rename, change a line's serving and quantity, Save; Long-press → Archive: it leaves the list; type its name in the filter: dimmed "Tap to restore"; Restore brings it back; the log page's `…` menu offers the same Edit / Archive.
- [ ] Remove, from a food, a serving that a meal uses: in the Meals segment the meal's square `+` is disabled; its log page's Add is disabled and the footer says to edit the meal; the editor shows "Serving removed · tap to pick another" in coral and Save stays disabled until you pick one.
- [ ] Log an Entry while the Food tab is visible (from the sheet): the summary numbers cross-dissolve and the bars slide rather than jump.
- [ ] Light mode, log page and Entry detail, "Made of" section: is there a hairline gap between the two rows? (seen in a simulator render; the other sections show none.)
- [ ] Dynamic Type: the summary row's numbers shrink to fit rather than wrap; the meal editor rows, the picker, the line form and the log page scale without clipping.
- [?] A Meal Entry's Serving name is "meal" ("0.5 × meal" on the card and detail).
- [?] The calories bar is `accentAmber`, matching its tile.
- [?] Over the target the bar is full with no colour change.
- [?] A macro whose Target is 0 shows `—` and no fill for that bar only.
- [?] Summary numbers are whole with grouping and no units.
- [?] The breakdown is stored for one of the meal and scaled on screen by the quantity; overtyping a macro makes the breakdown and totals disagree.
- [?] A line whose serving was removed stays in the meal with zero macros until repicked, and the meal cannot be logged until then.
- [?] Meals list by name; lines reorder by drag.
- [?] The meal editor's food picker has no "New food" action.
- [?] A new meal goes straight to its log page.
- [?] "No meals yet" is gone; an empty Meals segment shows only "New meal".
- [?] `Meal` and `MealComponent` gained an optional `id: UUID` (additive).

## 08: Train: Exercises, Plans, Supersets

- [ ] Train → Exercises chip: the catalogue opens; `+` → type a name, pick a Muscle Group from the menu, add equipment and a rest of 150; Save stays disabled until there is a name (and while rest is 0); the row reads "Chest · Barbell · Rest 150 s"; the chip's subtitle back on the root reads "1 exercise".
- [ ] Tap an Exercise → the sheet opens filled in; Archive exercise: it moves to the Archived section, dimmed with "Archived · tap to restore"; tap it → Restore brings it back.
- [ ] Train root: with no Plans the Plans section shows a card with `—` and "Tap New plan to build your first plan."; New plan opens the editor with the keyboard in the name field.
- [ ] Plan editor: Add exercise → the picker filters as you type; "New exercise “curl”" opens the sheet pre-filled and, on Save, the exercise lands in the plan; each new row reads "3 × 8–12"; drag the handle to reorder; swipe left to remove; Save is disabled until a name and one exercise exist.
- [ ] Tap a row → Planned Sets: type 135 in weight and 5 in reps; leave the max empty: back in the editor the row reads "3 × 5 · 135 lbs"; type 8 and 12: "8–12"; type 12 then 8: Save is disabled; Add set repeats the last set; swipe a set to delete; the keyboard never covers the last row or Add set.
- [ ] Superset: tap the link button on the first row: it turns lavender and the two rows read "A1 · …" / "A2 · …"; link the second row too: "A3"; unlink the middle: "A1 / A2" and the third alone; drag A2 below an unlinked row: the pair breaks; a plan with two pairs reads A1 A2 B1 B2. The last row has no link button.
- [ ] Save the plan: the root card shows the name, "4 exercises", and the exercise names; tap it: the editor reopens with everything in order and the superset intact; kill and relaunch: same.
- [ ] Editor `…` → Archive: pops to the root, the plan sits under Archived with Restore; Restore returns it to Plans.
- [ ] Settings → kg: reopen a plan's sets: 135 lbs reads 61.2 kg; type 60 and save; back in lbs it reads 132.3 lbs.
- [ ] Archive an Exercise that a Plan uses: the plan's row still shows it with "· archived"; the picker no longer offers it.
- [ ] Dynamic Type: the set pills, plan cards, catalogue rows and the Exercise sheet scale without clipping; check light and dark throughout.
- [?] The Superset link is a per-row button (lavender when linked) rather than an icon between cards; the between-cards icon arrives on the logger's `ExerciseCard`s.
- [?] Grouped rows are labelled A1 / A2, B1 / B2.
- [?] The picker offers "New exercise" inline.
- [?] A new row starts as 3 × 8–12 with no weight; Add set repeats the last set.
- [?] A Plan needs a name and one Exercise; a row may have zero sets ("No sets").
- [?] An empty weight stores 0 kg and reads `—`; a max below the min disables Save rather than swapping.
- [?] Archive (Plan editor `…`, Exercise sheet) does not confirm and discards unsaved editor changes.
- [?] Plans and Exercises list by name; no manual order.
- [?] `Exercise`, `Plan`, `PlanExercise`, `PlannedSet` gained an optional `id: UUID` (additive).
- [?] New plan is a full-width glass capsule under the Plans cards, not a `+` in the navigation bar.

## 09: Train: Workout logger and lifecycle

- [ ] Train root → Start workout: the menu lists each Plan (with its exercise count) and "Empty workout"; pick Push: the logger opens titled "Push", subtitle "Started h:mm", one card per exercise with "A1 · Barbell · 3 sets", set rows pre-filled with the target weight and the range's minimum reps.
- [ ] Tap a row's `—` check: all four pills flood green with the spring and the check appears; tap again to undo. Type a weight and reps (Done bar closes the pad); kill and relaunch the app: the numbers and checks are still there and the root reads "Resume workout · Push · since h:mm".
- [ ] Add set repeats the last set; long-press a row → Remove set; card `…` → Remove exercise; Add exercise → picker → the new card lands at the bottom with 3 blank sets (reps placeholder `—`).
- [ ] Edit the Plan (change a target, remove an exercise) while the Workout is active: the logger is unchanged; the Plan editor shows only its own edits.
- [ ] Back out of the logger: the Active Workout bar docks above the tab bar ("Push · Active · n min") on every tab and inline when the tab bar minimises; tap it: back in the logger (no second copy); push the picker from the logger: no bar; switch to Home: bar; tap: back to the logger.
- [ ] Finish with some sets unchecked: "n sets you did not complete will be dropped" → Finish → "Update plan targets with today's weights?" → Update: the Plan's weights match what you lifted, reps and exercises unchanged; the detail shows only completed sets; the root's grid marks today, Recent workouts lists it ("h:mm · n min", "Sep d · n exercises · n sets"), the bar is gone.
- [ ] Finish with nothing checked: "Nothing logged yet" → Discard removes it (grid and Recent unchanged). `…` → Discard workout asks first.
- [ ] Start a Workout, set the device clock 13 hours ahead, relaunch: "Still working out?" offers Finish / Discard (Discard / Keep active if nothing was completed).
- [ ] Two finished Workouts on one Day: the grid marks the Day once; tapping opens the "Today · 2 workouts" list; tapping a card opens its detail; a Day with one goes straight to it.
- [ ] Settings → kg: the logger, detail, and Recent captions read in kg; a weight typed as 60 kg reads 132.3 lbs back in lbs.
- [ ] Dynamic Type: set pills, card headers, the Start button's two lines, the accessory bar and the detail lines scale without clipping; check light and dark throughout.
- [?] Logged Sets pre-fill reps with the range's minimum (8 for 8–12); the range is the placeholder once cleared.
- [?] Finish with no completed set offers Discard / Keep logging; the launch prompt offers Discard / Keep active in that case.
- [?] Finish with uncompleted sets confirms how many will be dropped.
- [?] The logger's `…` has Discard workout (with confirmation).
- [?] Write-back skips 0 kg sets and pairs rows by Exercise in order; the offer is skipped when no completed set has a weight; the launch prompt's Finish never offers it.
- [?] A Workout's title is the Plan's live name (renaming a Plan retitles past Workouts); "Empty workout" with no Plan.
- [?] An Exercise added mid-Workout starts with 3 blank sets; Add set repeats the last set with no target.
- [?] The grid marks today as soon as a Workout starts; Recent workouts shows the last 5 finished only.
- [?] Remove set is a long-press menu; Remove exercise lives in the card's `…`.
- [?] Non-Workout Days draw as empty sunken circles (like the Habits calendar); only Workout Days respond.
- [?] `Workout`, `WorkoutExercise`, `LoggedSet` gained an optional `id: UUID` (additive).

## 10: Train: rest timer and Superset logging

- [ ] In the logger, complete a set on an Exercise that is not in a Superset: the bar docks above the tab bar with a green `timer` icon, the countdown ("2:00", or the Exercise's rest default, e.g. "2:30" for 150 s), "Rest · Push", and ✕; it counts down each second; ✕ removes it at once.
- [ ] Complete A1's set: no timer. Complete A2's set: timer. With a three-Exercise group, only the third starts it.
- [ ] While the timer runs, switch to Home / Habits / Food: the bar and countdown follow; tap it: back in the logger. Scroll down so the tab bar minimises: the bar goes inline showing the icon, countdown and ✕ (no "Rest · Push"); scroll up: it grows back.
- [ ] Let it reach 0:00: a success haptic plays and the bar reverts (to the Workout line on other tabs; gone inside the logger). Background the app mid-count, come back a minute later: the countdown reflects the real time passed.
- [ ] Tap the card's `timer` button: the timer starts with that Exercise's default, even on A1.
- [ ] Complete sets in the Superset: the cards do not scroll or move; the keyboard closes on ✓ as before; the lavender link sits between A1 and A2 (and A2 and A3), no link between ungrouped cards.
- [ ] Finish or Discard the Workout while the timer runs: the bar disappears entirely.
- [ ] Dynamic Type: the countdown, "Rest · Push", the link glyph, and the timer button scale; the bar's two lines do not clip in light or dark.
- [?] One accessory: the countdown replaces the Workout line everywhere while it runs (including inside the logger); tap still returns to the logger.
- [?] The card's timer button ignores the Superset rule and always (re)starts with the row's default or 120 s.
- [?] Completing any set restarts a running timer with the new duration.
- [?] The rule is by row: A1's extra sets (unequal set counts) never start the timer.
- [?] The timer ends itself with a haptic; no local notification in the background; not persisted across relaunch.
- [?] Grouped cards sit 24 pt apart with the link; ungrouped 16 pt.
- [?] Countdown is card-title size with monospaced digits (the accessory height fits two lines only at that size).
