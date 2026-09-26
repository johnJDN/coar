# Coar v1

Status: ready-for-agent

Vocabulary is `CONTEXT.md`; decisions with lock-in are ADRs 0001–0005. Cross-cutting
model tickets live in `.scratch/data-model/`. This spec is the product as grilled on
2026-09-13 and is the source for implementation tickets.

## Problem Statement

John tracks five things that together describe whether he is getting healthier: habits,
food macros, strength training, body weight, and the sleep and steps his phone already
records. Today that lives across several apps and a notebook, none of which share
history, all of which are heavier than a single-user tool needs to be, and none of
which are trustworthy over time: editing a food's macros rewrites six months of history,
changing a plan rewrites past workouts, and a target change repaints a successful cut
as failure. He wants one minimal iOS app where every number is his, every day is a
record of what happened, and nothing silently changes underneath him.

## Solution

A four-tab iOS 26 app — Home, Habits, Food, Train — with no accounts, synced through
the user's own iCloud, that treats history as immutable fact. Habits are a target over a
period with a heatmap and streak; Food is a per-day timeline of Entries against dated
Targets; Train is Plans, Workouts with a live logger and rest timer, Exercise
Progression, Body Weight, and Progress Photos; Home is a glance at today. Sleep and
steps are read from HealthKit and never stored. Every screen follows `DESIGN.md`.

## User Stories

### Shell and Home

1. As John, I want four tabs (Home, Habits, Food, Train) with native Liquid Glass chrome, so that the app feels like part of iOS 26 rather than a web view.
2. As John, I want Home to greet me by name and show today's date as the title, so that the screen reads as "today".
3. As John, I want a full-width habits card on Home with each habit's check-in control inline, so that I can check in from Home without opening the Habits tab.
4. As John, I want a full-width macros card on Home showing today's consumed vs target as a `DotMatrix` per macro, so that I know how much room I have left today.
5. As John, I want a Sleep square on Home showing last night's time asleep, so that I see how I recovered.
6. As John, I want a Steps square on Home showing today's step count, so that I know whether to walk more.
7. As John, I want a Body Weight square on Home showing my latest Trend Weight, so that I see the direction without the noise.
8. As John, I want a Last Workout square on Home showing the last Plan name and how long ago, so that I know whether I'm due.
9. As John, I want tapping the habits card to open the Habits tab and tapping the macros card to open Food, so that Home is a launcher, not a duplicate.
10. As John, I want tapping Sleep or Steps to push a 30-day detail within Home, so that I can see a trend without leaving the tab.
11. As John, I want tapping Body Weight or Last Workout to switch to Train and push the matching screen, so that there is exactly one weight screen and one workout screen.
12. As John, I want an avatar button on Home that opens Settings as a sheet, so that settings are reachable but out of the way.
13. As John, I want every Home card to stay in place and show `—` when its data is missing, so that a missing target or an unauthorised HealthKit never collapses the layout.

### Habits

14. As John, I want to create a habit with an emoji, a name, a kind (yes/no or quantitative), a target amount, and a period (day or week), so that "no phone on waking", "gym 3× a week", and "read 20 pages a day" are all one kind of thing.
15. As John, I want each habit shown as a card with its emoji, name, today's check-in control, a streak hero number, and a heatmap, so that everything about a habit is one glance.
16. As John, I want a yes/no habit's check-in control to be a two-state toggle, so that checking in is one tap.
17. As John, I want a quantitative habit's control to show today's total and open a compact number sheet with quick-add chips, so that "10 more pages" is one tap but the day still has one total.
18. As John, I want at most one Check-in per habit per day, with re-entry replacing the total, so that retroactive edits are unambiguous.
19. As John, I want the heatmap to have 7 rows with Monday on top and about six months of columns, so that it reads like the habit heatmaps I already know.
20. As John, I want yes/no cells to be a single accent colour when done and `surfaceSunken` otherwise, so that a miss is visible without me logging it.
21. As John, I want quantitative cells to scale in four intensity buckets by amount ÷ the period's target, so that a big day looks bigger and a small day still counts.
22. As John, I want weekly habits to show a week-met dot above each column, so that I can see which weeks hit 3 of 3 even when the cells can't.
23. As John, I want my streak counted in the habit's own period ("12 days", "4 weeks"), so that a weekly habit isn't judged daily.
24. As John, I want the current period to count toward the streak once met and only break it once it ends unmet, so that a 2-of-3 week on Wednesday isn't shown as broken.
25. As John, I want weekly habits to caption the streak with "2 of 3 this week", so that I know what's left.
26. As John, I want to tap a habit to open a detail page with a calendar, so that I can fix a missed check-in from last Tuesday.
27. As John, I want to edit a habit's target and period from its detail page as a dated change, so that raising a target never repaints history.
28. As John, I want to reorder habits manually, so that the tab reflects my priorities.
29. As John, I want to archive a habit rather than delete it, and restore it later, so that a year of check-ins survives a misclick.
30. As John, I want an Archived section at the bottom of Habits with restore and delete-permanently, so that archived things are findable but out of the way.

