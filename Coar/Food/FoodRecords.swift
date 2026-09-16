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

/// An Entry as read through the façade (CONTEXT.md "Entry", ADR 0003): its own copy of the
/// name, Serving name, quantity, and the four macros for the whole quantity, taken when it
/// was logged; the instant it was eaten and the local Day it was logged into (ADR 0005); and
/// the Food Item it came from, for re-logging only.
struct EntryRecord: Hashable, Identifiable {
    let id: UUID
    let loggedAt: Date
    let day: Day
    let name: String
    let servingName: String
    let quantity: Double
    let macros: Macros
    let foodItemID: FoodItemRecord.ID?
    let modifiedAt: Date
}
