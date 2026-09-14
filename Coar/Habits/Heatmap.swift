import Foundation

/// The habit heatmap's cells (DESIGN.md §8 "Streaks / consistency over weeks"): 7 rows with
/// Monday on top, one column per Monday-to-Sunday week, the last column being the week that
/// holds today. A pure rule function: Days and Check-ins in, cell levels out.
enum Heatmap {

    static let rows = 7
    /// About six months of weeks.
    static let columns = 26

    enum Level: Hashable {
        /// After today: not drawn.
        case future
        /// No Check-in, or no target in force to judge it against: `surfaceSunken`. An
        /// empty Day is the miss.
        case empty
        /// Quantitative only: up to a quarter of the target in force.
        case quarter
        /// Quantitative only: up to half.
        case half
        /// Quantitative only: more than half but short of the target.
        case mostly
        /// Met: the accent, with bloom.
        case done
    }

    /// The bucket of a quantitative Day's amount ÷ the target in force on it (DESIGN.md §8
    /// "accent intensity by count"). Only reaching the target is `done`, so a nearly-met Day
    /// never reads as met; with no target in force there is nothing to judge against.
    static func level(amount: Double, target: Double?) -> Level {
        guard let target, target > 0, amount > 0 else { return .empty }
        switch amount / target {
        case ...0.25: return .quarter
        case ...0.5: return .half
        case ..<1: return .mostly
        default: return .done
        }
    }

    struct Cell: Hashable {
        let day: Day
        let level: Level
    }

    /// Column-major: the first 7 cells are the leftmost week, Monday first. `levels` holds
    /// the level of every Day with a Check-in; any other Day up to today is empty.
    static func cells(endingOn today: Day, columns: Int, levels: [Day: Level]) -> [Cell] {
        let firstMonday = weeks(endingOn: today, columns: columns)[0]
        return (0..<(columns * rows)).map { offset in
            let day = firstMonday.advanced(by: offset)
            let level: Level = day > today ? .future : levels[day] ?? .empty
            return Cell(day: day, level: level)
        }
    }

    /// The Monday of each column, leftmost first; the last is the current week's.
    static func weeks(endingOn today: Day, columns: Int) -> [Day] {
        let currentMonday = today.startOfWeek
        return (0..<columns).map { currentMonday.advanced(by: -7 * (columns - 1 - $0)) }
    }
}
