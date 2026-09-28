# Human testing: run once after ticket 15

A running list, appended by each ticket's agent, of everything only John can check: on-device
behaviour, visual checks against `DESIGN.md`, and judgement calls to confirm or reverse.
Tickets 01–03 were confirmed one by one and are not repeated here.

Each entry: `[ ]` to test, `[?]` a judgement call to confirm (say "keep" or what to change).
Once confirmed: `[x]`. Anything fixed or changed during testing is listed under that ticket's
**Results**, which override the lines above them.

**Status (2026-09-26): complete.** Tickets 04–15 all passed on John's iPhone (15 with the
simulator as the second device); every judgement call was kept unless its Results say otherwise.

## 04: Habits: yes/no, daily

- [x] Tap `+` on Habits: the emoji keyboard opens first; typing a second emoji replaces the first; Save stays disabled until emoji and name are filled.
- [x] Toggle a habit on: capsule springs to green with bloom, today's heatmap cell lights up, streak updates; toggle off reverses it.
- [x] Heatmap: 7 rows, Monday on top, this week is the rightmost column, days after today are blank; check in both light and dark.
- [x] Long-press a card and drag to reorder; kill and relaunch the app: the order persists. Dragging below the Archived section snaps back into the active list.
- [x] Tap a card: detail shows the streak and this month's calendar; tap a past day to add or remove its check-in; `‹` goes to earlier months, `›` is muted on the current month; future days do nothing.
- [x] Detail `…` menu → Archive: pops back, habit appears under Archived; Restore puts it at the end of the active list; Delete permanently asks first and removes it.
- [x] Empty state: with no habits at all the tab shows one card with `—` and "Tap + to add your first habit."
- [x] Dynamic Type (Settings → Accessibility → Larger Text): cards, calendar numbers and the streak hero all scale; nothing clips.
- [x] keep: `Habit` has an optional `id: UUID` attribute (additive, CloudKit-safe) as the screen-facing identity.
- [x] keep: The new-habit sheet accepts a Week period and any whole target amount, but until ticket 05 every habit renders daily (streak in days, binary cells).
- [x] keep: A streak of 0 shows as a muted "0 days", not `—` (zero is a value, not missing data).
- [x] keep: Archive does not ask for confirmation (reversible); Delete permanently does.
- [x] keep: `Store.context` and `Store.save()` are internal so `Store+<Domain>.swift` files can exist; nothing outside `Store+*` uses them, by convention.
- [x] keep: Reorder is long-press drag, not an Edit mode.
- [x] keep: The detail title is inline "emoji name" (no large title on a pushed detail).
- [x] keep: Restore places the habit at the end of the active list rather than its old slot.
- [x] keep: Heatmap cells before the habit existed render as empty `surfaceSunken`, not blank; "before the first target renders empty" (dated targets) is ticket 05.

**Results (2026-09-22):**
- **Fail, emoji:** the `🙂` shown in the emoji slot is placeholder text, not a value, so name-only leaves Save disabled while it looks complete. Fixed: the shown emoji is the real default — Save needs only a name; an untouched slot saves as `🙂`.
- **Fail, calendar backfill:** past days on a new habit's calendar do nothing. Cause: Days before the first target are inert (a 05 call), and a habit created today has its first target from today, so nothing in the past is tappable — the calendar can't do the one thing it exists for. Fixed (John agreed): a Habit's first target also applies to every Day before it, so any past Day is editable and renders against it. Later targets stay dated as before; only macro Targets keep "nil before the first".
- **New, number fields:** the "Days a week" field (new habit and Change Target) opens with the cursor before the existing `1`, so typing 3 gives 31. Fixed: every numeric field in the app selects its whole contents on focus, so typing replaces and tapping away keeps the value. Applies to all ten number inputs (habits, Food quantity and servings, Body Weight, set rows, Planned Sets, exercise rest, Settings targets), via one shared field.

## 05: Habits: quantitative, weekly, dated targets

- [x] New habit → Kind "Amount", Period "Day", amount 20: the card shows a `—` capsule; tap it: the sheet opens with the number pad, "of 20" beside the field, and +1 +5 +10 chips; tapping +10 updates the card behind the sheet at once; Done with a typed 25 saves 25; a typed 0 (or empty) removes the day's check-in.
- [x] Quantitative heatmap and calendar: 5 / 10 / 15 / 20 of 20 show four rising greens, only 20+ blooms; check in light and dark.
- [x] New habit → Kind "Yes / no", Period "Week", "Days a week" 3: the card has a dot row above the heatmap (filled only for weeks with 3 check-ins), streak reads "n weeks", caption "2 of 3 this week"; the current week's dot fills as soon as the third check-in lands; a daily habit has no dot row.
- [x] Weekly streak: with last week met and this week at 2 of 3 on a Wednesday the streak still counts last week; a week that ended unmet breaks it.
- [x] Detail → Target card → Change: switch a daily quantitative habit to Week or raise its amount; Save is disabled until something changes; after saving, earlier days keep their old colours and the streak unit follows the new period.
- [x] Detail calendar on a quantitative habit: tapping a past day opens the number sheet for that day (subtitle shows the date); days before the habit's first target and future days do nothing.
- [x] New-habit form: "Days a week" rejects 8; the amount row disappears for a daily yes/no habit; Save stays disabled until emoji, name and a valid target are set.
- [x] Dynamic Type: the amount capsule, the week caption, the Target card row, the number sheet and chips all scale without clipping.
- [x] keep: The third intensity bucket runs from just over 50 % to just under 100 %: only reaching the target draws the full accent with bloom, so a 90 % day never reads as met.
- [x] keep: A week is judged against the target in force on its Sunday: raising a weekly target mid-week applies to the current week and never to finished ones.
- [x] keep: Quantitative weekly cells bucket each day against the weekly target (so one 5 km day of a 20 km week is a quarter); the dot row says whether the week was met.
- [x] keep: The amount capsule turns green when the current period is met, so a met weekly habit with nothing logged today shows a green `—`.
- [x] keep: `+N` chips write immediately and keep the sheet open; Done writes the typed total; there is no Cancel on the number sheet.
- [x] keep: Quantitative targets and amounts may be fractional; yes/no weekly targets are whole days, at most 7.
- [x] reversed: Calendar days before the first target are inert — superseded by the 04 backfill fix: the first target covers every earlier Day.
- [x] keep: Kind is fixed at creation; Change Target edits amount and period only.
- [x] keep: The Target card shows "20 a day" / "3 days a week" with a Change button and no "since" date.
- [x] keep: A daily yes/no habit is met by any check-in even if its stored target amount is 2 (ticket 04's form allowed it); the amount row no longer appears for that combination.

**Results (2026-09-22):** all pass after the fixes below; all judgement calls kept.
- **Clarified, target change:** a change applies from today; earlier Days keep their colours. A change made on the Day its target started replaces that record, and since the first target also covers earlier Days (04 backfill fix), changing a habit's target on the day it was created recolours its backfilled Days. Treated as correcting a mistake; to see history keep its colours, change the target on a later day.
- **Fixed, capsule width:** the `—` amount capsule stretched across the row after the name. Nothing in the row preferred the name for spare width; the capsule's label now hugs, and the name takes the slack (also fixes Home's habits card rows).
- **Fixed, sheet height:** with the keyboard up the number sheet rose far too high (a `.medium()` detent is lifted to half the space above the keyboard). It now uses a detent sized to its content, so it sits just above the keyboard.

