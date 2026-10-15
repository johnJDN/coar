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
    private var gramsPerUnit: Double?

    /// Grams in one of each weight unit a portion may be counted in.
    static let gramsPer: [String: Double] = ["g": 1, "gram": 1, "grams": 1, "kg": 1_000, "oz": 28.3495, "lb": 453.592, "lbs": 453.592]

    /// `gramsInOne` is the weight of one, when known from elsewhere (an Estimate's grams);
    /// a unit that says its own weight ("100 g", "serving (28 g)") wins.
    init(_ unit: String, gramsInOne: Double? = nil) {
        typed = unit
        numbersUnit = unit
        gramsPerUnit = Self.grams(inOne: unit) ?? gramsInOne
    }

    var trimmed: String {
        typed.trimmingCharacters(in: .whitespaces)
    }

    /// The unit was changed to one the numbers couldn't follow: they are still for the old one.
    var needsNumbers: Bool {
        !trimmed.isEmpty && trimmed.lowercased() != numbersUnit.lowercased()
    }

    /// Sets the unit, and returns the quantity re-expressed in it when it's a weight unit and
    /// the weight is known: whole grams, other weights to one decimal.
    mutating func set(_ newValue: String, quantity: Double?) -> Double? {
        typed = newValue
        let key = trimmed.lowercased()
        guard let factor = Self.gramsPer[key], let perUnit = gramsPerUnit, let quantity,
              key != numbersUnit.lowercased() else { return nil }
        let converted = quantity * perUnit / factor
        numbersUnit = trimmed
        gramsPerUnit = factor
        return factor == 1 ? converted.rounded() : (converted * 10).rounded() / 10
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
