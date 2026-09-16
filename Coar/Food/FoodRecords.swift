import Foundation

/// A Food Item as read through the façade (CONTEXT.md "Food Item"): a named food with one
/// or more Servings in the user's order, one of them the default.
struct FoodItemRecord: Hashable, Identifiable {
    let id: UUID
    let name: String
    let isArchived: Bool
    let servings: [ServingRecord]
    let modifiedAt: Date

    /// The Serving logged when the user does not pick one: the one marked default, else the
    /// first (a Food Item always has at least one).
    var defaultServing: ServingRecord? {
        servings.first { $0.isDefault } ?? servings.first
    }
}

/// A Serving as read through the façade (CONTEXT.md "Serving"): a named portion with the
/// macros for one of it and, when known, its weight in grams.
struct ServingRecord: Hashable, Identifiable {
    let id: UUID
    let name: String
    let macros: Macros
    let grams: Double?
    let isDefault: Bool
}

/// A Serving as typed on the Food Item editor. New drafts get a fresh `id`; drafts carrying
/// an existing Serving's `id` update it in place, so reordering and renaming keep identity.
struct ServingDraft: Hashable, Identifiable {
    var id = UUID()
    var name: String
    var macros: Macros
    var grams: Double?
    var isDefault = false

    init(id: UUID = UUID(), name: String, macros: Macros, grams: Double? = nil, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.macros = macros
        self.grams = grams
        self.isDefault = isDefault
    }

    init(_ record: ServingRecord) {
        self.init(id: record.id, name: record.name, macros: record.macros, grams: record.grams, isDefault: record.isDefault)
    }
}

/// A Meal as read through the façade (CONTEXT.md "Meal"): a named group of Food Items in
/// fixed quantities, in the user's order. Its macros are read live from the Servings it
/// points at, so editing a Food Item changes what logging the Meal will snapshot next.
struct MealRecord: Hashable, Identifiable {
    let id: UUID
    let name: String
    let isArchived: Bool
    let components: [MealComponentRecord]
    let modifiedAt: Date

    /// The four macros for one of the Meal: the components summed.
    var macros: Macros {
        Macros.sum(components.map(\.macros))
    }
}

/// One line of a Meal: a Food Item, one of its Servings, and how many of it.
struct MealComponentRecord: Hashable, Identifiable {
    let id: UUID
    let foodItemID: FoodItemRecord.ID
    /// Nil once the Serving has been removed from its Food Item; the line then carries no
    /// macros until the user picks another.
    let servingID: ServingRecord.ID?
    /// The Food Item's name as it stands now.
    let name: String
    /// The Serving's name as it stands now; empty when the Serving is gone.
    let servingName: String
    let quantity: Double
    /// The Serving's macros for one, as the Food Item stands now; zero when the Serving is gone.
    let servingMacros: Macros

    /// The macros for `quantity` of the Serving.
    var macros: Macros {
        servingMacros.scaled(by: quantity)
    }
}

/// A Meal line as typed on the Meal editor. New drafts get a fresh `id`; drafts carrying an
/// existing line's `id` update it in place, so reordering keeps identity.
struct MealComponentDraft: Hashable, Identifiable {
    var id: UUID
    var foodItemID: FoodItemRecord.ID
    /// Nil while the line's Serving has been removed from its Food Item and none is picked
    /// yet; such a line cannot be saved.
    var servingID: ServingRecord.ID?
    var quantity: Double

    init(id: UUID = UUID(), foodItemID: FoodItemRecord.ID, servingID: ServingRecord.ID?, quantity: Double) {
        self.id = id
        self.foodItemID = foodItemID
        self.servingID = servingID
        self.quantity = quantity
    }
}

/// An Entry as read through the façade (CONTEXT.md "Entry", ADR 0003): its own copy of the
/// name, Serving name, quantity, and the four macros for the whole quantity, taken when it
/// was logged; the instant it was eaten and the local Day it was logged into (ADR 0005); and
/// the Food Item or Meal it came from, for re-logging only. A Meal Entry also keeps its
/// component breakdown.
struct EntryRecord: Hashable, Identifiable {
    let id: UUID
    let loggedAt: Date
    let day: Day
    let name: String
    let servingName: String
    let quantity: Double
    let macros: Macros
    let foodItemID: FoodItemRecord.ID?
    let mealID: MealRecord.ID?
    /// A Meal Entry's lines as they were when logged, for one of the Meal; empty for a Food
    /// Item Entry.
    let components: [EntryComponentRecord]
    let modifiedAt: Date
}

/// One line of a Meal Entry's breakdown: the Food Item's name, Serving name, quantity, and
/// macros for one of the Meal, copied when the Entry was logged (ADR 0003).
struct EntryComponentRecord: Hashable {
    let name: String
    let servingName: String
    let quantity: Double
    let macros: Macros
}
