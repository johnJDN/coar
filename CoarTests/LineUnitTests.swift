import XCTest
@testable import Coar

/// Changing a Describe line's unit (`.scratch/describe-qol/issues/02`): to a weight, when the
/// portion's weight is known, the same portion is re-expressed in it, so the numbers stay right
/// and a new amount scales them; to anything else the numbers can't follow, so the page says so
/// and offers to estimate again for the new portion.
final class LineUnitTests: XCTestCase {

    private let pho = Macros(calories: 450, protein: 30, fat: 12, carbs: 55)

    private func line(unit: String = "bowl", quantity: Double = 1, grams: Double? = 700) -> DescribeLineEdit {
        let estimate = Estimate(name: "Pho", quantity: quantity, unit: unit, grams: grams, macros: pho, source: .estimated, assumption: "")
        return DescribeLineEdit(DescribeLine(text: "pho", state: .filled(estimate)))
    }

    func test_toGrams_withAKnownWeight_reexpressesThePortion_andANewAmountScalesIt() throws {
        var edit = line()
        edit.setUnit("g")
        XCTAssertEqual(edit.quantity, 700)
        XCTAssertEqual(edit.estimate?.macros, pho, "the same bowl, in grams")
        XCTAssertFalse(edit.unitNeedsNumbers)

        edit.setQuantity(350)
        XCTAssertEqual(edit.estimate?.macros.calories, 225)
        XCTAssertEqual(edit.estimate?.grams, 350)
        XCTAssertEqual(edit.estimate?.unit, "g")
    }

    func test_toOunces_andBackThroughTyping_landsOnTheSamePortion() throws {
        var edit = line()
        for partial in ["", "o", "oz"] { edit.setUnit(partial) }
        XCTAssertEqual(try XCTUnwrap(edit.quantity), 24.7, accuracy: 0.05)
        XCTAssertEqual(edit.estimate?.macros, pho)
        edit.setUnit("g")
        XCTAssertEqual(try XCTUnwrap(edit.quantity), 700, accuracy: 1)
    }

    func test_aUnitTheNumbersCantFollow_isFlagged_andOffersAnEstimateForTheNewPortion() {
        var edit = line()
        edit.setUnit("cup")
        XCTAssertTrue(edit.unitNeedsNumbers)
        XCTAssertNil(edit.estimate, "the line keeps what it had rather than the bowl's numbers as a cup")
        edit.setQuantity(2)
        XCTAssertEqual(edit.reestimateText, "Pho, 2 cups")
    }

    func test_typingTheMacrosForTheNewUnit_makesThemTheLines() {
        var edit = line()
        edit.setUnit("cup")
        edit.setMacro(.calories, 200)
        XCTAssertFalse(edit.unitNeedsNumbers)
        XCTAssertEqual(edit.estimate?.unit, "cup")
        XCTAssertEqual(edit.estimate?.macros.calories, 200)
        XCTAssertEqual(edit.estimate?.source, .typed)
    }

    func test_toGrams_withNoKnownWeight_isFlaggedToo() {
        var edit = line(grams: nil)
        edit.setUnit("g")
        XCTAssertTrue(edit.unitNeedsNumbers)
        XCTAssertEqual(edit.quantity, 1)
    }

    func test_puttingTheUnitBack_clearsTheFlag() {
        var edit = line()
        edit.setUnit("cup")
        edit.setUnit("bowl")
        XCTAssertFalse(edit.unitNeedsNumbers)
    }

    func test_aLineAlreadyInGrams_changesToOuncesByItsOwnUnit() throws {
        var edit = line(unit: "g", quantity: 200, grams: nil)
        edit.setUnit("oz")
        XCTAssertEqual(try XCTUnwrap(edit.quantity), 7.1, accuracy: 0.05)
        XCTAssertEqual(edit.estimate?.macros, pho)
    }
}
