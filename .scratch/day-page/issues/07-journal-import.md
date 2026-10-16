# 07: Journal import

**Spec:** `../spec.md`

**Status:** needs-info (a real Journal export)

Option 1 in `../spec.md`: a folder John picks once (security-scoped bookmark, device-local); on each open, find the newest export ZIP, read entries not yet seen, split each into events on device (`FoundationModels`), store the events (not the text). Only entries from the last 30 days; older ones are skipped for now. Blocked on a real export to read its format.

## Comments
- 2026-10-16 (John): cap at the last month for now; the overnight backlog is for later.
