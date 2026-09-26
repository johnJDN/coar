import Foundation

/// The "+" sheet's order for Food Items and Meals: most recently used first. A thing's last
/// use is the later of its own last edit and the moment an Entry from it was last written
/// (the Entry's `modifiedAt`, not `loggedAt`: the time of day eaten says nothing about when
/// it was used, and a 11:50 PM Entry logged this morning would otherwise pin a food to the
/// top all day). Creating, editing, or logging it (onto any Day) moves it to the top. Ties
/// fall back to name.
enum RecentUse {

    struct Candidate<Value> {
        let value: Value
        let name: String
        let modifiedAt: Date?
        let lastLoggedAt: Date?

        var lastUsed: Date? {
            switch (modifiedAt, lastLoggedAt) {
            case let (edited?, logged?): return max(edited, logged)
            case let (edited, logged): return edited ?? logged
            }
        }
    }

    static func ordered<Value>(_ candidates: [Candidate<Value>]) -> [Value] {
        candidates.sorted { a, b in
            switch (a.lastUsed, b.lastUsed) {
            case let (x?, y?) where x != y: return x > y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }.map(\.value)
    }
}
