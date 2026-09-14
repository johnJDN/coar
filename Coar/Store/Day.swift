import Foundation

/// A calendar day as it was where the user was when a record was made (CONTEXT.md "Day",
/// ADR 0005). Computed once at write time from an instant and the local calendar, stored as
/// its `rawValue` ("2026-09-13"), and never recomputed from the instant later.
struct Day: Hashable, Comparable, Codable, CustomStringConvertible {

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

    // MARK: Storage form

    /// ISO-8601 calendar date, e.g. "2026-09-13". Sorts chronologically as a string.
    var rawValue: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The first instant of this Day in `calendar`; for placing a Day on a time axis.
    func startDate(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    var description: String { rawValue }

    static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
