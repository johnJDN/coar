# 01: Indoor walks, the inhaler, and treadmill settings

**What to build:** John (2026-11-01): he does indoor treadmill walks, recorded on the Watch as
Indoor Walk, and wants to see improvement; some walks he uses his inhaler first and some not,
and he wants to see whether it helps. VO2 max isn't the measure here: the Watch estimates it
only on outdoor walks, runs and hikes. The comparable measure is heart rate at the same speed
and incline, which the Watch doesn't know on a treadmill.

**Status:** done

- [x] A Workout note per Health Workout (new entity `WorkoutNote`, keyed by the Health Workout's
      UUID, ADR 0002): Used inhaler before, speed (stored km/h, shown mph with US units), incline %;
      an empty note is removed; dedupe keeps the latest modified
- [x] Health Workouts know whether they're walks, indoors, and the Watch's distance; indoor walks
      are named "Indoor walk"; a range read for Walks
- [x] Day page: a Watch workout row opens its note; its detail adds the settings and "inhaler"
- [x] Walks (Train chip): heart rate per indoor walk over six months, coloured by inhaler; up to
      three groups of walks at the same speed and incline (with/without inhaler, first → latest);
      every walk, each opening its note (`WalkComparison.groups`)
- [x] "Same as last time" fills the last speed and incline set on any walk
- [x] Tests (7), and a Day page fix: timeline times were an hour late after 2 AM on a Day the clocks go back (they counted elapsed seconds)

## Comments

- 2026-11-01 (agent): Left as deliberate: only indoor walks are listed (outdoor walks have VO2
  max on the Sleep page's vitals already); groups need both speed and incline, so a walk with
  only one isn't compared; the note sheet says it's for noticing patterns to raise with a
  doctor, not for deciding medication. Speed is rounded to 0.1 in the shown unit, so a typed
  3.3 mph reads back 3.3. Needs a CloudKit schema deploy (new entity) before upload.
