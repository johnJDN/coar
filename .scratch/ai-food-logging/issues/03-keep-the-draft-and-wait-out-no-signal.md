# 03: Keep the draft and wait out no signal

**What to build:**
- **The draft is kept.** Unlogged lines survive closing the sheet and quitting the app: they're
  a JSON file in Application Support on this iPhone, written on every change. `…` → Clear
  drops them.
- **Offline lines wait.** With no connection a line says "Waiting for connection" and is sent
  when `NWPathMonitor` reports a path while the sheet is open.
- **Repeated lines are free.** A line whose normalised text was estimated before fills
  instantly from a device-local cache.

Spec: stories 5, 22, 23, "The Describe draft lives on this iPhone", and "Estimating" step 2.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Draft file:
  - read when the sheet opens, written on every change;
  - a line that was "checking" when the app quit is sent again on open;
  - a missing or corrupt file starts an empty draft and is logged, never a crash
- [ ] Clear in the Describe tab's `…` (no confirm: it's a draft, and typing it again is cheap)
- [ ] Offline:
  - a `URLError` for no connection moves the line to waiting;
  - `NWPathMonitor` sends every waiting line again;
  - no retry loop while there's no path
- [ ] Normalisation shared with 04 (lowercase, trim, collapse spaces, read a leading quantity)
- [ ] Cache:
  - a JSON file in Caches, at most 500 lines, least recently used dropped first;
  - a hit is labelled with its original source;
  - library matches aren't cached
- [ ] Tests (pure):
  - draft encode/decode round-trip;
  - a corrupt file gives an empty draft;
  - normalisation;
  - the cache's least-recently-used drop and hit;
  - waiting → checking when a path appears
- [ ] Check by hand: type offline in the simulator (Network Link Conditioner, or the Mac's Wi-Fi off), close the sheet, reopen it, reconnect, and the lines fill in
