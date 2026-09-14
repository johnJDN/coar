# 15: Sync dedupe pass

**What to build:** Two devices syncing offline can create duplicates CloudKit cannot prevent (ADR 0002). After every remote-change import and once on launch, a pass makes both devices converge: for one-Check-in-per-Habit-per-Day, one-Body-Weight-per-Day, and one-default-Serving-per-Food-Item, the latest `modifiedAt` survives; for the Active Workout, the later `startedAt` stays active and the older is finished if it has any Logged Set, deleted if none. Rule as decided in `.scratch/data-model/issues/01`.

**Blocked by:** 03, 04, 06, 09

**Status:** ready-for-agent

- [ ] Pass runs on `NSPersistentStoreRemoteChange` and on launch, on a background context, saving once
- [ ] Check-in duplicates (same Habit + Day): keep latest `modifiedAt`, delete others — including quantitative ones (no summing, no larger-wins)
- [ ] Body Weight duplicates (same Day): keep latest `modifiedAt`
- [ ] Default Serving duplicates (same Food Item): keep latest `modifiedAt` as default, clear the flag on others (do not delete Servings)
- [ ] Active Workout duplicates: later `startedAt` remains active; older gets `finishedAt` set if it has any Logged Set, else deleted
- [ ] UI reflects the survivor via the normal diffable snapshot path; no manual reloads
- [ ] Tests (façade): construct each duplicate case in the in-memory container, run the pass, assert survivors and side effects; idempotent on a second run