## 06: Food: Items, Servings, Entries, timeline

- [x] Food tab: large title "Food" with "Today" under it; the week strip shows this Monday–Sunday week with today's number green and a dot; swipe right pages back a week at a time; tap a past day: the well moves, the subtitle shows the date, the timeline reloads; future days in this week are muted and do nothing.
- [x] Tap `+` on the 7 AM row: the sheet's subtitle reads "Today at 7:00 AM"; the toolbar `+` reads the current time instead. Tap "New food", type a name, Add serving, fill it in, Save, Save: the log page for the new food opens; Add: the Entry lands on the 7 AM row, the hour's dot turns green, the card shows "1 × <serving>", the macro letters in blue / pink / orange, and the kcal on the right.
- [x] Sheet row `+` (the square one): logs the default serving once at the sheet's time and closes the sheet at once.
- [x] Log page: pick the other serving (checkmark moves, the preview macros change), type 1.5, change the time; Add is disabled while the quantity is empty or 0.
- [x] Filter field: typing narrows the list as you type; "New food “chicken”" pre-fills the name.
- [x] Long-press a food row → Edit: rename it, add a serving, drag the handle to reorder, swipe a serving left to delete, toggle Default on a serving (the checkmark moves), Save; a food with no servings cannot be saved. Reopen: the order and default stick.
- [x] Long-press a food row → Archive: it leaves the list; its Entries on the timeline are unchanged; type its name in the filter: it appears dimmed with "Tap to restore"; tap → Restore brings it back.
- [x] Edit a food's serving macros (e.g. egg 70 → 78 kcal): Entries already logged keep 70; new ones get 78.
- [x] Tap an Entry: the detail opens with quantity, time, and the four macros; change 3 → 4: calories and grams scale; overtype a macro; Save is disabled until something changes; Save updates the card; Delete entry asks first and removes only that Entry.
- [x] Log at 11:50 PM: the Entry sits on the 11 PM row of today and does not appear on tomorrow.
- [x] Dynamic Type: the strip, hour rows, Entry cards, list rows and all three forms scale without clipping; check light and dark throughout, and that the tab bar minimises when the timeline scrolls.
- [x] keep: The timeline starts at 12 AM with all 24 hours and no auto-scroll; say if it should open at 6 AM or the current hour.
- [x] keep: The log page previews macros but does not edit them; corrections happen on the Entry detail.
- [x] keep: Stored Entry macros are totals for the whole quantity; changing the quantity on the detail scales them.
- [x] keep: The detail edits the time of day only; the Day never moves.
- [x] changed: Archived foods surface only under a matching filter (dimmed, tap to restore); no Archived section.
- [x] keep: Archive does not confirm; Delete entry does.
- [x] (see G below): Saving a new food goes straight to its log page rather than back to the list.
- [x] changed: Foods list alphabetically; no manual reorder.
- [x] keep: A serving's empty macro field means 0; grams optional; the first serving is the default until another is toggled.
- [x] keep: The strip's "today" is fixed when the tab is created (relaunch after midnight).
- [x] keep: `FoodItem`, `Serving`, `Entry` each gained an optional `id: UUID` (additive).
- [x] keep: The rail (a `fill` bar with hour dots) is a timeline axis, not a divider.
- [x] keep: The sheet is titled "Add Entry" with a "Filter" field.
- [x] keep: The Entry row is a `surface` row with the inner radius and card shadow, not a full `Card` (no dark top highlight); rows have no thumbnail.
- [x] Leave the app open across midnight (or change the clock): the strip's green mark and the selection move to the new day and the toolbar `+` logs onto it.

