# 10: Train: rest timer and Superset logging

**What to build:** Completing a set auto-starts a rest timer in the bottom accessory bar, using the Exercise's rest default or 120 s, dismissible; grouped Superset cards stay in place with a link icon and no auto-advance, and the timer starts only after a set of the group's last Exercise.

**Blocked by:** 09

**Status:** ready-for-agent

- [ ] Completing a `SetRow` starts the timer in the `UITabAccessory` (countdown, dismiss); duration = the Workout row's rest default ?? 120 s
- [ ] Timer survives navigating between tabs and re-docks inline when the tab bar minimises
- [ ] Superset cards render the link icon between them; no scrolling or focus change on set completion
- [ ] For a Superset group, completing a set on any Exercise but the group's last does not start the timer; completing one on the last does
- [ ] Tests (pure): trigger rule over (group membership, position, completed exercise) for straight sets, 2-exercise groups, 3-exercise groups
