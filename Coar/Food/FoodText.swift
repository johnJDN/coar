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

    /// The typed quantity when it is a positive number, else nil.
    static func quantity(typed value: Double?) -> Double? {
        guard let value, value > 0, value.isFinite else { return nil }
        return value
    }

    /// "140 kcal".
    static func calories(_ macros: Macros) -> String {
        "\(macros.calories.formatted(.number.precision(.fractionLength(0)))) kcal"
    }

    /// "70 kcal • 1 egg": a Serving's line in the picker (DESIGN.md §7 `ListRow`).
    static func summary(of serving: ServingRecord) -> String {
        "\(calories(serving.macros)) • \(serving.name)"
    }

    /// "Today at 8:00 AM" / "Monday, September 7 at 12:00 PM".
    static func when(_ instant: Date) -> String {
        "\(Day(instant).title()) at \(instant.formatted(.dateTime.hour().minute()))"
    }
}