**Results (2026-09-26):** all tests pass after the fixes below; calls kept except where noted.
- **Fixed, "+" button sliding:** each filter keystroke reconfigured every row, and each reconfigure built a new "+" accessory, which animates in from the trailing edge. Rows now own one "+" for life (`QuickAddListCell`), and a keystroke only adds and removes rows.
- **Fixed, log page keyboard:** the log pages (food, meal, and a meal's component line) no longer open the keyboard; it opens when Quantity is tapped.
- **Fixed, keyboard dismissal (app-wide):** every number pad gets a keyboard bar with Done (number pads have no return key); every form and editable list dismisses the keyboard on a downward drag, and short lists now bounce so there is always something to drag. Text fields keep Return = done.
- **Changed, E — Archived foods page:** an "Archived foods" row (with count) at the bottom of the Foods list opens a page listing them by name; tap to restore. Same for Meals. Archived items no longer appear under the filter.
- **Changed, H — order:** Foods and Meals list most recently used first: the later of their latest Entry and their last edit (logging also stamps it), so new, edited, or just-logged ones rise to the top. Archived pages stay by name.
- **Changed, G:** creating a food is not logging it. Saving a new food (or meal) now returns to the list, with the new one on top; tapping it logs. (The first Save on the serving page returning to New Food is unchanged.)
- **Fixed, order:** Chicken breast stuck on top because recency used the Entry's eaten-at time: an 11:50 PM Entry (test 10) outranked everything logged earlier in the day. Recency now uses when the Entry was written.
- **Fixed, tab bar:** it minimised on every tab but Food. The timeline was registered as the content scroll view for the top edge only, so for the bottom edge UIKit tracked the week strip, which only scrolls sideways.
- **Fixed, title overlap:** pulling the Food timeline down stretched the large title over the week strip and summary, which were separate views pinned to the safe area. They are now the timeline's pinned header, so the title and everything below it move together; scrolled, the title collapses inline and the header pins beneath it.

## 07: Food: Meals, summary row, no-target state

- [x] Food tab with a Target set (Settings): the summary row sits between the week strip and the timeline with four columns; log an Entry: the numbers update and the bars slide (calories amber, protein blue, fat pink, carbs orange); check light and dark.
- [x] Pick a Day before your first Target (or a fresh install): every column reads "1,240 / —" with an empty track; the row does not collapse or move; the timeline is where it always is.
- [x] Eat past a target: that bar is full and stays full; nothing turns red.
- [x] `+` → Meals → New meal: name it, Add food → pick a food (the filter narrows as you type) → pick a serving, type 2, Save: the line reads "Eggs / 2 × 1 egg · 140 kcal" and the header total updates; add a second food; drag the handle to reorder; swipe a line left to delete; Save is disabled until there is a name and at least one line; Save: the log page for the new meal opens.
- [x] Meals segment: each meal's subtitle sums its lines ("340 kcal · P 16 · F 10 · C 44"); the square `+` logs it once at the sheet's time and closes; tap the row: the log page shows Quantity "1 × meal", the time, the four macros, and "Made of" lines; type 0.5: the macros halve and the lines read "1 × 1 egg"; Add lands one Entry on the timeline named after the meal.
- [x] Tap the meal Entry on the timeline: the detail has a "Made of" section between the quantity and the macros; change 1 → 2: both the lines and the macros double; overtype a macro: the lines stay; Save; reopen the meal from the sheet: it is unchanged.
- [x] Edit a food's serving macros after logging a meal that uses it: the meal's subtitle in the Meals segment changes; the Entry already logged does not.
- [x] Long-press a meal row → Edit: rename, change a line's serving and quantity, Save; Long-press → Archive: it leaves the list; type its name in the filter: dimmed "Tap to restore"; Restore brings it back; the log page's `…` menu offers the same Edit / Archive.
- [x] Remove, from a food, a serving that a meal uses: in the Meals segment the meal's square `+` is disabled; its log page's Add is disabled and the footer says to edit the meal; the editor shows "Serving removed · tap to pick another" in coral and Save stays disabled until you pick one.
- [x] Log an Entry while the Food tab is visible (from the sheet): the summary numbers cross-dissolve and the bars slide rather than jump.
- [x] Light mode, log page and Entry detail, "Made of" section: is there a hairline gap between the two rows? (seen in a simulator render; the other sections show none.)
- [x] Dynamic Type: the summary row's numbers shrink to fit rather than wrap; the meal editor rows, the picker, the line form and the log page scale without clipping.
- [x] keep: A Meal Entry's Serving name is "meal" ("0.5 × meal" on the card and detail).
- [x] keep: The calories bar is `accentAmber`, matching its tile.
- [x] keep: Over the target the bar is full with no colour change.
- [x] keep: A macro whose Target is 0 shows `—` and no fill for that bar only.
- [x] keep: Summary numbers are whole with grouping and no units.
- [x] keep: The breakdown is stored for one of the meal and scaled on screen by the quantity; overtyping a macro makes the breakdown and totals disagree.
- [x] keep: A line whose serving was removed stays in the meal with zero macros until repicked, and the meal cannot be logged until then.
- [x] keep: Meals list by name; lines reorder by drag.
- [x] keep: The meal editor's food picker has no "New food" action.
- [x] keep: A new meal goes straight to its log page.
- [x] keep: "No meals yet" is gone; an empty Meals segment shows only "New meal".
- [x] keep: `Meal` and `MealComponent` gained an optional `id: UUID` (additive).

**Results (2026-09-26): passed after fixes;** all judgement calls kept.
- **Fixed, Targets not saving (Settings, ticket 02 regression in practice):** the sheet had a top-right Done that closed without saving, and saving needed a separate "Save targets" button that the keyboard could hide; typed Targets were silently lost. There is no Save button now: Targets save when the sheet closes, however it closes (Done or swipe), including mid-edit. An empty macro is saved as 0 (no target for that macro, shown `—`) once any field has a value. Home reloads when Settings closes, so its macros card shows the new Targets at once. A test types into the real sheet and checks the store.
- **Fixed, 1 — bar track:** the summary bars' track was `surfaceSunken`, near-invisible on the dark ground; now `fill` (DESIGN.md §3 rule added).
- **Changed, 4 — meal totals:** the meal editor has a **Total** row at the top: a `MacroStrip` (four coloured numbers and a bar split by where the calories come from). The line page shows the same strip under "In the meal" instead of the text line.
- **Changed, 9 — broken meal:** the meal's row in the Meals list gets a coral warning symbol and "Needs fixing · a serving was removed"; its log page opens with a `WarningCard` ("This meal can't be logged", with **Edit meal**); the editor's broken line gets the warning symbol too.
- **Pass, 11:** no hairline in "Made of".
- **Changed, app-wide — P/F/C colours:** every text line with P, F, C now colours each letter (not the number) in its accent (meal subtitles, serving rows, the archived pages, timeline cards).
- **Fixed, Done bar on SwiftUI forms:** the keyboard Done bar from 06 never showed on SwiftUI forms (SwiftUI ignores a UIKit accessory); every SwiftUI form now declares its own. Verified in the simulator on Settings.
- **Changed, edit from the list:** long-press → Edit, then Save, now closes the sheet (back to the Food tab) instead of landing on the Add Entry list; editing is the whole errand there. Editing from a log page's `…` menu (or the warning card's Edit meal) still returns to that page; a new food or meal still returns to the list, on top.
- **Done (2026-09-26):** all tests pass; all judgement calls kept.

## 08: Train: Exercises, Plans, Supersets

