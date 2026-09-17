import Foundation

/// How a sleep or steps value reads on screen.
enum HealthText {

    /// Time asleep as hours and minutes to the nearest minute: "7h 32m", "8h", "45m".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(rest)m"
        }
    }

    /// A step count with grouping: "8,432".
    static func steps(_ count: Int) -> String {
        count.formatted(.number.grouping(.automatic))
    }
}
