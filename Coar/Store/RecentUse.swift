import Foundation

/// The "+" sheet's order for Food Items and Meals: most recently used first. A thing's last
/// use is the later of its latest Entry's time and its own `modifiedAt`, which a save also
/// stamps when an Entry is logged from it (the relationship changes). So logging, even
/// onto a past Day, creating, or editing moves it to the top. Ties fall back to name.
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
