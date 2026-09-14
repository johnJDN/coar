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
        return (value * 10).rounded() / 10
    }

    /// The kilograms to store for a value the user entered in this unit.
    func kilograms(fromDisplayValue value: Double) -> Double {
        switch self {
        case .pounds: return value / Self.poundsPerKilogram
        case .kilograms: return value
        }
    }

    var symbol: String {
        switch self {
        case .pounds: return "lbs"
        case .kilograms: return "kg"
        }
    }
}
