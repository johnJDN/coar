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
        /// No Check-in met the target: `surfaceSunken`. An empty Day is the miss.
        case empty
        /// Met: the accent, with bloom.
        case done
    }

    struct Cell: Hashable {
        let day: Day
        let level: Level
    }

    /// Column-major: the first 7 cells are the leftmost week, Monday first. `met` holds
    /// every Day whose Check-in met the target.
    static func cells(endingOn today: Day, columns: Int, met: Set<Day>) -> [Cell] {
        let firstMonday = today.startOfWeek.advanced(by: -7 * (columns - 1))
        return (0..<(columns * rows)).map { offset in
            let day = firstMonday.advanced(by: offset)
            let level: Level = day > today ? .future : met.contains(day) ? .done : .empty
            return Cell(day: day, level: level)
        }
    }
}