### Food

31. As John, I want the Food tab to open on today with a horizontally scrolling week date strip, so that I can flick back a few days.
32. As John, I want a compact summary row with consumed / target and a thin bar for calories, protein, fat, and carbs, so that the numbers sit above the timeline without pushing it down.
33. As John, I want a vertical hourly timeline with a "+" per hour and Entries placed at their time, so that the day reads chronologically.
34. As John, I want to create a Food Item with a name and one or more named Servings, each with its four macros and optionally its gram weight, one marked default, so that "1 egg" and "100 g" can both exist on the same item.
35. As John, I want to create a Meal as a named group of Food Items in fixed quantities, so that "chicken & rice" is one thing to log.
36. As John, I want the "+" sheet to have Foods and Meals segments that filter as I type, with a "New food" action, so that logging my own catalogue is fast without a database.
37. As John, I want logging a Food Item to pick a Serving and a quantity, so that "1.5 × 100 g" is expressible.
38. As John, I want logging a Meal to create one Entry on the timeline with a quantity multiplier, so that half a recipe is 0.5 and the timeline stays readable.
39. As John, I want a Meal Entry to keep its component breakdown in its detail view, so that I can see what it was made of.
40. As John, I want every Entry to keep its own copy of the name, Serving name, quantity, and macros at log time, so that editing "Eggs" later never changes what I ate.
41. As John, I want to edit or delete an Entry, including its snapshotted macros, so that correcting the past is done on the past.
42. As John, I want macro Targets to be a dated series where I edit only the current one, so that a past day is judged against the target that applied then.
43. As John, I want a day before my first Target, or with no Target at all, to show `—` in the target slots and no bar fill, so that a missing target isn't shown as 0%.
44. As John, I want to archive Food Items and Meals rather than delete them, so that re-log references stay clean.

### Train

45. As John, I want the Train root to show a month grid of workout days, a Start action, my Plans, and recent Workouts, so that the screen I open at the gym is the training flow.
46. As John, I want a row of chips under the grid for Exercises, Body Weight, and Progress Photos, so that catalogue and body tracking are one tap away without cluttering the root.
47. As John, I want tapping a grid day to open that day's Workout, or a short list if there were several, so that history is browsable by date.
48. As John, I want to create an Exercise with a name, a primary Muscle Group from a fixed list, and optional free-text equipment, so that volume can be aggregated later.
49. As John, I want to create a Plan as an ordered list of Exercises, each with Planned Sets holding a target weight and a min–max rep range, so that "3 × 5" and "3 × 8–12" are both expressible.
50. As John, I want to mark adjacent Exercises in a Plan as a Superset, with different set counts allowed, so that A1/A2 pairs match how I actually train.
51. As John, I want to start a Workout from a Plan, so that the logger opens pre-filled with my targets.
52. As John, I want to start an empty Workout and add Exercises as I go, so that a drop-in session is possible.
53. As John, I want a Workout to be a full copy of its Plan at start time, so that editing the Plan next month never rewrites what I lifted.
54. As John, I want the live logger to show an `ExerciseCard` per Exercise with `SetRow`s pre-filled from the Planned Sets, so that logging is confirming, not typing.
55. As John, I want to log weight and reps and mark a set complete, and nothing else, so that logging takes seconds.
56. As John, I want to add or remove sets and Exercises mid-Workout, so that the Workout reflects what I did.
57. As John, I want superset cards to stay in place with a link icon and no auto-advance, so that fixing a number I just typed doesn't fight the scroll.
58. As John, I want a rest timer to start automatically when I complete a set, using the Exercise's default duration or 120 s, so that rest is measured without a tap.
59. As John, I want the rest timer to start only after the last Exercise in a Superset group, so that it never fires between A1 and A2.
60. As John, I want the rest timer in the bottom accessory bar, dismissible, so that it follows me across tabs.
61. As John, I want at most one Active Workout, persisted from the first tap and shown in the accessory bar when I'm elsewhere, so that closing the app mid-set loses nothing.
62. As John, I want a Workout still active 12+ hours after starting to be offered "finish or discard" on launch, so that the app never guesses my numbers.
63. As John, I want Finish to drop sets I never completed, so that history holds only sets actually performed.
64. As John, I want Finish to offer "update plan targets with today's weights?", weights only, opt-in, so that progressive overload is one tap.
65. As John, I want two Workouts on one day to be allowed, so that an AM and PM session both count.
66. As John, I want an Exercise detail page with a Progression chart of Estimated 1RM per Workout from that day's best set, so that trading reps for weight still reads as progress.
67. As John, I want a list of recent sets below the Progression chart, so that the raw numbers are one scroll away.
68. As John, I want a per-Exercise rest duration default, so that squats and curls rest differently without re-setting each time.
69. As John, I want to archive Exercises and Plans rather than delete them, so that history keeps its references.

