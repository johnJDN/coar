# Watch link: effort on a workout

John's ask (2026-10-14): link the calories a Watch workout burned to a workout in Coar,
optionally and not for all of them, "so that I can go back and use it as an indicator for how
hard I worked out". He chose average heart rate as an extra.

## Decisions

- **Optional per workout.** Nothing links itself. A finished Workout has an Apple Watch card:
  linked, it shows the Effort; unlinked, it invites a link, and offers a one-tap Link when
  exactly one Health Workout overlaps the Workout in time.
- **Effort = active energy and average heart rate** of the Health Workout. Not total calories
  (resting energy makes every workout look alike), and never added to food or Targets.
- **Only the link is stored.** The plan was to copy the numbers into the Workout so they
  outlive Health. ADR 0002 forbids it: Coar's store syncs through CloudKit, and Apple's
  guidelines forbid storing HealthKit data in iCloud. So a Workout keeps `healthWorkoutID`
  (a reference, no reading) and the numbers are read live from Apple Health each time. The
  cost: if Health no longer holds the workout, the card says so and the effort is gone.
- **One Health Workout, one Workout.** Linking it again moves the link.
- **Its own permission.** Workouts, active energy, and heart rate are requested when the user
  first opens the link sheet, separately from sleep and steps, so Home's Health tiles do not
  fall back to "Connect" on existing installs.
- **Nothing prompts by itself.** Opening a workout reads Health quietly; before the first link
  that returns nothing and the card just invites.

## Not now

- Counting Watch-only workouts (a run, pickleball) as workout days, or listing them in Train.
  Same permission, a second ticket.
- A prompt on Finish (a workout takes minutes to reach the iPhone from the Watch).
- Heart-rate zones, calories on a chart, comparing sessions side by side.

## Schema

One optional UUID, `Workout.healthWorkoutID`: a CloudKit schema deploy before the TestFlight
upload (`project-testflight-cloudkit-production`).
