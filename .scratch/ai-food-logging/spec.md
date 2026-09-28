# AI food logging

Status: ready-for-agent

Vocabulary is `CONTEXT.md`. This feature widens **Entry** and adds **Estimate**, and ticket 02
updates the glossary. Decided in conversation with John on 2026-09-27. Supersedes the v1 Out of
Scope line "AI food-photo → macros".

## Problem Statement

Logging food in Coar today means making a Food Item first, then logging it. That suits the
thirty things John eats every week. It fails for everything else: the lasagna at a friend's
place, a restaurant bowl, a new protein bar. Each one-off means a trip through the Food Item
editor and four numbers he has to look up. Afterwards the library holds a Food Item he'll never
use again. So one-offs go unlogged or get rough numbers, and the day's totals stop being
trustworthy.

## Solution

A **Describe** tab becomes the first tab on the Food "+" sheet:
- **Typing.** Type what you ate, one food per line, like a note. A couple of seconds after you
  stop typing, each line fills in its name, portion and macros.
- **Photos.** A camera button does the same from a photo of a plate or a nutrition label.
- **Logging.** **Log** turns the filled lines into ordinary Entries at the sheet's time.
- **Your library.** Your own Food Items and Meals win whenever a line means one of them. Nothing
  joins the library unless you tap Save as food.
- **Not included:** an imported food database and a barcode scanner.

The Entry becomes the base of food logging: a name, a portion and macros that stand on their
own. They already do (ADR 0003). Food Items and Meals stay as shortcuts for things you eat often.

**Where estimates come from.** Models reached through OpenRouter with John's own key, which is
kept in the iPhone Keychain. The cheapest source is tried first:
1. The library and a cache of earlier lines (free).
2. A cheap text model for everyday foods.
3. A web-search model, only for restaurant and brand foods.
4. A vision model for photos.

There's no data-structure change, so no CloudKit schema deploy.

## User Stories

### Describing

1. As John, I want the Food "+" sheet to open on a Describe tab, before Foods and Meals, so that typing what I ate is the quickest way to log anything.
2. As John, I want to type one food per line, with Return starting a new line, so that a whole lunch is a short list rather than a form.
3. As John, I want each line to fill in its name, portion, calories and P/F/C about two seconds after I stop typing it (or at once when I press Return), so that I see the numbers while I type the next line.
4. As John, I want editing a line to re-check only that line, so that untouched lines keep their numbers and aren't paid for twice.
5. As John, I want a line I've typed before, word for word, to fill in instantly from last time, so that my regular one-offs cost nothing.
6. As John, I want one line to be one Entry ("toast with butter" is one Entry by that name), so that what I typed is what I see on the timeline.
7. As John, I want each filled line to say where its numbers came from ("Your food", "Your meal", "Estimated", "Looked up", "From photo", "From label", "Typed"), so that I know which numbers to double-check.
8. As John, I want a Log button that shows how many lines and how many calories it will log ("Log 3 · 740 kcal"), so that I know what I'm about to add.
9. As John, I want Log to log every filled line at the sheet's time and remove those lines, leaving any line that's still filling or has failed, so that one bad line doesn't hold up the rest.
10. As John, I want nothing logged until I tap Log, so that typing is never a commitment.

### Your library wins

11. As John, I want a line that is exactly the name of a saved Food Item or Meal ("protein shake", "2 eggs") to use it with no model call: its default Serving's macros, with the Entry linked like a normal log, so that my own numbers beat a guess and cost nothing.
12. As John, I want looser wording ("my usual shake", "a couple of eggs") to match a saved Food Item or Meal too, with the macros still taken from my library and never from the model, so that I don't have to remember exact names.

### Adjusting a line

