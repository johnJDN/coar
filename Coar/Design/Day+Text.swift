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
}
