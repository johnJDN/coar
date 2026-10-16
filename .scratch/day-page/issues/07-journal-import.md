# 07: Journal import

**Spec:** `../spec.md`

**Status:** ready-for-agent

Option 1 in `../spec.md`: a folder John picks once (security-scoped bookmark, device-local; iCloud Drive files may need downloading first); on each open, read the export folder, read entries not yet seen, split each into events on device (`FoundationModels`), store the events (not the text). Only entries from the last 30 days; older ones are skipped for now. Blocked on a real export to read its format.

## Comments
- 2026-10-16 (John): cap at the last month for now; the overnight backlog is for later.
- 2026-10-16 (agent): Looked at John's export (structure only, no text read or shown). It's the
  Mac's File → Export "website" format: a folder, not a ZIP. `iCloud Drive/Coar/AppleJournalEntries/`
  holds `index.html`, `Resources/` (an icon only), and `Entries/` with one HTML file per entry,
  named `YYYY-MM-DD_<Title_with_underscores>.html` (2,414 files; 100 dates have more than one).
  In each: `div.pageHeader` is the date ("Friday, October 10, 2026", no time), `div.title` the
  title, `div.bodyText` then `p.p2 > span.s2` paragraphs (`p.p3` are blank lines); an empty
  `div.assetGrid`. No time of day, no location, no photos. So: identify an entry by its file
  name, re-read it when its text changes (keep a hash), take the Day from the file name, and
  times only from what the text says. John exports from the Mac, the same way each time, and
  each export is the whole journal: Coar skips what it has read.
- 2026-10-16 (agent): At John's request, read 14 entries (two a year, 2020–2026, varied months)
  to learn how they're written. Structure only recorded here:
  - The header reads "Weekday, Month D, YYYY" followed by the title in the same line. One line
    per thing done, in order, blank lines between groups. Times are sparse and loose ("at
    2:30", "around 9", "til like 4"); order lets untimed lines sit between timed ones.
  - "Writing this at 1:46" is when it was written: skip it.
  - 2020–22: title "Woke up at..." continuing into the first line; meals under `######
    Breakfast` / `Lunch` / `Dinner`. 2023: "BREAKFAST" / "DINNER". 2024 on: the title is the
    weekday ("WEDNESDAY"); 2025–26 fewer meal headings, shorter.
  - Up to about 2025, entries end with "Written at:", an address, an Apple Maps link with
    `ll=lat,lon`, and often a weather sentence. Parse the place (and the coordinates) for a
    Day's place; drop the block from what the model reads. Newest entries (Oct 2026) lack it.
  - The Day can be off by one: the file name can be the day after the header (written after
    midnight), and a weekday title can disagree with the header by a day ("WEDNESDAY" on a
    Tuesday). Use the header's date; when the title is a weekday one day away, use the title's.
  - Meals: shown as journal meal events only on Days without a Coar food log; where Coar has
    Entries, those win and the journal's meal lines aren't shown twice.
- 2026-10-16 (John): writing after midnight, he moves the entry's date back to the day it's
  about (the time still shows ~1 AM) and titles it with that day's weekday ("MONDAY"). So the
  Day rule is: a weekday title wins, as the date within one day of the header that falls on
  it (a mismatch means the date wasn't moved back); with no weekday title, the header date.
  Ignore the file name's date and the entry's time of writing.
