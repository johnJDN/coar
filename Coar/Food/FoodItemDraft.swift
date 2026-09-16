import Foundation

/// A Food Item as typed on its editor: a name and its Servings in order. Keeps the "exactly
/// one default" rule (CONTEXT.md "Serving") as Servings come and go.
struct FoodItemDraft: Equatable {
    var name = ""
    var servings: [ServingDraft] = []

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Saveable: a name and at least one Serving.
    var isComplete: Bool {
        !trimmedName.isEmpty && !servings.isEmpty
    }

    /// Replaces the Serving with the same id, or appends a new one. A Serving saved as the
    /// default takes the flag from the others; the first Serving is the default when none
    /// holds it.
    mutating func upsert(_ serving: ServingDraft) {
        if let index = servings.firstIndex(where: { $0.id == serving.id }) {
            servings[index] = serving
        } else {
            servings.append(serving)
        }
        if serving.isDefault {
            for index in servings.indices where servings[index].id != serving.id {
                servings[index].isDefault = false
            }
        }
        settleDefault()
    }

    mutating func remove(_ id: ServingDraft.ID) {
        servings.removeAll { $0.id == id }
        settleDefault()
    }

    /// Puts the Servings in the given order; ids not listed keep their relative order after.
    mutating func reorder(_ ids: [ServingDraft.ID]) {
        servings.reorder(ids)
    }

    private mutating func settleDefault() {
        guard !servings.isEmpty, !servings.contains(where: \.isDefault) else { return }
        servings[0].isDefault = true
    }
}

extension Array where Element: Identifiable {
    /// Puts the elements in the given id order; ids not listed keep their relative order after.
    mutating func reorder(_ ids: [Element.ID]) {
        let position = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        sort { (position[$0.id] ?? ids.count) < (position[$1.id] ?? ids.count) }
    }
}
