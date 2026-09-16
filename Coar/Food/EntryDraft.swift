import Foundation

/// An Entry as typed on its detail sheet (ADR 0003: the past is corrected on the past). The
/// instant, the quantity, and the four snapshotted macros for the whole quantity. Changing
/// the quantity scales the macros so the values per one stay what they were; editing a macro
/// field sets it as typed.
struct EntryDraft: Equatable {
    var loggedAt: Date
    /// As typed; nil while empty.
    private(set) var typedQuantity: Double?
    /// As typed; an empty field counts as 0.
    var typedMacros: [Macro: Double?]
    /// The quantity the macros are for: the last valid one, kept while the field is empty.
    private var macrosQuantity: Double

    init(_ record: EntryRecord) {
        loggedAt = record.loggedAt
        typedQuantity = record.quantity
        typedMacros = Dictionary(uniqueKeysWithValues: Macro.allCases.map { ($0, record.macros[$0]) })
        macrosQuantity = record.quantity
    }

    /// The valid quantity, or nil while the field is empty or not positive.
    var quantity: Double? {
        FoodText.quantity(typed: typedQuantity)
    }

    /// The four macros as typed, or nil while any is negative.
    var macros: Macros? {
        Macros(typed: typedMacros)
    }

    var isSaveable: Bool {
        quantity != nil && macros != nil
    }

    /// Sets the quantity, scaling the macros by the change so what one of it holds stays the
    /// same. Clearing the field leaves the macros where they are until a quantity returns.
    mutating func setQuantity(_ newValue: Double?) {
        typedQuantity = newValue
        guard let current = quantity, macrosQuantity > 0, let macros else { return }
        let scaled = macros.scaled(by: current / macrosQuantity)
        typedMacros = Dictionary(uniqueKeysWithValues: Macro.allCases.map { ($0, scaled[$0]) })
        macrosQuantity = current
    }
}