### Body Weight and Progress Photos

70. As John, I want to log Body Weight on the Train tab, one per day with re-entry replacing, so that a day has one value.
71. As John, I want the weight screen to show Trend Weight as the hero and a chart of raw points with a smoothed trend line, so that water swings don't hide the direction.
72. As John, I want Body Weight written to HealthKit, so that the Health app agrees with Coar.
73. As John, I want to add a Progress Photo from the camera or library, dated, not tied to a weight, so that taking a photo doesn't require weighing in.
74. As John, I want a grid of Progress Photos by date, so that I can find one.
75. As John, I want a two-up compare of any two Progress Photos, captioned with date and the nearest Body Weight, so that the photos answer "did anything change?".
76. As John, I want Progress Photos synced through my private iCloud, so that losing the phone doesn't lose them.

### Sleep and Steps

77. As John, I want last night's sleep to be attributed to the day I woke and measured as time asleep excluding awake and in-bed, so that Coar matches the Health app.
78. As John, I want a 30-day sleep detail with one bar per wake-day, so that I see the pattern.
79. As John, I want today's steps as a live HealthKit sum and a 30-day detail, so that the number is current without the app storing it.
80. As John, I want Sleep and Steps to show "No data" with a tap-through to authorise when HealthKit access is missing, so that the card explains itself.

### Sync, units, settings

81. As John, I want everything I author to sync through my private iCloud without an account, so that my iPad and a future replacement phone have it.
82. As John, I want duplicates created by two devices syncing offline (Check-in, Body Weight, Active Workout, default Serving) to resolve deterministically, so that both devices converge on the same answer.
83. As John, I want to choose lbs (default) or kg in Settings and have every weight display in it, so that the unit is mine.
84. As John, I want Settings to hold macro Targets, units, and HealthKit access only, so that the sheet is short and nothing dangerous lives in it.
85. As John, I want my data to be keyed by the local day I lived, so that a late-night check-in doesn't move when I travel.
86. As John, I want light and dark mode to be the same layout with different tokens, so that neither mode feels second-class.
87. As John, I want Dynamic Type respected everywhere, so that the app is legible at my size.

## Implementation Decisions

### Stack and structure (ADR 0001)

- Programmatic UIKit shell: `UITabBarController` with four `UITab`s, `UINavigationController` per tab with large titles, `UISheetPresentationController` for Settings and the "+" sheets, `UITabAccessory` for the rest timer / Active Workout bar. No storyboards, no XIBs.
- Lists and grids are `UICollectionView` with compositional layout and diffable data sources; every update is a snapshot apply with animation. Heatmap, timeline, date strip, month grid, and the live logger are UIKit.
- SwiftUI for leaf content only: Swift Charts (Progression, sleep/steps/weight detail), `StatRing`, `DotMatrix`, thin bars, card bodies via `UIHostingConfiguration`, and the Settings form. Hosted views are values-in, closures-out.
- Design tokens exposed as both `UIColor`/`UIFont` and `Color`/`Font` from one source, per `DESIGN.md`.
- The greeting name is a constant ("John") in v1; no Settings field.

### Persistence and sync (ADR 0002)