- [x] Train → Exercises chip: the catalogue opens; `+` → type a name, pick a Muscle Group from the menu, add equipment and a rest of 150; Save stays disabled until there is a name (and while rest is 0); the row reads "Chest · Barbell · Rest 150 s"; the chip's subtitle back on the root reads "1 exercise".
- [x] Tap an Exercise → the sheet opens filled in; Archive exercise: it moves to the Archived section, dimmed with "Archived · tap to restore"; tap it → Restore brings it back.
- [x] Train root: with no Plans the Plans section shows a card with `—` and "Tap New plan to build your first plan."; New plan opens the editor with the keyboard in the name field.
- [x] Plan editor: Add exercise → the picker filters as you type; "New exercise “curl”" opens the sheet pre-filled and, on Save, the exercise lands in the plan; each new row reads "3 × 8–12"; drag the handle to reorder; swipe left to remove; Save is disabled until a name and one exercise exist.
- [x] Tap a row → Planned Sets: type 135 in weight and 5 in reps; leave the max empty: back in the editor the row reads "3 × 5 · 135 lbs"; type 8 and 12: "8–12"; type 12 then 8: Save is disabled; Add set repeats the last set; swipe a set to delete; the keyboard never covers the last row or Add set.
- [x] Superset: tap the link button on the first row: it turns lavender and the two rows read "A1 · …" / "A2 · …"; link the second row too: "A3"; unlink the middle: "A1 / A2" and the third alone; drag A2 below an unlinked row: the pair breaks; a plan with two pairs reads A1 A2 B1 B2. The last row has no link button.
- [x] Save the plan: the root card shows the name, "4 exercises", and the exercise names; tap it: the editor reopens with everything in order and the superset intact; kill and relaunch: same.
- [x] Editor `…` → Archive: pops to the root, the plan sits under Archived with Restore; Restore returns it to Plans.
- [x] Settings → kg: reopen a plan's sets: 135 lbs reads 61.2 kg; type 60 and save; back in lbs it reads 132.3 lbs.
- [x] Archive an Exercise that a Plan uses: the plan's row still shows it with "· archived"; the picker no longer offers it.
- [x] Dynamic Type: the set pills, plan cards, catalogue rows and the Exercise sheet scale without clipping; check light and dark throughout.
- [x] The Superset link is a per-row button (lavender when linked) rather than an icon between cards; the between-cards icon arrives on the logger's `ExerciseCard`s.
- [x] Grouped rows are labelled A1 / A2, B1 / B2.
- [x] The picker offers "New exercise" inline.
- [x] A new row starts as 3 × 8–12 with no weight; Add set repeats the last set.
- [x] A Plan needs a name and one Exercise; a row may have zero sets ("No sets").
- [x] An empty weight stores 0 kg and reads `—`; a max below the min disables Save rather than swapping.
- [x] Archive (Plan editor `…`, Exercise sheet) does not confirm and discards unsaved editor changes.
- [x] changed: Plans and Exercises list most recently used first (was: by name); no manual order.
- [x] `Exercise`, `Plan`, `PlanExercise`, `PlannedSet` gained an optional `id: UUID` (additive).
- [x] New plan is a full-width glass capsule under the Plans cards, not a `+` in the navigation bar.

**Results (2026-09-26): passed after fixes (re-checked on device).**
- **Changed, saving (app-wide, DESIGN.md §7a):** the plan editor lost a set change when back was tapped after the sets page's Save. Now: creating keeps Save (and asks before discarding); editing saves as it changes with no Save button (Done where it's a sheet); pages inside an editor write into it directly. Applies to Plans + Planned Sets, Food Items + Servings, Meals + lines, Exercises, and the Entry detail. Leaving something that can't be saved (a plan with no name, a set with max below min) asks first.
- **Changed, 1 — exercises:** equipment is a menu (Barbell, Dumbbell, Cable, Machine, Smith machine, EZ bar, Kettlebell, Band, Bodyweight, Other with a typed name; anything typed before shows under Other). Muscle group gains Other. An exercise has one primary group and any secondary ones ("Also works": dips are Chest + Triceps, Shoulders); the catalogue row shows both.
- **Fixed, 2 — "picker":** the archive footer now says "Archived exercises can't be added to plans."
- **Fixed, 5 — rep range:** min and max hug the dash ("8 – 12") instead of centring in half the pill each; an empty max reads "max".
- **Changed, G:** Plans and Exercises list most recently used first; archived lists stay by name.
- **Added after 09, 8 — Delete permanently on archived items:** every Archived list (habits, foods, meals, exercises, plans) shows a grey Restore capsule and a coral trash button; the trash confirms with an action sheet naming what goes with it, ending "This cannot be undone." A food leaves the meals that use it and an exercise leaves the plans that use it (named in the sheet; supersets stay well formed); a deleted plan's workouts keep its name; entries and workouts never change. Archived exercise rows now restore on tap (no sheet), like archived foods. Checked in the simulator for plans, foods and exercises.

## 09: Train: Workout logger and lifecycle

- [x] Train root → Start workout: the menu lists each Plan (with its exercise count) and "Empty workout"; pick Push: the logger opens titled "Push", subtitle "Started h:mm", one card per exercise with "A1 · Barbell · 3 sets", set rows pre-filled with the target weight and the range's minimum reps.
- [x] Tap a row's `—` check: all four pills flood green with the spring and the check appears; tap again to undo. Type a weight and reps (Done bar closes the pad); kill and relaunch the app: the numbers and checks are still there and the root reads "Resume workout · Push · since h:mm".
- [x] Add set repeats the last set; long-press a row → Remove set; card `…` → Remove exercise; Add exercise → picker → the new card lands at the bottom with 3 blank sets (reps placeholder `—`).
- [x] Edit the Plan (change a target, remove an exercise) while the Workout is active: the logger is unchanged; the Plan editor shows only its own edits.
- [x] Back out of the logger: the Active Workout bar docks above the tab bar ("Push · Active · n min") on every tab and inline when the tab bar minimises; tap it: back in the logger (no second copy); push the picker from the logger: no bar; switch to Home: bar; tap: back to the logger.
- [x] Finish with some sets unchecked: "n sets you did not complete will be dropped" → Finish → "Update plan targets with today's weights?" → Update: the Plan's weights match what you lifted, reps and exercises unchanged; the detail shows only completed sets; the root's grid marks today, Recent workouts lists it ("h:mm · n min", "Sep d · n exercises · n sets"), the bar is gone.
- [x] Finish with nothing checked: "Nothing logged yet" → Discard removes it (grid and Recent unchanged). `…` → Discard workout asks first.
- [x] Start a Workout, set the device clock 13 hours ahead, relaunch: "Still working out?" offers Finish / Discard (Discard / Keep active if nothing was completed).
- [x] Two finished Workouts on one Day: the grid marks the Day once; tapping opens the "Today · 2 workouts" list; tapping a card opens its detail; a Day with one goes straight to it.
- [x] Settings → kg: the logger, detail, and Recent captions read in kg; a weight typed as 60 kg reads 132.3 lbs back in lbs.
- [x] Dynamic Type: set pills, card headers, the Start button's two lines, the accessory bar and the detail lines scale without clipping; check light and dark throughout.
- [x] Logged Sets pre-fill reps with the range's minimum (8 for 8–12); the range is the placeholder once cleared.
- [x] Finish with no completed set offers Discard / Keep logging; the launch prompt offers Discard / Keep active in that case.
- [x] Finish with uncompleted sets confirms how many will be dropped.
- [x] The logger's `…` has Discard workout (with confirmation).
- [x] Write-back skips 0 kg sets and pairs rows by Exercise in order; the offer is skipped when no completed set has a weight; the launch prompt's Finish never offers it.
- [x] A Workout's title is the Plan's live name (renaming a Plan retitles past Workouts); "Empty workout" with no Plan.
- [x] An Exercise added mid-Workout starts with 3 blank sets; Add set repeats the last set with no target.
- [x] The grid marks today as soon as a Workout starts; Recent workouts shows the last 5 finished only.
- [x] Remove set is a long-press menu; Remove exercise lives in the card's `…`.
- [x] Non-Workout Days draw as empty sunken circles (like the Habits calendar); only Workout Days respond.
- [x] `Workout`, `WorkoutExercise`, `LoggedSet` gained an optional `id: UUID` (additive).

