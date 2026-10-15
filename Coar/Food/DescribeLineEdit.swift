import Foundation

/// A Describe line as edited on its page (`.scratch/ai-food-logging/issues/05`): the name,
/// the portion, the four macros, and Save as food. Like `EntryDraft`, changing the quantity
/// scales the macros so one of it holds the same; typing a macro makes the numbers the user's
/// own ("Typed"). A line that had no Estimate (it failed, or is waiting for a connection)
/// gets one once a macro is typed.
struct DescribeLineEdit: Equatable {

    var name: String
    /// As typed; set through `setUnit`, which keeps the numbers right where it can.
    private(set) var unit: String
    /// The unit the macros are for: the line's, or the weight unit a known portion was
    /// re-expressed in. When `unit` differs, the numbers are for something else.
    private var numbersUnit: String
    /// Grams in one `numbersUnit`, when known: from the Estimate's weight, or the unit itself.
    /// As typed; nil while empty.
    private(set) var typedQuantity: Double?
    /// As typed; an empty field counts as 0.
    private(set) var typedMacros: [Macro: Double?]
    /// The Extras the line holds, as typed; an empty field is not recorded.
    private(set) var typedExtras: [Extra: Double?]
    var saveAsFood: Bool
    /// What the line held when the page opened; nil for a line with no Estimate yet.
    let original: Estimate?
    /// A macro was typed on this page.
    private(set) var macrosTyped = false
    /// The quantity the macros are for: the last valid one, kept while the field is empty.
    private var macrosQuantity: Double
    private var gramsPerUnit: Double?

    /// Grams in one of each weight unit a line may be counted in.
    private static let gramsPer: [String: Double] = ["g": 1, "gram": 1, "grams": 1, "kg": 1_000, "oz": 28.3495, "lb": 453.592, "lbs": 453.592]

    init(_ line: DescribeLine) {
        let estimate = line.estimate
        original = estimate
        name = estimate?.name ?? line.trimmedText.prefix(1).uppercased() + line.trimmedText.dropFirst()
        unit = estimate?.unit ?? "serving"
        numbersUnit = unit
        if let estimate {
            gramsPerUnit = Self.gramsPer[estimate.unit.lowercased()]
                ?? estimate.grams.flatMap { estimate.quantity > 0 ? $0 / estimate.quantity : nil }
        }
        typedQuantity = estimate?.quantity ?? 1
        typedMacros = Dictionary(uniqueKeysWithValues: Macro.allCases.map { macro in (macro, estimate?.macros[macro]) })
        typedExtras = Dictionary(uniqueKeysWithValues: Extra.allCases.map { extra in (extra, estimate?.extras[extra]) })
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
        if let extras = Extras(typed: typedExtras) {
            let scaledExtras = extras.scaled(by: current / macrosQuantity)
            typedExtras = Dictionary(uniqueKeysWithValues: Extra.allCases.map { ($0, scaledExtras[$0]) })
        }
        macrosQuantity = current
    }

    /// Sets the unit. To a weight unit when the portion's weight is known, the same portion is
    /// re-expressed in it ("1 bowl" of 700 g becomes "700 g"), so the macros stay right and a
    /// new amount scales them. Any other change leaves the numbers for the old unit, which
    /// `unitNeedsNumbers` reports; partial typing ("o" on the way to "oz") changes nothing.
    mutating func setUnit(_ newValue: String) {
        unit = newValue
        let key = newValue.trimmingCharacters(in: .whitespaces).lowercased()
        guard let factor = Self.gramsPer[key], let perUnit = gramsPerUnit, let current = quantity,
              key != numbersUnit.lowercased() else { return }
        let converted = current * perUnit / factor
        let rounded = factor == 1 ? converted.rounded() : (converted * 10).rounded() / 10
        typedQuantity = rounded
        macrosQuantity = rounded
        numbersUnit = newValue.trimmingCharacters(in: .whitespaces)
        gramsPerUnit = factor
    }

    /// The unit was changed to one the numbers couldn't follow: they are still for the old one.
    var unitNeedsNumbers: Bool {
        let typed = unit.trimmingCharacters(in: .whitespaces)
        return !typed.isEmpty && typed.lowercased() != numbersUnit.lowercased()
    }