- Core Data with `NSPersistentCloudKitContainer` mirroring to the private database. Every attribute optional or defaulted, every relationship optional with an inverse, no unique constraints, no ordered relationships; explicit `sortOrder` where order matters (Plan exercises, Planned Sets, habits, Servings).
- Every entity carries an app-set `modifiedAt`. A dedupe pass runs on every remote-change notification and once on launch: for each invariant (one Check-in per Habit per Day, one Body Weight per Day, one default Serving per Food Item), group by key, keep the latest `modifiedAt`, delete the rest. Active Workout: if more than one is active, the later `startedAt` stays active; the older is finished if it has any Logged Set, deleted if none. (`.scratch/data-model/issues/01`)
- Progress Photos are external-binary attributes so CloudKit syncs them as assets.
- No iCloud toggle. Sync status is read-only in Settings at most.
- All app-facing reads and writes go through one store façade (the primary test seam); view controllers never touch `NSManagedObjectContext` directly.

### Time (ADR 0005)

- Day-keyed records — Check-in, Body Weight, Workout, Progress Photo — store the local calendar Day at write time and never recompute it. Entries store an instant and the Day they were logged into.
- Weeks are Monday–Sunday, hardcoded. The heatmap's top row is Monday.
- Sleep: a night belongs to the wake Day; value = sum of asleep-stage samples (core, deep, REM, unspecified), excluding awake and in-bed.

### History is snapshotted (ADR 0003)

- Entry snapshots name, Serving name, quantity, and the four macros; optional reference to Food Item or Meal for re-log/grouping; a Meal Entry also snapshots its component list.
- Starting a Workout deep-copies the Plan into the Workout's own exercise rows (with Superset grouping, sort order, and the Exercise's rest default) and Planned Set targets; Logged Sets are recorded alongside. The Workout keeps a plain Plan reference.
- Targets: a dated series (effective-from Day) for macros, and a dated series of (amount, period) per Habit. Lookup "in force on Day D" returns nil when none applies; callers render `—`, never 0. (`.scratch/data-model/issues/02`)

### Units (ADR 0004)

- All mass stored in kilograms. The unit setting converts on input and display, rounding at one decimal. Applies to lifted weight and Body Weight.

### Habits

- Habit: emoji, name, kind (yes/no | quantitative), sortOrder, archived flag, and a dated target series of (amount, period ∈ {day, week}).
- Check-in: habit, Day, amount. At most one per habit per Day; writes replace. Yes/no check-ins have amount 1; toggling off deletes the Check-in.
- Streak: consecutive Periods ending at the current one that met target; the current Period counts if already met and does not break the streak until it has ended unmet. Computed, never stored.
- Heatmap cell: yes/no → binary; quantitative → bucket of amount ÷ target-in-force (≤25, ≤50, ≤75, ≥100 %). Weekly habits add one week-met dot per column. A Habit's first target also covers every Day before it, so past Days can be backfilled (changed 2026-09-22 in testing).
- Quantitative input: a compact sheet with the current total, number pad, and quick-add chips that edit the single Check-in.
- Archive rather than delete; an Archived section with restore and delete-permanently (which cascades Check-ins).

### Nutrition

- Food Item: name, archived flag, one or more Servings (name, four macros, optional grams, isDefault, sortOrder). Meal: name, archived flag, components (Food Item + Serving + quantity, sortOrder).
- Entry: instant, Day, name, Serving name, quantity, four macros, optional Food Item / Meal reference, optional component snapshot.
- The "+" sheet: `SegmentedTabs` Foods / Meals, most recently used first, type-to-filter over the user's catalogue, "New food" action, an "Archived foods" / "Archived meals" page to restore from. No Search segment. (Order and archived page changed 2026-09-26 in testing.)
- Summary row uses thin bars; Home uses `DotMatrix`. Same accents (blue protein, orange carbs, pink fat).

### Training