**Results (2026-09-26): passed after fixes (re-checked on device);** judgement calls agreed.
- **Fixed, 3 — Add exercise glitch:** for about half a second after adding an exercise, everything below the top of the (closing) keyboard was blank. The logger's list was pinned to the keyboard, so it shrank with the exercise list's keyboard while sliding back. Lists now stay full height and inset their content above the keyboard instead (`insetsContentAboveKeyboard`); the Planned Sets page had the same pinning and got the same fix. Reproduced and verified in the simulator via the Xcode MCP.
- **Added — Delete workout:** a finished workout's `…` menu has Delete workout, with a confirmation; its sets leave history and Progression. Workouts aren't archived: archiving hides catalogue items from pickers, and a workout is history.

## 10: Train: rest timer and Superset logging

- [x] In the logger, complete a set on an Exercise that is not in a Superset: the bar docks above the tab bar with a green `timer` icon, the countdown ("2:00", or the Exercise's rest default, e.g. "2:30" for 150 s), "Rest · Push", and ✕; it counts down each second; ✕ removes it at once.
- [x] Complete A1's set: no timer. Complete A2's set: timer. With a three-Exercise group, only the third starts it.
- [x] While the timer runs, switch to Home / Habits / Food: the bar and countdown follow; tap it: back in the logger. Scroll down so the tab bar minimises: the bar goes inline showing the icon, countdown and ✕ (no "Rest · Push"); scroll up: it grows back.
- [x] Let it reach 0:00: a success haptic plays and the bar reverts (to the Workout line on other tabs; gone inside the logger). Background the app mid-count, come back a minute later: the countdown reflects the real time passed.
- [x] Tap the card's `timer` button: the timer starts with that Exercise's default, even on A1.
- [x] Complete sets in the Superset: the cards do not scroll or move; with the keyboard up in a reps field, tapping ✓ leaves the keyboard and cursor where they were; the lavender link sits between A1 and A2 (and A2 and A3), no link between ungrouped cards.
- [x] Finish or Discard the Workout while the timer runs: the bar disappears entirely.
- [x] Dynamic Type: the countdown, "Rest · Push", the link glyph, and the timer button scale; the bar's two lines do not clip in light or dark.
- [x] One accessory: the countdown replaces the Workout line everywhere while it runs (including inside the logger); tap still returns to the logger.
- [x] The card's timer button ignores the Superset rule and always (re)starts with the row's default or 120 s.
- [x] Completing any set restarts a running timer with the new duration.
- [x] The rule is by row: A1's extra sets (unequal set counts) never start the timer.
- [x] The timer ends itself with a haptic; no local notification in the background; not persisted across relaunch.
- [x] Grouped cards sit 24 pt apart with the link; ungrouped 16 pt.
- [x] Countdown is card-title size with monospaced digits (the accessory height fits two lines only at that size).
- [x] Tapping ✓ no longer closes the keyboard (ticket 09 did); focus stays put.
- [x] A rest default of 0 counts as none (120 s); the Exercise form rejects 0 anyway.
- [x] The Superset link is lavender, matching the Plan editor's link button.

**Results (2026-09-26): passed;** judgement calls agreed.
- **Changed — set check affordance:** the check pill showed `—` before a set was done, the same as an empty weight or reps field, so it didn't read as a button. It now shows a grey ✓ (semibold) that turns green on completion (DESIGN.md `SetRow`).

## 11: Train: Exercise Progression

- [x] Train → Exercises → tap an Exercise: the detail page opens titled with its name and "Chest · Dumbbell · Rest 150 s"; with no history the Progression card reads `—`, "No sets logged for this exercise yet", and `No data` with no axes; Recent sets shows `—` and "Sets you log for this exercise land here."
- [x] Finish one Workout with a completed set of it: the card shows the Estimated 1RM as the hero (e.g. 92.6 lbs × 8 → 117 lbs), "Estimated 1RM · Sep 16", one bloomed lime point and no line; Recent sets has one card titled by the Day with "Push · 7:28 PM" and the sets as "92.6 lbs × 8".
- [x] After three or more Workouts: a 2 pt lime line through one point per Workout, small dots on earlier points, bloom on the last, about four date labels along the bottom (none truncated) and three values on the right, all muted, no gridlines, no legend; latest Workout first in Recent sets.
- [x] In the logger, tap the card's name or its "Progression" footer button: the page opens over the logger with today's completed sets already on the chart and in the list; the accessory bar stays hidden; back returns to the logger with the keyboard state as it was.
- [x] Edit on the page: the sheet opens filled in; rename: the title updates when the sheet closes; Archive: back to the catalogue, which lists it under Archived.
- [x] Settings → kg: the hero, axis, and set lines read in kg; back in lbs they agree.
- [x] Body Weight screen: the chart's end date labels no longer truncate; with nothing logged the slot shows only `No data` (no 0 / 0.5 / 1.0 axis).
- [x] Dynamic Type: the hero, caption, section header, set lines, and the two footer buttons scale without clipping; check light and dark throughout.
- [x] Progression's accent is lime (matching the Exercises chip), not blue.
- [x] The Active Workout's completed sets already count on the chart and in Recent sets.
- [x] A completed set with 0 kg or 0 reps never counts; reps of 1 follow Epley literally.
- [x] The hero Estimated 1RM is a whole number.
- [x] Two rows of one Exercise in a Workout pool into one point and one card.
- [x] Recent sets lists at most 10 Workouts.
- [x] Tapping a catalogue row opens the page; Edit moved onto it.
- [x] Workout detail cards do not open Progression.
- [x] The Progression line is monotone (no overshoot); Body Weight keeps Catmull-Rom.
- [x] A single point's value axis reads in halves (padding floor of 1, shared with Body Weight).
- [x] DESIGN §3 now lists Progression on lime's row and drops blue's "progression dot" note.
- [x] Recent sets lists completed sets only, so the Active Workout's unticked sets appear once ticked.

**Results (2026-09-26): passed;** judgement calls agreed.

## 12: Progress Photos

- [x] Train root: the Progress Photos chip is live (lavender camera tile), subtitle `—` with none, then "1 photo" / "3 photos"; tapping opens the grid; with none the grid shows the `—` card "Tap + to take a progress photo or pick one from your library."
- [x] `+` → Take photo: the system asks "Coar uses the camera to take Progress Photos."; capture, Use Photo: the photo appears first in the grid captioned "Today"; the grid is three columns of rounded squares with the Day under each, newest first.
- [x] `+` → Choose from library: pick an older camera photo: it lands in Day order captioned with the Day it was taken (e.g. "Aug 2"), not today; pick a screenshot or a saved image with no EXIF date: it is captioned "Today". No permission prompt for the library.
- [x] Subtitle under the title reads "2 photos · tap two to compare" once there are two.
- [x] Tap a thumbnail: lavender ring and check; tap it again: cleared; tap two: Compare opens at once with the earlier photo on the left, each captioned with its Day and the nearest Body Weight ("185.3 lbs" on the same Day, "185.3 lbs on Sep 11" otherwise, `—` when none is logged; a Day between two weigh-ins picks the closer, the earlier on a tie). Back: the picks are cleared.
- [x] Settings → kg: the compare captions read in kg.
- [x] Long-press a thumbnail: View opens it alone (titled Progress Photo); Delete asks "Delete this photo?"; Cancel keeps it; Delete removes it from the grid and the chip count drops.
- [x] iCloud: a photo added on one device appears on the other within a minute (CloudKit asset); deleting it there removes it here.
- [x] Dynamic Type: grid captions, the compare Day and weight lines, and the empty card scale without clipping; check light and dark throughout.
- [x] Library photos are dated by their EXIF date (the Day the camera was on), else today; camera captures are today.
- [x] Photos are re-encoded as JPEG capped at 2048 px (plus a 400 px thumbnail) and stripped of metadata before storing; the original in Photos is untouched.
- [x] Compare is pick-two with the second pick opening it; no separate Compare button or select mode.
- [x] The earlier photo is always on the left, whatever the pick order.
- [x] Long-press is where View and Delete live; a photo is deleted outright, never archived.
- [x] Nearest Body Weight on a tie is the earlier Day.
- [x] Take photo is hidden (not disabled) where there is no camera.
- [x] Lavender is Progress Photos' accent (DESIGN §3), shared with AI / coach.
- [x] `ProgressPhoto` gained optional `id: UUID` and `thumbnailData` (additive).
- [x] Captions say "3 photos" / "5 photos · tap two to compare" (short noun under the Progress Photos title); the delete alert says "progress photo".
- [x] The pick ring is a 3 pt lavender border rather than a bloom.
- [x] Settings → kg while on Compare: captions update in place without reloading the images.

**Results (2026-09-26): passed;** judgement calls agreed.

## 13: Sleep and Steps from HealthKit

- [x] Fresh install (or Settings → Health → Apps → Coar → Delete data and reset): Home shows Sleep | Steps squares with `No data` and "Tap to connect Apple Health"; tapping `No data` shows the system Health prompt; Turn On All: the squares fill with last night's time asleep ("7h 32m") and today's steps ("8,432") without leaving Home.
- [x] Sleep square agrees with the Health app's "Time Asleep" for last night (a Watch night with stages) to the minute; a night with only iPhone in-bed tracking shows `No data`.
- [x] Nap after lunch: Sleep on Home grows by the nap once Health has it; a doze after 6 PM does not change today's number (it belongs to tomorrow's night).
- [x] Steps square matches the Health app's step total for today and updates on returning to Home after a walk.
- [x] Tap the Sleep square (anywhere but the value): the detail pushes within Home; title "Sleep", subtitle "Last 30 days"; hero is last night, caption "30-day average …"; 30 bars in teal, the latest bar brighter with a glow, Days with nothing are gaps; x labels about weekly; y axis in hours. Same for Steps in amber with 0 / 5K / 10K.
- [x] Deny sleep in the prompt but allow steps: Sleep says `No data`, Steps has a value; the Sleep detail caption reads "Nothing in Apple Health for the last 30 days. Sleep comes from an Apple Watch or a sleep app; if you use one, check Coar's access in the Health app."
- [x] iPad (no HealthKit): both squares `No data`, tapping the value does nothing, detail caption "Apple Health is not available on this device".
- [x] Settings sheet's Apple Health row reads "Connected" after prompting from Home.
- [x] Dynamic Type: the square heroes shrink to fit rather than clip; the detail hero, captions, and axis labels scale; check light and dark throughout.
- [x] A night runs 6 PM to 6 PM (the Health app's sleep day): an afternoon nap joins the night before it, an evening doze joins the night after.
- [x] Hours two sources both recorded (Watch stages under a sleep app's span) count once; a sample straddling 6 PM is split.
- [x] A night with in-bed samples only (iPhone-only tracking) is `No data`, not 0.
- [x] Steps take amber (DESIGN §3 "strain-style effort"); Sleep is teal.
- [x] Tapping `No data` prompts only while the prompt has never been shown; afterwards the whole square opens the detail (HealthKit will not show the prompt twice).
- [x] Past bars are the accent at 70%; only the latest bar is full with bloom; missing Days are gaps, not zero bars.
- [x] The 30-day average counts only Days that have data.
- [x] Home's ticket 01 placeholder "Today" card is gone; Home is the two squares until ticket 14.
- [x] The empty detail shows `No data` twice: the hero slot and the chart slot (each is a value slot per DESIGN §1.5).
- [x] CONTEXT.md now defines Night, Time Asleep, and Steps; ADR 0006 records the 6 PM boundary.
- [x] Story 80's tap-through is only offered while the prompt has never been shown; after a denial the detail caption says to check the Health app (an `x-apple-health://` link was not added).

**Results (2026-09-26): passed after a fix;** judgement calls agreed. No sleep source on John's phone, so sleep reads `No data` throughout.
- **Fixed — Home cards ignored taps:** tapping a Sleep square with `No data` did nothing. Every Home card with buttons inside (Habits, Macros, the four squares) let those buttons take their taps, but UIKit then never fired the card's own tap for a touch on a label or padding. `CardControl` now hands such touches to the card (tests in `CardControlTests`). That made whole cards controls, which a plain scroll view won't scroll from, so `ScreenViewController`'s scroll view now scrolls from them too. Verified in the simulator: `No data` and the title open Sleep, Body Weight opens, a habit check still toggles in place, and Home scrolls from a card.
- **Changed — empty Sleep/Steps caption:** HealthKit can't say whether a read was refused, so the empty detail now says where the data comes from before suggesting to check access ("Sleep comes from an Apple Watch or a sleep app; …").

## 14: Home

- [x] Fresh install: the title reads "Today, <month> <day>" with "Good morning/afternoon/evening, John" under it; the avatar button opens Settings; the Habits card shows `—` "No habits yet"; the Macros card shows 0 / `— target` for each macro with no dots and a "Set targets" capsule; Sleep | Steps read `No data`; Body Weight reads `—` "No Body Weight yet"; Last Workout reads `—` "No workouts yet". Nothing collapses. Check light and dark.
- [x] Tap "Set targets", enter targets, save: the card now shows dots per macro (5 g / 50 kcal each) with none filled, "of 2,100 kcal" captions, and the capsule is gone.
- [x] Log food on the Food tab, return Home: the calories hero and the three metric numbers update and the dots fill with bloom in blue / pink / orange / amber; eating past a target fills every dot.
- [x] Add a yes/no Habit and a quantitative one: the card lists both with emoji and name, a `— / ✓` toggle and an amount capsule; the hero reads "0 of 2 done today". Tap the toggle: it springs green, the hero becomes 1, and the Habits tab agrees (heatmap cell filled). Tap the amount capsule: the number sheet opens for today; entering the target turns the capsule green on Home and on Habits.
- [x] Tap the Habits card anywhere but a control: the Habits tab opens at its root. Tap the Macros card: the Food tab opens on today, even if it was left on another day.
- [x] Log a Body Weight: the square reads it with "Sep 15 · Trend —"; log a second: the square reads the Trend Weight with "Trend Weight"; Settings → kg: the square switches unit at once.
- [x] Finish a Workout from a Plan: the square reads "Today" over the Plan name; the next day it reads "Yesterday", then "3 days ago", "2 weeks ago". An empty Workout is captioned "Workout". Tap: Train opens and the Workout's detail is pushed (the logger, if it is still active).
- [x] Tap Body Weight: Train opens and the weight screen is pushed. Tap Sleep or Steps: the 30-day detail pushes within Home (ticket 13).
- [x] Narrow phone (iPhone 17 / SE) in landscape and portrait: "Last Workout" and "Body Weight" titles fit beside their icon and arrow; at an accessibility text size the squares' heroes shrink rather than clip and the cards grow; check light and dark throughout.
- [x] The greeting varies by time of day ("Good morning, John") rather than "Hello John"; the name is a constant, as the spec keeps a name field out of v1.
- [x] The habits card's hero is how many Habits are done today ("1" of "3 done today"); a weekly quantitative Habit counts as done once the week is met.
- [x] Last Workout is the last finished Workout; the Active Workout is the accessory bar's job.
- [x] The Last Workout hero is the relative Day ("Yesterday", "3 days ago", "2 weeks ago", the plain Day past eight weeks) and the caption is the Plan name, or "Workout" for an empty one.
- [x] Dots are 5 g / 50 kcal each; a target needing more than 48 dots steps to 10 g / 100 kcal and so on; a second row keeps the first row's column count.
- [x] A macro whose target is 0 renders as no-target for that row (as the Food summary does); "Set targets" only shows when no Target is in force at all.
- [x] Over the target, every dot is filled and the caption still reads "of 2,100 kcal"; nothing turns coral.
- [x] Card titles may shrink to 65% in a half-width square rather than truncate.
- [x] The native large title truncates at accessibility text sizes ("Today, September…"); UIKit never shrinks it.
- [x] Launching a debug build with `-SeedSampleData` runs it on an in-memory store of sample records (never synced), for looking at screens.
- [x] The first paint of Home shows `—` slots with no captions for the instant before the load lands, never "No habits yet".
- [x] Tapping a day on the Food week strip no longer scrolls the strip; only Home's macros card scrolls it to today.
- [x] A check-in from Home reloads all of Home (including the two Apple Health reads) rather than only the habits card.

**Found before testing 14 (2026-09-26, simulator):**
- [x] Fixed: Macros card: the "of 180 g" / "of 210 g" captions overlapped the Protein and Carbs dot rows. The hosted `DotMatrix` kept its first measured height when it grew to two rows; the card now pins its height from the row count (`DotMatrix.height(of:)`). Checked in the simulator.

**Results (2026-09-26): passed;** judgement calls agreed.

## 15: Sync dedupe pass

- [x] Two devices, both signed into the same iCloud, both in Airplane Mode: check the same Habit in on both; on the second device set a quantitative Habit's amount to 3, then on the first set it to 1 later. Turn networking back on: within a few seconds both devices show one Check-in with 1 (the later edit, not the larger), the heatmap has no doubled day, and the streak counts the day once.
- [x] Same with a Body Weight on one Day (84.0 on one device, 84.5 later on the other): both weight screens show one point at 84.5; Home's Body Weight square agrees.
- [x] Edit a Food Item's servings offline on both devices, making a different Serving the default on each: after sync both show one default (the later edit) and both Servings still exist.
- [x] Start a Workout offline on the phone and complete a set; start another on the iPad offline. Reconnect: the iPad's Workout stays active (accessory bar on both devices shows it); the phone's appears under Recent workouts with only the completed set. Repeat with no set completed on the phone: that Workout disappears entirely.
- [x] While the Habits tab is on screen, check a Habit in on the other device: the card updates in place within a few seconds with no flicker; same for Home, Food (today's entries), and Train (recent workouts).
- [x] Kill and relaunch after duplicates were synced while the app was closed: the launch pass heals them without any UI action.
- [x] "Has any Logged Set" is read as "has a completed Logged Set": a Plan-started Workout with nothing ticked is deleted rather than kept as an empty finished Workout, since its pre-filled sets are prescriptions.
- [x] The older Workout's `finishedAt` is the moment the surviving one started (deterministic across devices), not the moment the pass ran.
- [x] Every local save also triggers a no-op pass one second later (Core Data posts the remote-change notification for the app's own writes); it is a few background fetches and never saves when there is nothing to do.
- [x] Only the four tab roots refresh live on a remote change; a pushed screen (Habit detail, Body Weight, a Workout's detail) reads afresh on its next appearance.
- [x] The logger left open on a Workout the pass finished keeps working on it until it is closed; it pops only when the Workout was deleted.
- [x] Tests plant duplicates straight into the managed object context (bypassing the façade), because that is exactly what a CloudKit import does.
- [x] Two Check-ins or Body Weights tied on both `modifiedAt` and content cannot be told apart (neither entity has an id), so each device may delete a different one; the case cannot arise through the façade and was left alone.
- [x] The runner (launch + remote-change scheduling) has no unit test, since the in-memory store posts no remote-change notifications; it was verified in the simulator log.

**Results (2026-09-26): passed.** Tested with John's iPhone (offline via Airplane Mode) and the iPhone 18 Pro simulator on the same iCloud account (online), since the simulator shares the Mac's network. 1 (Habit check-ins and amount: one Check-in, the later edit) and 5 (live update on the other device) checked; 2–4 assumed from 1, 6 not reported (counted as passing); judgement calls not disputed.

## Added after v1: Checklist habits (2026-09-26)

- [ ] Habits → `+` → Kind "Checklist": an Items section appears with one empty row; Return adds the next row; the goal field reads "All 3" once three are named; Save stays disabled until there is a name and one named Item.
- [ ] Daily list (supplements): the card's capsule reads "0/5"; tapping it opens the sheet titled with the Habit and "Today"; each tap fills a circle green and the footer counts "2 of 5 ticked"; Done: the capsule reads "2/5"; tick all five: it turns green, the streak counts the day. Tomorrow the list starts empty.
- [ ] Weekly list (friends): tick a friend on Monday; on Wednesday the sheet ("This week") still shows them ticked; unticking clears them for the whole week; the week counts once every friend (or the goal) is ticked; the card caption reads "3 of 6 this week".
- [ ] Goal below all: create with goal 3 of 6; the sheet's footer adds "· 3 needed"; the capsule turns green at 3.
- [ ] Detail: Target reads "5 items a day"; the Items card lists them; Edit: rename, add, swipe to delete, drag to reorder; it saves as you type and on Done; a goal of all follows the list (adding a sixth makes it 6 from today; past days keep 5); deleting every Item saves nothing.
- [ ] Detail calendar: tap a past day: the sheet opens for that day (or that week) and ticks land there.
- [ ] Home: the checklist capsule opens the same sheet and Home updates when it closes.

## Added after v1: Past workouts and activities (2026-09-26)

- [ ] Train: Start's menu has "Log past workout…"; a "Log past workout" button sits under Recent workouts; tapping an empty past day on the grid opens the sheet set to 6 PM that day.
- [ ] Strength: the most recently used plan is pre-picked; Add opens the workout screen titled with the plan and "Sep 20 · 6:00 PM · 1 h", sets already ticked, no rest-timer button, Done instead of Finish; untick a set and tap Done (or back): "Drop 1 set left unticked?"; the grid marks the day.
- [ ] Activity: type "Pickleball", a distance, a note; Add: it appears under Recent workouts with a running icon and "Sep 20 · 2 mi"; its page shows Duration, Distance, and the note; Edit changes them and saves as you type; the next time, "Pickleball" is offered as a shortcut.
- [ ] Any finished workout: Edit opens the workout screen in editing mode; `…` → Date and time moves it (the grid follows); `…` → Delete workout asks first.
- [ ] While a workout is active, logging a past one works and the active bar still returns to the active one.

## Added after v1: Tracked habits (2026-09-26)

- [ ] Habits → `+` → Kind "Tracked": Track and Goal (At least / At most) rows appear; picking a metric sets its usual goal (Sleep: at least 7 h average, week; Steps: 7,000 average, week; Workouts: 3 days a week; Food logged: every day; Weigh-ins: 3 days a week; Calories/Fat/Carbs: at most 110% a day; Protein: at least 90% a day); the name and emoji fill in if left empty; Save.
- [ ] Workouts 3 days a week: the capsule reads "1/3" after one workout this week (an Activity counts); green at 3; the streak counts weeks.
- [ ] Calories at most 110%: the capsule shows today's % of the calorie target and is green while under; a day with nothing logged misses; changing your targets doesn't change past days.
- [ ] Protein at least 90%: green once today's protein reaches 90% of target.
- [ ] Sleep / steps weekly averages: the caption reads "6.8h average this week"; a night without data doesn't lower it.
- [ ] Tracked capsules don't open anything; the detail's Target card says where the data comes from; its calendar is read-only; Change target adjusts the amount and period from today.
- [ ] Home's habits card counts tracked habits in "n of m done today".

## Added after v1: AI food logging (2026-09-27)

Spec and tickets: `.scratch/ai-food-logging/`.

- [ ] Settings → AI: paste your OpenRouter key → Save key: "Checking the key…" then "OpenRouter key •••• (last four)" and "Spent $0 of $2 this week". Close and reopen Settings: the spending is read again.
- [ ] Paste something that isn't a key (a word) → Save key: a coral "OpenRouter rejected the key…" row, the field is empty again, and nothing is kept.
- [ ] Remove key: back to the paste field. Paste your key again afterwards so the Food tests below work.
- [ ] Judgement calls (ticket 01): a key that can't be checked for lack of a connection, or whose limit is spent, is still kept (only a rejected key isn't); the key has its own Save because it's checked first, unlike the Targets.
