# 04: Add sleep (naps and sleep the Watch missed)

**What to build:** John (2026-10-16) woke at 5, lay awake until 7, slept again about 8 to
9:30, and the Watch didn't record the second sleep. "yes build the add sleep button".

**Status:** done

- [x] Add sleep on the Sleep page's overview card, beside History: fell asleep, woke up
      (date and time, never the future, at most 16 hours), the length
- [x] Saved to Apple Health as "Asleep" (`HKCategoryValueSleepAnalysis.asleepUnspecified`),
      with its own permission prompt so Home's tiles never go back to Connect
- [x] The page reloads: the time joins the Night it belongs to (6 PM to 6 PM)
- [x] Test: a nap three hours after waking adds to Time Asleep but keeps the wake time

## Comments

- 2026-10-16 (agent): Checked in the simulator: adding an hour took last night from 6h 47m
  to 7h 47m, the wake time stayed 7:08, the score went 86 → 95. Left as deliberate:
  - **Only adding.** Apple lets an app delete only its own samples, so Coar can't remove
    or trim what the Watch recorded; that's done in the Health app.
  - **A nap more than an hour after waking is a second sleep**: it adds to Time Asleep and
    the score's duration but doesn't move the wake time or bedtime.
  - No undo in Coar for an added sleep yet; delete it in Health (Sleep → Show All Data).
