import Foundation

/// An Entry as typed on its detail sheet (ADR 0003: the past is corrected on the past). The
/// name, the instant, the quantity and its unit, and the four snapshotted macros for the
/// whole quantity. Changing the quantity scales the macros so the values per one stay what
/// they were; changing the unit converts by weight where it can (`PortionUnit`); editing a
/// macro field sets it as typed.
struct EntryDraft: Equatable {
    var name: String
    var loggedAt: Date
    /// The Serving name as typed and the one the macros are for; set through `setUnit`.
    private var portionUnit: PortionUnit
    /// A Meal Entry is counted in "meal": its unit can't be changed.
    let isMeal: Bool
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
        name = record.name
        loggedAt = record.loggedAt
        portionUnit = PortionUnit(record.servingName)
        isMeal = !record.components.isEmpty || record.mealID != nil || record.servingName == EntryRecord.mealServingName
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

    /// The name to save, or nil while the field is empty.
    var trimmedName: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The unit as typed.
    var unit: String {
        portionUnit.typed
    }

    /// The Serving name to save, or nil while the field is empty.
    var servingName: String? {
        portionUnit.trimmed.isEmpty ? nil : portionUnit.trimmed
    }

    var isSaveable: Bool {
        trimmedName != nil && servingName != nil && quantity != nil && macros != nil && extras != nil
    }

    /// Sets the unit: to a weight unit when the portion's weight is known ("100 g" → "g"), the
    /// same portion is re-expressed in it; any other change leaves the macros as they were,
    /// which `unitNeedsNumbers` reports.
    mutating func setUnit(_ newValue: String) {
        guard let converted = portionUnit.set(newValue, quantity: quantity) else { return }
        typedQuantity = converted
        macrosQuantity = converted
    }

    /// The unit was changed to one the macros couldn't follow: they are still for the old one.
    var unitNeedsNumbers: Bool {
        portionUnit.needsNumbers
    }

    /// Whether the servings | g switch shows: the weight is known and it didn't start in grams.
    var offersGrams: Bool {
        portionUnit.knowsWeight && PortionUnit.gramsPer[portionUnit.originalUnit.lowercased()] == nil
    }

    /// The unit the switch names opposite grams: the one it started in.
    var servingUnit: String { portionUnit.originalUnit }

    var isInGrams: Bool { portionUnit.trimmed.lowercased() == "g" }

    /// Gives the amount in grams, or back in the unit it started in; the macros stay right.
    mutating func setInGrams(_ on: Bool) {
        setUnit(on ? "g" : portionUnit.originalUnit)
    }


    /// The portion the macros are still for, while `unitNeedsNumbers`: "1 serving".
    var numbersPortion: String {
        FoodText.portion(macrosQuantity, of: portionUnit.numbersUnit)
    }

    /// Typing a macro makes the numbers the user's, for the unit as it now reads.
    mutating func setMacro(_ macro: Macro, _ value: Double?) {
        typedMacros[macro] = value
        if unitNeedsNumbers {
            portionUnit.adopt()
            macrosQuantity = quantity ?? macrosQuantity
        }
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
