# 15: Sync dedupe pass

**What to build:** Two devices syncing offline can create duplicates CloudKit cannot prevent (ADR 0002). After every remote-change import and once on launch, a pass makes both devices converge: for one-Check-in-per-Habit-per-Day, one-Body-Weight-per-Day, and one-default-Serving-per-Food-Item, the latest `modifiedAt` survives; for the Active Workout, the later `startedAt` stays active and the older is finished if it has any Logged Set, deleted if none. Rule as decided in `.scratch/data-model/issues/01`.

**Blocked by:** 03, 04, 06, 09

**Status:** done

- [x] Pass runs on `NSPersistentStoreRemoteChange` and on launch, on a background context, saving once
- [x] Check-in duplicates (same Habit + Day): keep latest `modifiedAt`, delete others — including quantitative ones (no summing, no larger-wins)
- [x] Body Weight duplicates (same Day): keep latest `modifiedAt`
- [x] Default Serving duplicates (same Food Item): keep latest `modifiedAt` as default, clear the flag on others (do not delete Servings)
- [x] Active Workout duplicates: later `startedAt` remains active; older gets `finishedAt` set if it has any Logged Set, else deleted
- [x] UI reflects the survivor via the normal diffable snapshot path; no manual reloads
- [x] Tests (façade): construct each duplicate case in the in-memory container, run the pass, assert survivors and side effects; idempotent on a second run

## Comments

- 2026-09-17 (agent): Implemented. Rule: `DedupePass` (`Coar/Store/Store+Sync.swift`) runs over any
  context and saves once: Check-ins group by Habit + Day and Body Weights by Day, the latest
  `modifiedAt` stays and the rest are deleted (a `modifiedAt` tie breaks on amount / kilograms,
  so two devices pick the same row); default Servings group by Food Item, the latest keeps the
  flag and the others lose only the flag; Active Workouts keep the later `startedAt`, and an
  older one is finished the way Finish does it (uncompleted sets dropped, `finishedAt` = the
  survivor's `startedAt`) when it has a completed Logged Set, else deleted. Rows the pass
  changes get `modifiedAt` stamped like any façade write; nothing is saved when there is
  nothing to do. Façade: `Store.runDedupePass()` runs it on a background context, the view
  context merges before it returns, and it posts `activeWorkoutDidChange` when a Workout was
  touched (the accessory bar re-reads). Scheduling: `SyncDedupeRunner`, owned by the app
  delegate for the live store (not the unit-test host), runs once at launch and after each
  `NSPersistentStoreRemoteChange`, one run at a time with a one-second settle so an import
  burst coalesces, and posts `Store.remoteChangesDidMerge` after each run. UI: the four tab
  roots observe that notification (`UIViewController.observeRemoteChanges`, `Coar/Shell/
  RemoteChanges.swift`) and, only while on show, re-read through the façade and apply their
  snapshot exactly as on appearance; pushed screens read afresh on their next appearance.
  Verified on the iPhone 17 simulator: the launch pass ran, CloudKit's own setup writes
  triggered two more runs a second apart, then nothing for 20 s. Tests: 7 through the façade
  (`SyncDedupeTests`; duplicates planted straight into the context, as an import lands them),
  each asserting the survivor, the side effects, and an empty second run; suite green at 217.
  Left as deliberate (see `human-testing.md`): "has any Logged Set" reads as "has a completed
  Logged Set", since a Plan start pre-fills uncompleted sets that are prescriptions, not data;
  the older Workout's `finishedAt` is the survivor's `startedAt`; the store posts the
  remote-change notification for the app's own saves too, so every local write runs a cheap
  no-op pass a second later; a logger open on a Workout the pass finished keeps working on it
  until closed.
