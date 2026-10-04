# Coar product brief

The owner's vision as stated before any code was written. `DESIGN.md` covers how it
looks; this covers what it does. Open questions at the bottom are for `/grill-with-docs`.

## Purpose

A minimalist personal tracker for: sleep, steps, strength training (body weight, plus
weight and reps for every set of every workout), nutrition macros, and habits (e.g.
waking up without touching the phone, taking supplements daily). Manual tracking first.
Later: AI food-photo → macros, and an AI chat coach that uses all of the user's data as
context, possibly with on-device models.

Single user, no accounts. Both dark and light mode. iOS 26 minimum. Units default to lbs
(stored as kg, ADR 0004).
The owner plans to get an Apple Watch (or a Fitbit; note Fitbit does not write to
HealthKit, so the architecture favours the Watch).

## Tabs

### Home

- Greeting: "Hello John" (the name is hardcoded for now).
- Top to bottom, on one screen: today's macros (a calorie ring with what is left, and a bar
  each for protein, fat, carbs; taps go to Food), the habits checklist (inline check-in;
  check-in habits still to do, with done ones behind Show done; taps go to Habits), then a
  row of four small tiles: Sleep | Steps (push a 30-day detail in Home's stack) | Weight
  (switch to Train and push the screen) | Training (workout days this week; switch to Train).
- Sleep: a night belongs to the day you woke; the number is time asleep (awake and
  in-bed excluded), matching the Health app.

### Habits

- One rectangular card per habit, each with an emoji and a name.
- Classic habit heatmap: 7 rows (one per weekday), enough columns for about six months.
- Every habit has a target amount and a period, day or week (Monday to Sunday): "no
  phone on waking" is 1 per day, "gym" is 3 per week, "pages read" is 20 per day.
  Targets are dated, so raising one never repaints history.
- Two kinds of habit:
  - **Quantitative** (e.g. pages read): cell colour intensity scales with the amount
    against the target, in four buckets.
  - **Yes/no** (e.g. no phone on waking, gym): a single colour for done. There is no
    recorded "miss"; an empty day is the miss.
- Weekly habits show a week-met dot above each heatmap column.
- Today's check-in is done directly from the tab; one check-in per day, and entering a
  quantity sets the day's total.
- The card's hero number is the streak, counted in the habit's period ("12 days",
  "4 weeks"); weekly habits caption it with "2 of 3 this week".
- Tapping a habit opens a detail page with a calendar to retroactively edit check-ins.
- Habits are archived, not deleted; archived habits keep their history. An archived habit can
  be deleted permanently from the Archived list, with its check-ins.

### Food

- Manual entry for now (no food database API yet; USDA / Open Food Facts / AI later).
- Layout modelled on MacroFactor's food log: a horizontally scrollable week date strip
  (day number over weekday, today marked), a macro summary row (consumed / target with
  a thin bar for calories, P, F, C; Home has a ring and bars), then a vertical hourly timeline with a "+" per hour
  slot; entries sit on the rail at their time.
- Macros tracked: calories, protein, fat, carbs. Nothing else.
- **Food items** (eggs, chicken breast, …) with one or more named servings, each with
  its macros and optionally its gram weight; one serving is the default.
- **Meals**: named groups of food items in fixed quantities.
- An **entry** is an item or meal eaten at a time, in a quantity. Entries snapshot their
  macros (ADR 0003); a meal entry is one row on the timeline and keeps its breakdown.
- Macro targets are dated; a past day is judged against the target in force then.
- The "+" sheet has Foods / Meals segments; Search arrives with a food database.
- Food items and meals are archived, not deleted; their Archived pages can delete one
  permanently (logged entries keep their numbers).

### Train

- Root screen: month grid of workout days, Start (from a plan or empty), plans, recent
  workouts; a row of chips pushes Exercises, Body Weight, and Progress Photos.
- **Exercises**: user-created catalogue: name, primary muscle group (fixed list),
  optional equipment (free text).
- **Plans**: a plan has N exercises; each exercise has N planned sets, each with a target
  weight and a rep range (min–max; a single number is min = max).
- **Start a workout** from a plan (or from nothing) and log weight and reps per logged
  set as you go. A workout deep-copies its plan (ADR 0003). Several workouts on one day
  are allowed. At most one is active; it
  survives app kill; one left open 12+ hours is offered "finish or discard" on launch.
  Finish drops sets that were never completed and offers to update the plan's target
  weights to today's.
- **Supersets**: adjacent exercises linked in a plan; the logger keeps both cards in
  place with no auto-advance; set counts may differ.
- **Rest timer**: auto-starts on set completion (after the last exercise of a superset
  group), per-exercise default duration with a 120 s fallback, lives in the accessory bar.
- **Exercise detail page**: progression as estimated 1RM (Epley) from each workout's best
  set, plus a list of recent sets.
- **Body weight**: one per day (logging again replaces), written to HealthKit (not read
  back in v1); chart shows
  raw points and a smoothed trend weight as the hero.
- **Progress photos**: camera or library, dated, not tied to a weight; grid plus a two-up
  compare captioned with date and nearest body weight.
- Exercises and plans are archived, not deleted; the Archived lists can delete one
  permanently (workouts keep their sets). A finished workout can be deleted from its page.

### Not tabs

- **Coach** (future): lives in the bottom accessory bar, not a tab.
- **Settings**: sheet from an avatar button: targets, units, HealthKit access. iCloud is
  always on (no toggle); name returns as a field when it stops being hardcoded.

## Settled

Everything above was grilled on 2026-09-13; the vocabulary is in `CONTEXT.md` and the
load-bearing decisions are ADRs 0003–0005. Day-keyed records (check-ins, body weight,
workouts, photos) store the local calendar day; entries store an instant plus their day.
Records CloudKit can duplicate across devices are deduped by latest `modifiedAt`
(`.scratch/data-model/issues/01-sync-duplicate-merge-rule.md`).

## Open questions (for grilling)

None. New ones go here as they appear.
