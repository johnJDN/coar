import Foundation

extension Day {
    /// The Day as a screen names it: "Today", else "Monday, September 7".
    func title(relativeTo today: Day = .today()) -> String {
        self == today ? "Today" : start().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    /// The Day as a caption names it: "Today", else "Sep 7".
    func shortTitle(relativeTo today: Day = .today()) -> String {
        self == today ? "Today" : shortText
    }

    /// "Sep 7".
    var shortText: String {
        start().formatted(.dateTime.month(.abbreviated).day())
    }

    /// How long ago the Day was, for a square that answers "am I due": "Today", "Yesterday",
    /// "3 days ago", "2 weeks ago"; the plain Day once it is eight weeks back or in the
    /// future.
    func relativeTitle(to today: Day) -> String {
        let daysAgo = distance(to: today)
        switch daysAgo {
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2..<14: return "\(daysAgo) days ago"
        case 14..<56: return "\(daysAgo / 7) weeks ago"
        default: return shortText
        }
    }
}