    /// The unit the numbers are still for, while `unitNeedsNumbers`.
    var numbersPortion: String {
        FoodText.portion(macrosQuantity, of: numbersUnit)
    }

    /// The line to send for a fresh estimate of the new portion: "Pho, 2 cups".
    var reestimateText: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(trimmedName.isEmpty ? (original?.name ?? "Food") : trimmedName), \(FoodText.portion(quantity ?? 1, of: unit.trimmingCharacters(in: .whitespaces)))"
    }

    mutating func setExtra(_ extra: Extra, _ value: Double?) {
        typedExtras[extra] = value
        extrasTyped = true
    }

    func typed(_ extra: Extra) -> Double? {
        typedExtras[extra] ?? nil
    }

    /// The Extras the page shows: those the line holds, and any typed here.
    var shownExtras: [Extra] {
        Extra.allCases.filter { typed($0) != nil || (original?.extras[$0] != nil) }
    }

    /// An Extra was typed on this page.
    private(set) var extrasTyped = false

    /// Typing a macro makes the numbers the user's own, for the unit as it now reads.
    mutating func setMacro(_ macro: Macro, _ value: Double?) {
        typedMacros[macro] = value
        macrosTyped = true
        if unitNeedsNumbers {
            numbersUnit = unit.trimmingCharacters(in: .whitespaces)
            macrosQuantity = quantity ?? macrosQuantity
            gramsPerUnit = Self.gramsPer[numbersUnit.lowercased()]
        }
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
        // A unit the numbers aren't for would log the old numbers under the new name: the line
        // keeps what it had until they're estimated again or typed.
        guard !unitNeedsNumbers, let quantity, let macros = Macros(typed: typedMacros) else { return nil }
        if original == nil, !macrosTyped || macros == .zero { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let renamed = trimmedName != (original?.name ?? trimmedName) || trimmedUnit != (original?.unit ?? trimmedUnit)
        let ownNumbers = macrosTyped || extrasTyped || original == nil
        let keepsMatch = !ownNumbers && !renamed
        var grams: Double?
        if let factor = Self.gramsPer[trimmedUnit.lowercased()] {
            grams = quantity * factor
        } else if let original, let originalGrams = original.grams, original.quantity > 0, !renamed {
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
            match: keepsMatch ? original?.match : nil,
            extras: (Extras(typed: typedExtras) ?? Extras()).normalised()
        )
    }
}

extension Estimate {

    /// The Serving that Save as food creates, and how many of it this line is
    /// (`ServingDraft.toSave`).
    var servingToSave: (serving: ServingDraft, quantity: Double) {
        ServingDraft.toSave(unit: unit, quantity: quantity, macros: macros, extras: extras, grams: grams)
    }
}

extension ServingDraft {

    /// The Serving that Save as food creates from a portion, and how many of it the portion
    /// is. A portion counted in grams or millilitres ("150 × g") saves a "100 g" Serving, so
    /// the food logs sensibly next time; anything else saves one of its unit.
    static func toSave(unit: String, quantity: Double, macros: Macros, extras: Extras = Extras(), grams: Double?) -> (serving: ServingDraft, quantity: Double) {
        let per100 = ["g", "gram", "grams", "ml"]
        let unitWord = unit.lowercased().trimmingCharacters(in: .whitespaces)
        if per100.contains(unitWord), quantity > 0 {
            let symbol = unitWord == "ml" ? "ml" : "g"
            let servings = quantity / 100
            return (ServingDraft(name: "100 \(symbol)", macros: macros.scaled(by: 1 / servings), grams: symbol == "g" ? 100 : nil, isDefault: true, extras: extras.scaled(by: 1 / servings)), servings)
        }
        let perOne = quantity > 0 ? 1 / quantity : 1
        return (ServingDraft(name: unit, macros: macros.scaled(by: perOne), grams: grams.map { $0 * perOne }, isDefault: true, extras: extras.scaled(by: perOne)), quantity)
    }
}
