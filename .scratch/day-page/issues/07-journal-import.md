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
