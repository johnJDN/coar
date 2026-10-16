# The Day page, and the context behind it

John (2026-10-15/16): give Coar as much context about his days as possible, for a coach to
read later, and show it. Chosen from a longer list:

- **About me**: age, height, sex.
- **A daily mood and energy check-in.**
- **All Apple Watch workouts**, not only those linked to a Coar Workout.
- **Wrist temperature** during sleep.
- **Weather and location** ("completely welcome"; the "Don't add weather" line in DESIGN.md
  §10 came from the baseline, not from John, and goes).
- **Apple Journal entries, turned into events on a timeline.** Option 1: John exports all
  entries now and then (Settings → Apps → Journal → Export All Journal Entries) into one iCloud
  Drive folder; Coar watches that folder and reads only entries it hasn't seen whenever it
  opens. No button in Coar. Read **on device** with Apple's Foundation Models; nothing leaves
  the phone.
- **The timeline lives on a Day page**, opened from Home's date.

Not possible (checked): reading Journal directly or from Shortcuts (its only actions create
entries or open a search); reading Screen Time numbers (apps can only display them).

## The Day page

Opened by tapping Home's date ("Today, October 16"); ‹ › or a swipe moves a day. Top to bottom:

1. **Header:** the Day; the place and its weather ("Seattle · 58° light rain, high 61°");
   mood and energy for the Day (tap to set).
2. **Timeline**, in time order, one row per thing, each with its time on the rail as the Food
   timeline does: woke and fell asleep (from the Night), meals (Entries), workouts (Coar
   Workouts, and Watch workouts not linked to one), the weigh-in, and journal events. A
   journal event without a time sits at the start of its part of the day (morning, afternoon,
   evening). Tapping a row opens what it is (an Entry, a Workout, the Sleep page).
3. **Summary** at the bottom: calories against the Target, habits done, steps, sleep score.

## Data

| What | Where it lives | Why |
|---|---|---|
| Age, sex, height | Read from Apple Health; typed in Coar only if Health has none (stored) | Health already has them |
| Mood and energy | Stored per Day (new record, synced) | Coar's own |
| Journal events | Stored (new record, synced): Day, time or part of day, title, category, the entry it came from | Derived once; re-reading every launch would be slow |
| Journal entry text | **Not stored**: the events are; the text stays in Journal | Most private thing Coar would hold |
| Place per Day | Stored (new record, synced): rounded location and place name, once a Day when Coar opens | Weather for a past Day needs where you were |
| Weather | Read live from WeatherKit for the Day's place | External, like Health |
| Watch workouts, wrist temperature | Read live from Apple Health (ADR 0002) | As sleep and steps |

New record types mean a CloudKit schema deploy before the first build with them.

## Journal events

Categories: Work, Social, Exercise, Food, Health, Travel, Errands, Rest, Mood, Other. Each
event: a short title in John's words ("Lunch with Sam"), a time if the entry gives one, else
a part of the day, and the category. A food or exercise event that matches something Coar
already logged that day is linked to it rather than shown twice.

**Only the last month for now** (John, 2026-10-16): entries older than 30 days in an export are
skipped, not read. Five years is about 1,800 entries, an hour or more of on-device work; if he
wants more later, the backlog is read newest first while the phone charges overnight
(`BGProcessingTask` with external power), a chunk a night, with progress in Settings.

On device, with `FoundationModels` (`LanguageModelSession`, guided generation into a
`@Generable` type). When Apple Intelligence isn't available, entries wait and are read later.
The iOS 27 SDK also has a Private Cloud Compute model: a later step up if on-device reading
turns out too weak, still private.

## Tickets

| # | Ticket | Needs from John |
|---|---|---|
| 01 | Wrist temperature on the Overnight card and its history | |
| 02 | About me | |
| 03 | Mood and energy check-in | |
| 04 | All Watch workouts | |
| 05 | Place and weather | Turn on WeatherKit for the App ID (developer portal → Identifiers → Coar → App Services) |
| 06 | Day page | |
| 07 | Journal import | One export ZIP to look at (structure only), and the folder choice |

01–05 can ship as they're done; 06 gathers them; 07 needs a real export to build against.
Schema deploy before the build with 02, 03, 05 or 07.
