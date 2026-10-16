# 03: Mood and energy check-in

**Spec:** `../spec.md`

**Status:** done

Once a day, two 1–5 scales (mood: 😞–😄; energy: low–high). Where: a slim row on Home under the macros until set for today, and on the Day page header any time. Stored per Day (new record, synced, one per Day, dedupe by latest). Optionally also written to Apple Health as State of Mind (decide when building).

## Comments
- 2026-10-16 (agent): Done. `MoodEnergyView`: five faces and five bolts; one `DayMood` a Day
  (deduped). Home's "How's today?" sits under the macros until both are set, then steps
  aside (after a beat, so the pick shows); the Day page always has it. Not written to
  Apple Health's State of Mind (left for later).
