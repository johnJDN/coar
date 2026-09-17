import XCTest
@testable import Coar

/// Seam 2: pure rule functions. Home's macros card draws a `DotMatrix` per macro, one dot per
/// unit (DESIGN.md §7), against the Target in force; with no Target there is no matrix at
/// all, never one against an implied 0 (`.scratch/data-model/issues/02`).
final class MacroDotsTests: XCTestCase {

    func test_gramsAreOneDotPerFiveGrams_filledByWhatWasEaten() throws {
        let dots = try XCTUnwrap(MacroDots(macro: .protein, consumed: 140, target: 180))

        XCTAssertEqual(dots.unit, 5)
        XCTAssertEqual(dots.total, 36)
        XCTAssertEqual(dots.filled, 28)
        XCTAssertFalse(dots.isOver)
    }

    func test_caloriesAreOneDotPerFiftyKilocalories_inTwoEvenRows() throws {
        let dots = try XCTUnwrap(MacroDots(macro: .calories, consumed: 1_240, target: 2_100))

        XCTAssertEqual(dots.unit, 50)
        XCTAssertEqual(dots.total, 42)
        XCTAssertEqual(dots.filled, 25)
        XCTAssertEqual(dots.columns, 21)
    }

    func test_aLargeTarget_takesACoarserUnit_soTheMatrixStaysTwoRows() throws {
        let dots = try XCTUnwrap(MacroDots(macro: .carbs, consumed: 0, target: 400))

        XCTAssertEqual(dots.unit, 10)
        XCTAssertEqual(dots.total, 40)
        XCTAssertEqual(dots.filled, 0)
        XCTAssertEqual(dots.columns, 20)
    }

    func test_overTheTarget_everyDotIsFilled_andTheMatrixSaysSo() throws {
        let dots = try XCTUnwrap(MacroDots(macro: .calories, consumed: 2_500, target: 2_100))

        XCTAssertEqual(dots.filled, dots.total)
        XCTAssertTrue(dots.isOver)
    }

    func test_aShortRow_fitsOneLine() throws {
        let dots = try XCTUnwrap(MacroDots(macro: .fat, consumed: 41, target: 60))

        XCTAssertEqual(dots.total, 12)
        XCTAssertEqual(dots.columns, 12)
        XCTAssertEqual(dots.filled, 8)
    }

    func test_withNoTarget_thereIsNoMatrix() {
        XCTAssertNil(MacroDots(macro: .protein, consumed: 140, target: nil))
        XCTAssertNil(MacroDots(macro: .protein, consumed: 140, target: 0))
    }
}
