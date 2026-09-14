import Foundation

/// A calendar day as it was where the user was when a record was made (CONTEXT.md "Day",
/// ADR 0005). Computed once at write time from an instant and the local calendar, stored as
/// its `rawValue` ("2026-09-13"), and never recomputed from the instant later.
struct Day: Hashable, Comparable, CustomStringConvertible {

    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The Day an instant falls on in `calendar`'s time zone.
    init(_ date: Date, in calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    static func today(in calendar: Calendar = .current) -> Day {
        Day(Date(), in: calendar)
    }

    /// The first instant of this Day in `calendar`'s time zone, for anything that needs a
    /// `Date` (a chart axis, a HealthKit sample). Display only: the Day itself is the fact.
    func start(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: Storage form

    /// ISO-8601 calendar date, e.g. "2026-09-13". Sorts chronologically as a string.
    var rawValue: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Fails for anything that is not a real Gregorian date (e.g. "2026-02-31").
    init?(rawValue: String) {
        let parts = rawValue.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: gregorian) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    var description: String { rawValue }

    static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

// MARK: - Calendar arithmetic

extension Day {

    /// A fixed proleptic Gregorian calendar in UTC: Day arithmetic is about calendar days,
    /// so it must not depend on the device's zone or its daylight-saving transitions.
    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private var gregorianDate: Date {
        Self.gregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// The Day `days` after this one (before, when negative).
    func advanced(by days: Int) -> Day {
        Day(Self.gregorian.date(byAdding: .day, value: days, to: gregorianDate)!, in: Self.gregorian)
    }

    /// ISO weekday: Monday is 1, Sunday is 7. A Period week runs Monday to Sunday
    /// (CONTEXT.md "Period").
    var weekday: Int {
        let sundayFirst = Self.gregorian.component(.weekday, from: gregorianDate)
        return sundayFirst == 1 ? 7 : sundayFirst - 1
    }

    /// The Monday that starts this Day's week.
    var startOfWeek: Day {
        advanced(by: 1 - weekday)
    }

    /// How many Days this Day's month has.
    var daysInMonth: Int {
        Self.gregorian.range(of: .day, in: .month, for: gregorianDate)!.count
    }
}
