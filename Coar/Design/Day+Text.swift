import Foundation

extension Day {
    /// The Day as a screen names it: "Today", else "Monday, September 7".
    func title(relativeTo today: Day = .today()) -> String {
        self == today ? "Today" : start().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}
