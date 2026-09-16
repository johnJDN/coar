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
        components.reorder(ids)
    }

    /// The Meal's macros as drafted, read from the Food Items the lines point at; a line
    /// whose Serving is gone adds nothing.
    func macros(in foodItems: [FoodItemRecord.ID: FoodItemRecord]) -> Macros {
        Macros.sum(components.compactMap { line in
            foodItems[line.foodItemID]?.serving(line.servingID)?.macros.scaled(by: line.quantity)
        })
    }
}

extension MealComponentDraft {
    init(_ record: MealComponentRecord) {
        self.init(id: record.id, foodItemID: record.foodItemID, servingID: record.servingID, quantity: record.quantity)
    }
}
