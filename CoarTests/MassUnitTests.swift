import XCTest
@testable import Coar

/// Seam 2: pure rule functions. Mass is stored in kilograms; the unit setting converts on
/// display and input only, rounding at one decimal (ADR 0004).
final class MassUnitTests: XCTestCase {

    func test_poundsEnteredAtOneDecimal_roundTripThroughKilograms_unchanged() {
        let entered = 185.3
        let stored = MassUnit.pounds.kilograms(fromDisplayValue: entered)
        XCTAssertEqual(MassUnit.pounds.displayValue(fromKilograms: stored), entered)
    }

    func test_poundsEnteredBeyondOneDecimal_areRoundedAtInputBeforeStoring() {
        // 185.37 lb rounds to 185.4 lb at input, which is 84.096 kg (not 185.37 lb's 84.083 kg).
        XCTAssertEqual(MassUnit.pounds.kilograms(fromDisplayValue: 185.37), 84.096, accuracy: 0.001)
    }

    func test_kilogramsDisplayedInPounds_roundsToOneDecimal() {
        // 80 kg is 176.3698... lb; a known-good conversion rounded at display precision.
        XCTAssertEqual(MassUnit.pounds.displayValue(fromKilograms: 80), 176.4)
    }

    func test_kilogramsDisplayedInKilograms_roundsToOneDecimal() {
        XCTAssertEqual(MassUnit.kilograms.displayValue(fromKilograms: 80.06), 80.1)
    }
}
