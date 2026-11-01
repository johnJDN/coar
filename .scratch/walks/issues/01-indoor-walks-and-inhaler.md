# 01: Indoor walks, the inhaler, and treadmill settings

**What to build:** John (2026-11-01): he does indoor treadmill walks, recorded on the Watch as
Indoor Walk, and wants to see improvement; some walks he uses his inhaler first and some not,
and he wants to see whether it helps. VO2 max isn't the measure here: the Watch estimates it
only on outdoor walks, runs and hikes. The comparable measure is heart rate at the same speed
and incline, which the Watch doesn't know on a treadmill.

**Status:** done

- [x] A Workout note per Health Workout (new entity `WorkoutNote`, keyed by the Health Workout's
      UUID, ADR 0002): Used inhaler before, the treadmill's distance (stored in metres, shown in
      miles with US units), the average incline %; an empty note is removed; dedupe keeps the
      latest modified
- [x] Health Workouts know whether they're walks, indoors, and the Watch's distance; indoor walks
      are named "Indoor walk"; a range read for Walks
- [x] Day page: a Watch workout row opens its note; its detail adds the treadmill numbers and
      "inhaler"
- [x] Effort (`WalkEffort`): speed = treadmill distance / the Watch's duration; oxygen by the ACSM
      walking equation; each walk's heart rate moved along the line from resting heart rate (the
      period's median from the Watch, 65 without) to the walks' usual speed and incline
- [x] Walks (Train chip): heart rate at that effort per walk, coloured by inhaler; Inhaler card
      (last 8 weeks, with and without); Fitness card (first few → latest few); every walk, each
      opening its note; "Same incline as last time"
- [x] Tests (10), and a Day page fix: timeline times were an hour late after 2 AM on a Day the
      clocks go back (they counted elapsed seconds)

## Comments

- 2026-11-01 (agent): Left as deliberate: only indoor walks are listed (outdoor walks have VO2
  max on the Sleep page's vitals already); groups need both speed and incline, so a walk with
  only one isn't compared; the note sheet says it's for noticing patterns to raise with a
  doctor, not for deciding medication. Speed is rounded to 0.1 in the shown unit, so a typed
  3.3 mph reads back 3.3. Needs a CloudKit schema deploy (new entity) before upload.
- 2026-11-01 (agent): John changes speed and incline during a walk, and his treadmill shows
  distance but not elevation gain. So the note asks for the treadmill's distance (average speed
  exactly, with the Watch's duration) and roughly the incline he was at most of the time, in
  place of one speed and incline; walks at any settings compare through the ACSM effort, and the
  "same settings" groups are gone. The incline is the rough part: a varied incline's effort is
  approximated by its average. Resting heart rate is one value for all walks (the period's
  median), so walks move alike; without vitals access it is 65. The ACSM equation is meant for
  about 1.9 to 3.7 mph; walks outside that still score, less exactly. Not yet deployed to
  CloudKit, so the field change needed no migration.
- 2026-11-01 (agent): John wants the inhaler noted for lifts too. A Workout logged in Coar
  carries `usedInhaler` itself (new field on Workout, needs the same schema deploy), set from
  "Used inhaler before" in the workout screen's `…` menu (while logging, editing, or on the
  finished workout); the subtitle ends "· Inhaler" and the Day row's detail adds "inhaler". A
  Watch workout that isn't a walk opens its note with only the inhaler switch. Left as
  deliberate: it's a record only, with no lifting comparison (lifting has no steady effort);
  Recent workouts cards don't show it; a mark on an unlinked Watch workout's note isn't carried
  to a Coar Workout when they're later linked (the linked Day row shows the Workout's own).
