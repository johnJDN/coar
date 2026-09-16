import Foundation

/// A Meal as typed on its editor: a name and its lines in order (CONTEXT.md "Meal").
struct MealDraft: Equatable {
    var name = ""
    var components: [MealComponentDraft] = []

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Saveable: a name and at least one line, each with a Serving picked.
    var isComplete: Bool {
        !trimmedName.isEmpty && !components.isEmpty && components.allSatisfy { $0.servingID != nil }
    }

    /// Replaces the line with the same id, or appends a new one.
    mutating func upsert(_ component: MealComponentDraft) {
        if let index = components.firstIndex(where: { $0.id == component.id }) {
            components[index] = component
        } else {
            components.append(component)
        }
    }

    mutating func remove(_ id: MealComponentDraft.ID) {
        components.removeAll { $0.id == id }
    }

    /// Puts the lines in the given order; ids not listed keep their relative order after.
    mutating func reorder(_ ids: [MealComponentDraft.ID]) {
        let position = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        components.sort { (position[$0.id] ?? ids.count) < (position[$1.id] ?? ids.count) }
    }
}

extension MealComponentDraft {
    init(_ record: MealComponentRecord) {
        self.init(id: record.id, foodItemID: record.foodItemID, servingID: record.servingID, quantity: record.quantity)
    }
}
