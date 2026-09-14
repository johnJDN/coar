import Foundation

/// Streak (CONTEXT.md): the number of consecutive Periods, ending now, in which a Habit met
/// its target. The current Period counts once met and only breaks the streak once it has
/// ended unmet, so an unmet today is still pending, not a miss. Computed, never stored. A
/// pure rule function: values in, value out.
enum Streak {

    /// The streak in Days for a daily Habit. `met` holds every Day whose Check-in met the
    /// target; Days after `today` are ignored.
    static func days(met: Set<Day>, today: Day) -> Int {
        var day = met.contains(today) ? today : today.advanced(by: -1)
        var count = 0
        while met.contains(day) {
            count += 1
            day = day.advanced(by: -1)
        }
        return count
    }
}
