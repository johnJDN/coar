import Foundation

/// A Describe line as edited on its page (`.scratch/ai-food-logging/issues/05`): the name,
/// the portion, the four macros, and Save as food. Like `EntryDraft`, changing the quantity
/// scales the macros so one of it holds the same; typing a macro makes the numbers the user's
/// own ("Typed"). A line that had no Estimate (it failed, or is waiting for a connection)
/// gets one once a macro is typed.
struct DescribeLineEdit: Equatable {

    var name: String
    var unit: String
    /// As typed; nil while empty.
    private(set) var typedQuantity: Double?
    /// As typed; an empty field counts as 0.
    private(set) var typedMacros: [Macro: Double?]
    var saveAsFood: Bool
    /// What the line held when the page opened; nil for a line with no Estimate yet.
    let original: Estimate?
    /// A macro was typed on this page.
    private(set) var macrosTyped = false
    /// The quantity the macros are for: the last valid one, kept while the field is empty.
    private var macrosQuantity: Double

    init(_ line: DescribeLine) {
        let estimate = line.estimate
        original = estimate
        name = estimate?.name ?? line.trimmedText.prefix(1).uppercased() + line.trimmedText.dropFirst()
        unit = estimate?.unit ?? "serving"
        typedQuantity = estimate?.quantity ?? 1
        typedMacros = Dictionary(uniqueKeysWithValues: Macro.allCases.map { macro in (macro, estimate?.macros[macro]) })
        macrosQuantity = estimate?.quantity ?? 1
        saveAsFood = line.saveAsFood
    }

    var quantity: Double? {
        FoodText.quantity(typed: typedQuantity)
    }

    /// Sets the quantity, scaling the macros by the change. Clearing the field leaves the
    /// macros where they are until a quantity returns.
    mutating func setQuantity(_ newValue: Double?) {
        typedQuantity = newValue
        guard let current = quantity, macrosQuantity > 0, let macros = Macros(typed: typedMacros) else { return }
        let scaled = macros.scaled(by: current / macrosQuantity)
        typedMacros = Dictionary(uniqueKeysWithValues: Macro.allCases.map { ($0, scaled[$0]) })
        macrosQuantity = current
    }

    mutating func setMacro(_ macro: Macro, _ value: Double?) {
        typedMacros[macro] = value
        macrosTyped = true
    }

    func typed(_ macro: Macro) -> Double? {
        typedMacros[macro] ?? nil
    }

    /// Saving to Foods is offered only for lines that aren't already one of the user's.
    var offersSaveAsFood: Bool {
        original?.match == nil
    }

    /// What the line holds now, or nil while it can't be added: no valid quantity, a negative
    /// macro, or nothing typed yet on a line that had no Estimate. Editing a matched line's
    /// name, unit, or macros makes it the user's own line, no longer the saved food's;
    /// changing only its quantity keeps the match.
    var estimate: Estimate? {
        guard let quantity, let macros = Macros(typed: typedMacros) else { return nil }
        if original == nil, !macrosTyped || macros == .zero { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let renamed = trimmedName != (original?.name ?? trimmedName) || trimmedUnit != (original?.unit ?? trimmedUnit)
        let ownNumbers = macrosTyped || original == nil
        let keepsMatch = !ownNumbers && !renamed
        var grams: Double?
        if let original, let originalGrams = original.grams, original.quantity > 0, !renamed {
            grams = originalGrams * quantity / original.quantity
        }
        return Estimate(
            name: trimmedName.isEmpty ? (original?.name ?? "Food") : trimmedName,
            quantity: quantity,
            unit: trimmedUnit.isEmpty ? "serving" : trimmedUnit,
            grams: grams,
            macros: macros,
            source: ownNumbers || (renamed && original?.match != nil) ? .typed : (original?.source ?? .typed),
            assumption: ownNumbers ? "" : (original?.assumption ?? ""),
            match: keepsMatch ? original?.match : nil
        )
    }
}

extension Estimate {

    /// The Serving that Save as food creates, and how many of it this line is. A line counted
    /// in grams or millilitres ("150 × g") saves a "100 g" Serving, so the food logs sensibly
    /// next time; anything else saves one of its unit.
    var servingToSave: (serving: ServingDraft, quantity: Double) {
        let per100 = ["g", "gram", "grams", "ml"]
        let unitWord = unit.lowercased().trimmingCharacters(in: .whitespaces)
        if per100.contains(unitWord), quantity > 0 {
            let symbol = unitWord == "ml" ? "ml" : "g"
            let servings = quantity / 100
            return (ServingDraft(name: "100 \(symbol)", macros: macros.scaled(by: 1 / servings), grams: symbol == "g" ? 100 : nil, isDefault: true), servings)
        }
        let perOne = quantity > 0 ? 1 / quantity : 1
        return (ServingDraft(name: unit, macros: macros.scaled(by: perOne), grams: grams.map { $0 * perOne }, isDefault: true), quantity)
    }
}