13. As John, I want to tap a filled line to open it and change its quantity, with the macros scaling to match, so that "1 slice" becomes 2 without retyping.
14. As John, I want to edit a line's name, portion and four macros directly, so that a wrong estimate is fixed before it's logged.
15. As John, I want a line I give my own macros to never need a model, so that a quick "Pizza, 600 kcal" works offline and when a line fails.
16. As John, I want Save as food on a line, so that logging it also creates a Food Item with that portion as its Serving and links the Entry to it, and next time it's one tap in Foods.

### Restaurant and brand foods

17. As John, I want restaurant and branded foods ("Chipotle chicken bowl", "Quest cookie dough bar") looked up on the web rather than guessed, and labelled "Looked up", so that chain and packaged food numbers are the published ones.
18. As John, I want a failed lookup to keep the everyday estimate, labelled "Estimated", so that the line still fills in.

### Photos

19. As John, I want a camera button that takes a photo or picks one from my library and adds each food it sees as a line ("From photo"), editable like a typed line, so that a plate is logged without typing.
20. As John, I want a photo of a nutrition label to add one line read exactly from the label ("From label") with its serving ("1 bar (60 g)"), so that packaged food is as accurate as typing the label in myself. I then set how many I had.
21. As John, I want photos used only for the estimate and then discarded, so that pictures of my food aren't stored anywhere.

### Errors, offline, and the key

22. As John, I want lines typed with no connection to say "Waiting for connection" and fill in by themselves when it returns while the sheet is open, so that the gym basement doesn't stop me typing.
23. As John, I want unlogged lines kept on this iPhone when I close the sheet, and shown again when I reopen it, with a Clear action to drop them, so that nothing I typed is lost.
24. As John, I want a line the model can't read, or one with impossible numbers (negative, over 5,000 kcal), shown as failed with a coral warning and a tap to retry or type the macros, so that a bad estimate is never quietly logged.
25. As John, I want a line whose calories disagree with its macros to carry a warning caption and still be loggable once I've looked, so that a doubtful number is visible without blocking me.
26. As John, I want the Describe tab to show a `WarningCard` when there's no key ("Add your OpenRouter key", with a button to Settings), when the key is rejected, or when its spending limit is reached, each saying which, so that I know why nothing fills in.
27. As John, I want an OpenRouter key row in Settings where I paste the key once, kept in this iPhone's Keychain only and shown afterwards only as its last four characters, so that the key is never visible or synced.
28. As John, I want Settings to check the key when I save it and show what it has spent against its limit ("$0.14 of $2 this week"), so that I know it works and what it costs.
29. As John, I want to remove the key from Settings, so that I can switch keys or turn the feature off.

## Implementation Decisions

### Data: no schema change

- An Entry already stands on its own: name, Serving name, quantity, four macros, and an
  optional Food Item or Meal reference (ADR 0003). The new façade call
  `logEntry(name:servingName:quantity:macros:at:in:)` logs one with no reference, through the
  existing `makeEntry`.
- A library match logs through the existing `logEntry(foodItem:serving:quantity:)` and
  `logEntry(meal:quantity:)`, so the Entry links to its source and "most recently used" order
  keeps working.
