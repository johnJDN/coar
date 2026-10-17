import Foundation

/// A portion's unit as edited on a page (`DescribeLineEdit`, `EntryDraft`), and the unit the
/// macros are for. Changing to a weight unit when the portion's weight is known re-expresses
/// the same portion in it ("1 bowl" of 700 g becomes "700 g"), so the macros stay right. Any
/// other change leaves the numbers for the old unit, which `needsNumbers` reports; partial
/// typing ("o" on the way to "oz") changes nothing.
struct PortionUnit: Equatable {

    /// As typed.
    private(set) var typed: String
    /// The unit the macros are for. When `typed` differs, the numbers are for something else.
    private(set) var numbersUnit: String
    /// Grams in one `numbersUnit`, when known.
    private(set) var gramsPerUnit: Double?
    /// The unit it started in and its weight, so switching to grams can switch back.
    let originalUnit: String
    private let originalGrams: Double?

    /// Grams in one of each weight unit a portion may be counted in.
    static let gramsPer: [String: Double] = ["g": 1, "gram": 1, "grams": 1, "kg": 1_000, "oz": 28.3495, "lb": 453.592, "lbs": 453.592]

    /// `gramsInOne` is the weight of one, when known from elsewhere (an Estimate's grams);
    /// a unit that says its own weight ("100 g", "serving (28 g)") wins.
    init(_ unit: String, gramsInOne: Double? = nil) {
        typed = unit
        numbersUnit = unit
        gramsPerUnit = Self.grams(inOne: unit) ?? gramsInOne
        originalUnit = unit
        originalGrams = gramsPerUnit
    }

    /// Whether the portion's weight is known, so it can be given in grams.
    var knowsWeight: Bool { gramsPerUnit != nil }

    var trimmed: String {
        typed.trimmingCharacters(in: .whitespaces)
    }

    /// The unit was changed to one the numbers couldn't follow: they are still for the old one.
    var needsNumbers: Bool {
        !trimmed.isEmpty && trimmed.lowercased() != numbersUnit.lowercased()
    }

    /// Sets the unit, and returns the quantity re-expressed in it when both weights are known:
    /// a weight unit ("g", "oz"), a unit that says its weight ("serving (28 g)"), or the one it
    /// started in. Whole grams, anything else to two decimals.
    mutating func set(_ newValue: String, quantity: Double?) -> Double? {
        typed = newValue
        let key = trimmed.lowercased()
        let factor = Self.gramsPer[key] ?? Self.grams(inOne: trimmed) ?? (key == originalUnit.lowercased() ? originalGrams : nil)
        guard let factor, let perUnit = gramsPerUnit, let quantity, key != numbersUnit.lowercased() else { return nil }
        let converted = quantity * perUnit / factor
        numbersUnit = trimmed
        gramsPerUnit = factor
        return factor == 1 ? converted.rounded() : (converted * 100).rounded() / 100
    }

    /// Numbers were typed for the unit as it reads: it's the one they're for now.
    mutating func adopt() {
        numbersUnit = trimmed
        gramsPerUnit = Self.grams(inOne: numbersUnit)
    }

    /// Grams in one of a unit that says it: a weight unit ("oz"), a counted weight ("100 g"),
    /// or a weight in brackets ("serving (28 g)").
    static func grams(inOne unit: String) -> Double? {
        let text = unit.trimmingCharacters(in: .whitespaces).lowercased()
        if let factor = gramsPer[text] { return factor }
        let weight = /(\d+(?:\.\d+)?)\s*(g|grams?|kg|oz|lbs?)/
        if let match = text.wholeMatch(of: weight) ?? text.firstMatch(of: /\((\d+(?:\.\d+)?)\s*(g|grams?|kg|oz|lbs?)\)/),
           let amount = Double(match.output.1), let factor = gramsPer[String(match.output.2)] {
            return amount * factor
        }
        return nil
    }
}
