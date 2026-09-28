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

**Status:** done

- [x] Draft file:
  - read when the sheet opens, written on every change;
  - a line that was "checking" when the app quit is sent again on open;
  - a missing or corrupt file starts an empty draft and is logged, never a crash
- [x] Clear in the Describe tab's `…` (no confirm: it's a draft, and typing it again is cheap)
- [x] Offline:
  - a `URLError` for no connection moves the line to waiting;
  - `NWPathMonitor` sends every waiting line again;
  - no retry loop while there's no path
- [x] Normalisation shared with 04 (lowercase, trim, collapse spaces, read a leading quantity)
- [x] Cache:
  - a JSON file in Caches, at most 500 lines, least recently used dropped first;
  - a hit is labelled with its original source;
  - library matches aren't cached
- [x] Tests (pure):
  - draft encode/decode round-trip;
  - a corrupt file gives an empty draft;
  - normalisation;
  - the cache's least-recently-used drop and hit;
  - waiting → checking when a path appears
- [x] Check by hand: type offline in the simulator (Network Link Conditioner, or the Mac's Wi-Fi off), close the sheet, reopen it, reconnect, and the lines fill in

## Comments

- 2026-09-27 (agent): Implemented.
  - **The draft file.** `DescribeDraftFile` (`Coar/Food/DescribeStorage.swift`) writes the
    draft to `describe-draft.json` in Application Support after every change, from a
    `didSet` on the controller's draft.
    - It uses atomic writes and complete-until-first-unlock protection.
    - `load()` resumes it: a line that was checking goes back to typing and is sent again.
    - A missing or unreadable file gives an empty draft, and the failure is logged.
  - **Clear** is in a "…" menu beside Add, shown only on Describe. It's disabled while
    nothing is typed. There's no confirm, since it's only a draft.
  - **Offline.** An `NWPathMonitor` sends every waiting line when a path appears. There's no
    timer, so nothing loops while offline.
  - **The cache.** `EstimateCache` is a value: at most 500 lines keyed by
    `FoodText.normalised` (lowercase, whitespace collapsed), least recently used dropped
    first. A hit counts as a use.
  - `CachingFoodEstimator` wraps the real estimator in the app.
    - It answers from the cache first and keeps every loggable answer.
    - Failures and impossible numbers aren't kept.
    - The cache is written to `estimate-cache.json` in Caches after each new answer, behind
      a lock.
  - **Normalisation.** The spec had it read a leading quantity here. That's left for 04,
    where it matters: in the cache, "2 eggs" and "3 eggs" are rightly different lines.
  - **Tests:** `DescribeStorageTests` (6): the draft round-trip with resume, missing and
    corrupt files, normalisation, the least-recently-used drop, a repeat answered without a
    request (including after a relaunch), and failures and impossible numbers asked again.
    Suite green at 288.
  - **Checked in the simulator:**
    - seeded two lines, closed the sheet, relaunched without the seed, and the lines were
      there;
    - the waiting line was sent again at open;
    - Clear emptied the draft and disabled Add.
  - **Offline recovery wasn't checked in the simulator,** since it shares the Mac's network.
    John checks it with Airplane Mode.
  - Left as deliberate:
    - a cache hit keeps the source it was first given;
    - the draft keeps no instant: Add uses the sheet's time, shown under its title;
    - a cache hit still flashes "Checking…" for a frame.
