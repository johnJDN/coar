# 0006. A Night runs 6 PM to 6 PM and belongs to the Day the user woke

**Status:** accepted (2026-09-16)

Sleep read from Apple Health is grouped into Nights by a fixed window: 6 PM the evening
before to 6 PM the Day in question, and the Night is that Day's (CONTEXT.md "Night"). Its
Time Asleep sums the asleep-stage samples clipped to the window, excludes awake and
in-bed, and counts once any hours two sources both recorded. Chosen because it is how the
Health app groups a night, so Coar's number agrees with the one the user can check there;
"the Day a sample ends on" was rejected because it puts an evening doze on the wrong Day,
and "gap-based sessions" because a nap would then be its own night. The boundary lives in
`SleepNight.boundaryHour`; a sample straddling it is split. Steps need no such rule:
HealthKit's per-Day statistics already sum a Day's samples across sources.
