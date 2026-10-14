import Foundation

/// Amounts and captions as the Food screens show them, and the number rules the forms share.
enum FoodText {

    /// Whole numbers plain, a fraction kept to one decimal when there is one.
    static func amount(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// "2 × 1 egg": how much of which Serving.
    static func quantity(_ quantity: Double, of servingName: String) -> String {
        "\(amount(quantity)) × \(servingName)"
    }

    /// The portion as a person says it, for a timeline card's second row: "1 medium banana",
    /// "3 slices", "2 servings (28 g)", "150 g". A Serving named with its own amount ("1 egg",
    /// "100 g") keeps the "×" for more than one ("4 × 1 egg"), and so does a fraction of a
    /// counted thing ("1.5 × cup"), which has no natural plural.
    static func portion(_ quantity: Double, of servingName: String) -> String {
        let unit = servingName.trimmingCharacters(in: .whitespaces)
        let count = amount(quantity)
        if unit.first?.isNumber == true {
            return quantity == 1 ? unit : "\(count) × \(unit)"
        }
        if measures.contains(unit.lowercased()) {
            return "\(count) \(unit)"
        }
        if quantity == 1 { return "1 \(unit)" }
        guard quantity == quantity.rounded() else { return "\(count) × \(unit)" }
        return "\(count) \(plural(unit))"
    }

    /// Units said as an amount, never pluralised: "150 g", "2 tbsp".
    private static let measures: Set<String> = ["g", "gram", "grams", "kg", "mg", "ml", "l", "oz", "fl oz", "lb", "lbs", "tbsp", "tsp"]

    /// "slice" → "slices", "glass" → "glasses", "patty" → "patties", "serving (28 g)" →
    /// "servings (28 g)", "piece of toast" → "pieces of toast". The noun pluralised is the one
    /// before " (" or " of ", else the last word; one already ending in "s" stays.
    static func plural(_ phrase: String) -> String {
        var head = phrase
        var tail = ""
        for marker in [" (", " of "] {
            if let range = head.range(of: marker) {
                tail = String(head[range.lowerBound...]) + tail
                head = String(head[..<range.lowerBound])
            }
        }
        var words = head.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard let last = words.last, !last.isEmpty else { return phrase }
        words[words.count - 1] = pluralWord(last)
        return words.joined(separator: " ") + tail
    }

    private static func pluralWord(_ word: String) -> String {
        let lower = word.lowercased()
        if lower.hasSuffix("s") && !lower.hasSuffix("ss") { return word }
        if ["ss", "x", "z", "ch", "sh"].contains(where: { lower.hasSuffix($0) }) { return word + "es" }
        if lower.hasSuffix("y"), let before = lower.dropLast().last, !"aeiou".contains(before) {
            return String(word.dropLast()) + "ies"
        }
        return word + "s"
    }

    /// The typed quantity when it is a positive number, else nil.
    static func quantity(typed value: Double?) -> Double? {
        guard let value, value > 0, value.isFinite else { return nil }
        return value
    }

    /// "140 cal".
    static func calories(_ macros: Macros) -> String {
        "\(macros.calories.formatted(.number.precision(.fractionLength(0)))) cal"
    }

    /// "140 cal · P 12 · F 10 · C 0": the four macros on one line.
    static func macroLine(_ macros: Macros) -> String {
        ([calories(macros)] + [Macro.protein, .fat, .carbs].map { "\($0.abbreviation) \(amount(macros[$0]))" }).joined(separator: " · ")
    }

    /// "70 cal • 1 egg": a Serving's line in the picker (DESIGN.md §7 `ListRow`).
    static func summary(of serving: ServingRecord) -> String {
        "\(calories(serving.macros)) • \(serving.name)"
    }

    /// "Today at 8:00 AM" / "Monday, September 7 at 12:00 PM".
    static func when(_ instant: Date) -> String {
        "\(Day(instant).title()) at \(instant.formatted(.dateTime.hour().minute()))"
    }
}
