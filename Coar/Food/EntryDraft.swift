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
    /// The Extras the Entry holds, as typed; an empty field is not recorded.
    var typedExtras: [Extra: Double?]
    /// The Extras the Entry had when it opened, so a cleared one still shows its row.
    let heldExtras: Set<Extra>
    /// The quantity the macros are for: the last valid one, kept while the field is empty.
    private var macrosQuantity: Double

    init(_ record: EntryRecord) {
        loggedAt = record.loggedAt
        typedQuantity = record.quantity
        typedMacros = Dictionary(uniqueKeysWithValues: Macro.allCases.map { ($0, record.macros[$0]) })
        typedExtras = Dictionary(uniqueKeysWithValues: Extra.allCases.map { ($0, record.extras[$0]) })
        heldExtras = Set(Extra.allCases.filter { record.extras[$0] != nil })
        macrosQuantity = record.quantity
    }

    /// The Extras the page shows: those the Entry holds, and any still typed.
    var shownExtras: [Extra] {
        Extra.allCases.filter { heldExtras.contains($0) || (typedExtras[$0] ?? nil) != nil }
    }

    /// The Extras as typed, or nil while any is negative.
    var extras: Extras? {
        Extras(typed: typedExtras)
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
        quantity != nil && macros != nil && extras != nil
    }

    /// Sets the quantity, scaling the macros by the change so what one of it holds stays the
    /// same. Clearing the field leaves the macros where they are until a quantity returns.
    mutating func setQuantity(_ newValue: Double?) {
        typedQuantity = newValue
        guard let current = quantity, macrosQuantity > 0, let macros else { return }
        let scaled = macros.scaled(by: current / macrosQuantity)
        typedMacros = Dictionary(uniqueKeysWithValues: Macro.allCases.map { ($0, scaled[$0]) })
        if let extras {
            let scaledExtras = extras.scaled(by: current / macrosQuantity)
            typedExtras = Dictionary(uniqueKeysWithValues: Extra.allCases.map { ($0, scaledExtras[$0]) })
        }
        macrosQuantity = current
    }
}