- Save as food is one façade call and one save: create a Food Item with one Serving (the
  line's unit as its name, macros for one, grams when known), then log the Entry linked to it.
- An Entry records nothing about how its numbers were made. The "Estimated" and "From label"
  captions exist only on the Describe tab. This is deliberate: a source attribute would be a
  schema change for a caption.

### The Describe draft lives on this iPhone

- The tab's lines are a draft, not Core Data. It's a small JSON file in Application Support,
  written on every change and never synced. Each line holds an id, its text, its state and its
  result. This is how "your text is saved right away" and waiting offline work without a schema
  change.
- The draft doesn't reach an iPad. That's fine for a single user who logs from the phone.
- Log uses the sheet's instant, shown as its subtitle, not the time a line was typed.

### Estimating, cheapest first

A line is sent 2 seconds after its last edit, or at once on Return. Each step runs only if the
one before it had no answer:

1. **Exact library match (free).**
   - The text is normalised: lowercased, trimmed, spaces collapsed, and a leading "2", "1.5",
     "½" or "1/2" read as the quantity.
   - It matches when it equals the name of an unarchived Food Item or Meal, ignoring a trailing
     "s".
   - The result is the default Serving (or the Meal) × the quantity.
2. **Cache (free).** Normalised text seen before gets its last result. The cache is a JSON file
   in Caches, kept on this iPhone only, holding at most 500 lines with the least recently used
   dropped first. Library matches aren't cached, because the library can change.
3. **Text model: `google/gemini-3.1-flash-lite`**, with structured output.
   - The input is the line plus the library as short handles, not UUIDs, which cost tokens:
     `f1 "Eggs" [s1 "1 large", s2 "100 g"]`, `m1 "Post-workout shake"`.
   - The output is an estimate: name, portion (quantity, unit, grams if known), macros for the
     whole portion, `needsLookup`, and a one-line assumption.
   - It may also include `match: {handle, serving, quantity}`. A match whose handles resolve
     wins, and its macros come from the library. A match that doesn't resolve is ignored in
     favour of the estimate.
4. **Lookup: `perplexity/sonar`**, only when `needsLookup` is true (a restaurant chain, a brand,
   a packaged product).
   - Sonar can't return structured output on OpenRouter, so the prompt asks for the same JSON
     and the reply is parsed leniently: strip code fences and take the first JSON object.
   - If the parse or the request fails, the line keeps step 3's estimate, labelled "Estimated".

**Photos** use `google/gemini-3.8-flash`.
- The image is shrunk to 1,024 px on its long edge and sent as JPEG at quality 0.7. It's never
  written to disk.
- The output is structured: a list of items, each with its source (`photo` or `label`), name,
  portion and macros.
- A label item carries the label's serving and the macros for one serving, with a quantity of 1.

**How requests are made**
- Model IDs are constants in one file. Swapping one is a one-line change, not a setting.
- Every request is a `POST https://openrouter.ai/api/v1/chat/completions` with:
  - `response_format` set to a strict `json_schema` (except Sonar);
  - `provider.require_parameters: true`, so only providers that honour the schema serve it;
  - `temperature: 0`;
  - `usage.include: true`, so each request's cost goes to `Logger(category: "Food")`.
- Timeouts: 20 s for text, 40 s for a photo.
- **Stale replies are dropped.** Each request carries the line's text, and a reply for text
  that has since changed is thrown away.

**Sanity rules** are pure functions:
- A line is **failed**, and can't be logged, when any of these hold:
  - any number is negative or not finite;
  - calories are over 5,000;
  - grams are over 3,000.
- A line is **flagged** "Calories don't match the macros", but can still be logged, when
  |kcal − (4P + 4C + 9F)| > max(40, 20% of kcal).

**Errors, each shown on screen:**

| What happened | What shows |
|---|---|
| HTTP 401 | `WarningCard` "OpenRouter rejected the key" |
| HTTP 402, or the key's limit reached | `WarningCard` "Your OpenRouter key's spending limit is reached" |
| No connection | The line waits and retries when `NWPathMonitor` reports a path |
| Anything else | The line fails, with a tap to retry |

**Cost at John's use.** Assuming about ten lines a day with half answered free, one lookup a
day, and a photo every other day:

| Source | Cost |
|---|---|
| Text line | ≈ $0.0005 |
| Lookup | ≈ $0.006 |
| Photo | ≈ $0.004 |
| **Total** | **≈ $0.30 a month**, well inside the key's $2-a-week limit |

### The key

- Stored as a Keychain generic password:
  - service `com.johnnguyen.coar.openrouter`;
  - `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`;
  - not synchronizable.
- It's never logged, and never in Core Data or `UserDefaults`.
- On save, Settings calls `GET https://openrouter.ai/api/v1/key` and shows the usage and the
  limit with its reset period.
- **Before release (not this feature):** a small server holds the key, checks App Attest, and
  limits each user. The OpenRouter client takes its base URL and its auth from one place, so
  that change touches one type. ADR 0007 records this decision (ticket 01).

### Screens

- **The "+" sheet.** `SegmentedTabs` Describe / Foods / Meals, with Describe first and the
  default. The filter field shows only on Foods and Meals. DESIGN.md §11 is updated to match.
- **The Describe tab.** A list with one row per line.
  - Each row is an editable single-line text field, Reminders-style:
    - Return makes a new line below.
    - Backspace on an empty line removes it.
  - Under the text sits a caption: the result ("2 large eggs · 140 kcal · P 12 F 10 C 1") and
    its source, or the line's state ("Checking…", "Waiting for connection", a coral failure).
  - Below the list: a camera button with a menu (Take Photo / Choose Photo) and the Log button.
  - `…` → Clear.
- **The line page.** Pushed from a filled line. It follows DESIGN.md §7a "a page inside an
  editor": edits write back into the line, with no Save.
  - Fields: name, quantity, unit, a `MacroStrip`, the four macro fields, and a Save as food
    toggle.
  - Changing the quantity scales the macros.
  - Typing a macro changes the source to "Typed".
- **Settings.** A new "AI" section with an "OpenRouter key" row.

### Code shape

- `FoodEstimator` protocol, with two calls:
  - one line plus the library handles, returning an estimate;
  - one photo plus the library handles, returning a list of estimates.
- Implementations: `OpenRouterFoodEstimator` for real, and a fake in tests.
- `OpenRouterClient` makes one request. It reads the key through a `KeyStore` protocol, backed by
  the Keychain in the app and a fake in tests.
- `DescribeDraft` holds the lines and applies edits and results as value transitions. The view
  controller owns the debounce and the network tasks.

## Testing Decisions

- The same seams as v1. No test touches the network, managed objects, or view hierarchies.
- **Seam 1, the store façade:**
  - an Entry with no reference shows in `entries(on:)` and `dailyTotals`;
  - Save as food creates the Food Item and an Entry linked to it, in one save;
  - a library match logs through the existing calls.
- **Seam 2, pure functions:**
  - normalising text and matching it exactly against the library (quantity, plural, archived
    items excluded);
  - parsing structured replies (valid, missing fields, unknown handle);
  - parsing Sonar leniently (code fence, prose around the JSON);
  - the sanity rules and the calorie mismatch check;
  - the cache's least-recently-used drop;
  - `DescribeDraft` transitions:
    - an edit clears the line's result;
    - a stale reply is dropped;
    - Log takes only filled lines and leaves the rest;
    - offline lines wait;
  - mapping each error (401, 402, offline, other).
- **The real OpenRouter calls** are checked by hand in the simulator. John's key goes in through
  the simulator pasteboard (`xcrun simctl pbcopy` from `~/.config/coar/openrouter-key`) and a
  paste into Settings. It's never printed, read into the transcript, or committed.
- **UI** is checked by hand against DESIGN.md.

## Out of Scope

- Barcode scanning. Label photos cover it; revisit if logging new packaged foods starts to feel
  slow.
- An imported food database, and USDA grounding of estimates.
- The server, App Attest, and per-user limits. These come before release, like the exercise
  library.
- A note typed alongside a photo. Portions are fixed by editing the lines it adds.
- Marking an Entry as estimated once it's logged.
- The Coach.

## Further Notes

- No schema change means no `-InitializeCloudKitSchema` and no deploy for this feature. If a
  ticket turns out to need one, stop and say so first.
- As in v1: judgement calls go in each ticket's comments, and the tests plus calls are appended
  to `.scratch/coar-v1/human-testing.md`. John tests every ticket together at the end.
- Tickets 01 → 02 come first. After that, 03–06 can land in any order, and 07 comes after 05.
