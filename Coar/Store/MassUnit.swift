import Foundation

/// The unit a mass is shown and entered in. Every stored mass is kilograms (ADR 0004); the
/// unit converts on display and input only, rounding at one decimal.
enum MassUnit: String, CaseIterable {
    case pounds
    case kilograms

    private static let poundsPerKilogram = 2.204_622_621_848_776

    /// The value shown to the user for a stored mass, rounded to one decimal.
    func displayValue(fromKilograms kilograms: Double) -> Double {
        let value: Double
        switch self {
        case .pounds: value = kilograms * Self.poundsPerKilogram
        case .kilograms: value = kilograms
        }
        return Self.roundedToOneDecimal(value)
    }

    /// The kilograms to store for a value the user entered in this unit, rounded at display
    /// precision first so what is stored is exactly what was shown.
    func kilograms(fromDisplayValue value: Double) -> Double {
        let entered = Self.roundedToOneDecimal(value)
        switch self {
        case .pounds: return entered / Self.poundsPerKilogram
        case .kilograms: return entered
        }
    }

    /// The display value as text, e.g. "185.3"; the log sheet's field.
    func displayValueText(fromKilograms kilograms: Double) -> String {
        displayValue(fromKilograms: kilograms).formatted(.number.precision(.fractionLength(1)))
    }

    /// The stored mass as the user reads it, e.g. "185.3 lbs".
    func displayText(fromKilograms kilograms: Double) -> String {
        "\(displayValueText(fromKilograms: kilograms)) \(symbol)"
    }

    private static func roundedToOneDecimal(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    var symbol: String {
        switch self {
        case .pounds: return "lbs"
        case .kilograms: return "kg"
        }
    }
}
