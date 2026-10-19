# 01: Evening reminder to log the day

**What to build:** John (2026-10-18): "notifications around 9PM each night to remind me to log
everything for the day".

**Status:** done

- [x] Settings → Reminders: Evening reminder (off until turned on; iOS asks the first time) and
      its time, 9:00 PM by default (`Preferences.reminderEnabled`, `reminderMinute`, per device)
- [x] `EveningReminder`: one notification a Day for the next 7 Days ("Log today · Meals, mood
      and energy, and anything else from today."), re-planned when Coar opens or goes away and
      after mood or energy is set (`ReminderPlan`)
- [x] Skipped on a Day already logged: food logged and both mood and energy set
- [x] Tapping it opens Home, then today's Day page (also from a cold launch)
- [x] Shown even while Coar is open; a "notifications are off" note when iOS blocks them
- [x] Tests (4)

## Comments

- 2026-10-18 (agent): Checked in the simulator: the toggle shows Time 9:00 PM; declining the
  iOS prompt shows the note. Left as deliberate:
  - **"Logged" is food plus mood and energy**: the two things only you can add. Weight,
    workouts and habits don't count toward skipping.
  - **Planned a week ahead**, so it keeps coming without opening Coar; a week away and it stops
    until the next open.
  - **The text is the same every night**: it's written when planned, before the day happens,
    so it can't list what's missing. The Day page shows that.
  - Not checked on a device: the tap opening the Day page (the simulator was refused permission).