- Exercise: name, Muscle Group (fixed enum), equipment (free text, optional), rest default (optional seconds), archived flag.
- Plan: name, archived flag, ordered exercise rows (Exercise, sortOrder, supersetGroup), each with ordered Planned Sets (target weight kg, repMin, repMax).
- Workout: startedAt, Day, finishedAt, optional Plan reference, ordered exercise rows copied from the Plan (name snapshot, Exercise reference, supersetGroup, rest default), each with target rows and Logged Sets (weight kg, reps, completed, sortOrder).
- Active Workout invariant: at most one with `finishedAt == nil`; persisted from creation. Launch check: an active Workout older than 12 hours prompts finish/discard.
- Finish: delete uncompleted sets, set `finishedAt`, optionally write completed weights back to the Plan's Planned Sets by position (weights only).
- Rest timer: starts on set completion; for a Superset group, only when the completed set belongs to the group's last Exercise; duration = Exercise default ?? 120 s; lives in the accessory bar, dismissible.
- Superset: adjacent rows sharing a supersetGroup; unequal set counts allowed; no auto-advance in the logger.
- Progression: per Workout containing the Exercise, best Estimated 1RM by Epley (w × (1 + r/30)) over completed Logged Sets; one point per Workout; a single Workout renders one point.
- Multiple Workouts per Day allowed; the month grid marks the Day once.
- Train root layout: month grid → Start → Plans → Recent workouts; three `PillChip`s under the grid push Exercises, Body Weight, Progress Photos.

### Body

- Body Weight: Day, kg; one per Day, writes replace; written to HealthKit (write-only in v1). Trend Weight: exponentially smoothed over the series (MacroFactor-style); with fewer than 2 points the trend is `—`.
- Progress Photo: Day, image (external binary), optional caption; camera or library; grid by Day; two-up compare captioned with Day and the nearest Body Weight.

### HealthKit

- One reader protocol (sleep for a wake Day, steps for a Day, 30-day series of each) and one writer (Body Weight). Read live on appear; never persisted. Unauthorised → `No data` with tap-through to the system prompt.

### Home

- Order: habits card → macros card → 2-column grid [Sleep | Steps] [Body Weight | Last Workout]. Cards never collapse; empty slots show `—` / `No data`.

### Settings

- Sheet: macro Targets (edits the current dated entry, creating a new one effective today if changed), units, HealthKit access. Nothing else.

## Testing Decisions

- A good test exercises behaviour through a public seam with realistic inputs and asserts what the user would observe, never how it is stored. No tests reach into managed objects, contexts, or view hierarchies.
- **Seam 1 — the store façade** over an in-memory `NSPersistentContainer` (same model, no CloudKit). Tests cover: snapshot behaviour (edit a Food Item, Entry unchanged; edit a Plan, Workout unchanged), dated Targets (day before first target → nil; change today → yesterday judged by old target), one-per-Day replace semantics for Check-in and Body Weight, archive hiding from pickers while history resolves, Workout lifecycle (single active, deep copy, finish drops uncompleted, plan write-back weights only), the dedupe pass (construct duplicates, run pass, assert survivor by `modifiedAt`; active-workout exception), and Day-keying (write at a late hour in one zone, read in another, Day unchanged).
- **Seam 2 — pure rule functions**, each a value-in/value-out function with no dependencies: streak (including the pending-current-period rule for day and week), heatmap intensity bucket (yes/no vs quantitative, weekly dot), Estimated 1RM and best-of-Workout, Trend Weight smoothing (including <2 points), sleep-night attribution and stage summing, rest-timer trigger for straight sets vs Superset groups, kg↔lbs round-trip at display precision.
- HealthKit is faked behind its reader/writer protocols; tests of Home and the sleep/steps details use the fake.
- UI (view controllers, hosted SwiftUI) is verified manually against `DESIGN.md` and via SwiftUI previews for leaf components; no snapshot or UI automation in v1.
- Prior art: none in this repo (green-field). Follow XCTest with a per-test in-memory container.

## Out of Scope

- Coach (accessory-bar chat), AI food-photo → macros, any server or edge function.
- Food database search (USDA / Open Food Facts); the Search segment.
- Reading Body Weight back from HealthKit; smart-scale import.
- Habit schedules on specific weekdays; recorded misses; per-kind sync merge rules.
- RPE/RIR, warm-up flags, per-set notes, exercise thumbnails, volume-by-Muscle-Group chart.
- Progress Photo tags/poses, "device-only" photo storage, iCloud toggle.
- Watch app, widgets, a Settings name field, week-start setting, custom fonts.

## Further Notes

- Build the three shared shapes once (dated series, one-per-Day record, Day-keyed date) per `.scratch/data-model/spec.md`, and route every feature through them.
- `DESIGN.md` is the acceptance checklist for every screen; the vocabulary in `CONTEXT.md` is mandatory in code names, ticket titles, and test names.
- Suggested slicing for tickets: (1) model + store façade + rule functions with tests, (2) shell + tokens + components, (3) Habits, (4) Food, (5) Train logger + rest timer, (6) Train catalogue + Progression + body screens, (7) Home + HealthKit + Settings.
