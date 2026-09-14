import Foundation

/// Streak (CONTEXT.md): the number of consecutive Periods, ending now, in which a Habit met
/// its target. The current Period counts once met and only breaks the streak once it has
/// ended unmet, so an unmet today is still pending, not a miss. Computed, never stored. A
/// pure rule function: values in, value out.
enum Streak {

    /// The streak in Days for a daily Habit. `met` holds every Day whose Check-in met the
    /// target; Days after `today` are ignored.
    static func days(met: Set<Day>, today: Day) -> Int {
        periods(met: met, current: today, length: 1)
    }

    /// The streak in Monday-to-Sunday weeks for a weekly Habit. `met` holds the Monday of
    /// every week whose total met the target; weeks after the current one are ignored.
    static func weeks(met: Set<Day>, today: Day) -> Int {
        periods(met: met, current: today.startOfWeek, length: 7)
    }

    /// Counts back from the current Period (if met) or the one before it, `length` Days at a
    /// time, while each is met.
    private static func periods(met: Set<Day>, current: Day, length: Int) -> Int {
        var period = met.contains(current) ? current : current.advanced(by: -length)
        var count = 0
        while met.contains(period) {
            count += 1
            period = period.advanced(by: -length)
        }
        return count
    }
}
