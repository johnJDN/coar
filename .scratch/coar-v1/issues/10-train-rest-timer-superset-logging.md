# 10: Train: rest timer and Superset logging

**What to build:** Completing a set auto-starts a rest timer in the bottom accessory bar, using the Exercise's rest default or 120 s, dismissible; grouped Superset cards stay in place with a link icon and no auto-advance, and the timer starts only after a set of the group's last Exercise.

**Blocked by:** 09

**Status:** done

- [x] Completing a `SetRow` starts the timer in the `UITabAccessory` (countdown, dismiss); duration = the Workout row's rest default ?? 120 s
- [x] Timer survives navigating between tabs and re-docks inline when the tab bar minimises
- [x] Superset cards render the link icon between them; no scrolling or focus change on set completion
- [x] For a Superset group, completing a set on any Exercise but the group's last does not start the timer; completing one on the last does
- [x] Tests (pure): trigger rule over (group membership, position, completed exercise) for straight sets, 2-exercise groups, 3-exercise groups

## Comments

- 2026-09-16 (agent): Implemented. Rule (`RestTimerRule.swift`, Seam 2, pure):
  `starts(afterSetOn:groups:)` (a row on its own always starts the timer; a grouped row
  only when no later row shares its group) and `seconds(restDefault:)` (the default, or
  120 s); `WorkoutRecord.restSeconds(afterSetOn:)` wraps both for a row id. Timer
  (`RestTimer.swift`): one `@MainActor` object in `AppDependencies.restTimer` holding the
  moment it ends at, `start(seconds:now:)`, `remainingSeconds(at:)` (rounded up, so 0:00
  shows only once it is over), `dismiss()`, and an expiry timer; posts `RestTimer.didChange`
  on start / dismiss / expiry and `RestTimer.didExpire` on expiry alone. Logger: completing a
  `SetRow` asks the rule for the row it belongs to and starts the timer; un-completing never
  does. The cards have no spacing of their own now: the gap after each card is an item
  (`CardGapCell`, 16 pt), or the Superset link (`SupersetLinkCell`, a lavender `link` on the
  ground, 24 pt) when the next row shares the group; nothing scrolls or moves focus on
  completion. Each `ExerciseCard` gained the DESIGN §7 timer button (starts the timer by
  hand with that row's default). Shell: the same `ActiveWorkoutBar` shows the countdown
  (`timer` icon, "1:42" in green, "Rest · Push", ✕) whenever the timer runs, on every tab
  and inside the logger, and the Workout line otherwise; it ticks each second while resting,
  each minute otherwise, on the common run-loop mode so scrolling never freezes it; the
  detail line hides when the tab bar minimises and the accessory goes inline
  (`UITraitTabAccessoryEnvironment`); a success haptic plays when the countdown runs out;
  a Workout that finishes or is discarded takes its timer with it. `TrainText.countdown`
  ("1:42") and a `cardTitleMonospaced` font variant (`FontToken.uiFont(monospacedDigits:)`,
  applied before Dynamic Type scaling, both `UIFont` and `Font` forms) were added. Tests:
  `RestTimerRuleTests` (8: straight sets, single row, 2- and 3-Exercise groups, a mixed
  Workout, out-of-range index, duration fallback, the record wrapper) and `RestTimerTests`
  (5: countdown, dismiss, restart, expiry, change posts). Verified visually in the simulator
  via a throwaway screenshot test (since removed) in light and dark: the logger with a
  Superset link and a completed A2 set, the bar with the countdown on the logger and on
  Home, the bar without a timer on Home. Full suite passes via
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`.
  Left as deliberate, please confirm: (1) One accessory, not two: while the timer runs the
  bar shows the countdown everywhere, logger included, and a tap still returns to the
  logger; ✕ dismisses. (2) The card's timer button starts the timer by hand with the row's
  default (or 120 s) regardless of the Superset rule, and always restarts a running one.
  (3) Completing any set restarts a running timer with the new row's duration; completing
  the same set again (after un-completing) starts it again. (4) The rule is by row, not by
  set count: with A1 at 3 sets and A2 at 2, A1's third set starts no timer. (5) The
  countdown ends itself at 0:00 with a success haptic and the bar reverts; no local
  notification when the app is in the background (needs a permission prompt; not in the
  ticket). The end is a moment, so backgrounding keeps the count true; it is not persisted
  across a relaunch. (6) Grouped cards sit 24 pt apart with the link between them,
  ungrouped 16 pt as before. (7) The countdown is card-title size with monospaced digits,
  not the metric size: the accessory's fixed height fits two lines only at that size.
  (8) Inline (tab bar minimised) shows icon + countdown + ✕, or icon + title + chevron.
  (9) VoiceOver: the bar reads "Rest, n seconds left, Push" with a Dismiss custom action;
  the link reads "Superset, continues below".
- 2026-09-16 (agent, after /code-review): Fixed: the expiry timer now runs on the common
  run-loop mode like the bar's ticker, so a scroll across 0:00 no longer holds back the
  haptic and the revert; an expiry found long after its moment (the app suspended past it)
  ends the timer without the haptic (`RestTimer.expiryGrace`, tested); `refreshAccessory`
  dismisses a timer that outlived its Workout and falls through instead of returning
  through the re-entrant notification; the bar's mode swap (Workout line ↔ countdown)
  cross-dissolves per DESIGN §9 and only the clock text is touched per tick; tapping ✓ no
  longer closes the keyboard, so completion changes neither scroll nor focus (ticket box 3;
  ticket 09's `endEditing` went). Duplication pulled out: `RestTimer.remainingSeconds(until:at:)`
  serves the bar and the timer; `totalSeconds` (never read) went; the card's timer button
  hands its seconds through `onStartRest` so the logger no longer re-derives them, and the
  `byHand` flag argument went with it. Left as is: `RestTimerRule.seconds` treats a rest
  default of 0 as none (→ 120 s), one more call to confirm, (10): the Exercise form rejects
  0, and a 0 s timer would end as it began; the Superset link is `accentLavender` like the
  Plan editor's link button (DESIGN §3 lists lavender for AI / coach; the two never share a
  screen); the gap and link cells share the section's height estimate (self-sizing settles
  them on first display). 167 tests pass.

## Changed during human testing (2026-09-26)

The set check shows a grey tick. Details under this ticket's Results in `.scratch/coar-v1/human-testing.md`; where they differ from the text above, they win.
