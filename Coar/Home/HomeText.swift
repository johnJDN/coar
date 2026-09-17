import Foundation

/// The words at the top of Home (spec story 2): today's date as the title and a greeting by
/// name as the subtitle. Coar is one person's app with no accounts and no name field (the
/// spec keeps both out of v1), so the name lives here.
enum HomeText {

    static let name = "John"

    /// "Today, September 16".
    static func title(for day: Day) -> String {
        "Today, " + day.start().formatted(.dateTime.month(.wide).day())
    }

    /// "Good morning, John" until noon, "Good afternoon, John" until five, then "Good
    /// evening, John".
    static func greeting(at date: Date, in calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return "Good morning, \(name)"
        case 12..<17: return "Good afternoon, \(name)"
        default: return "Good evening, \(name)"
        }
    }
}
