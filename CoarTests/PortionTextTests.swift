import XCTest
@testable import Coar

/// How a portion reads on a timeline card (`.scratch/food-cards/`): said the way a person would
/// say it, so the card's second row is short and never needs a "×" for one of something.
final class PortionTextTests: XCTestCase {

    func test_oneOfSomething_readsPlainly() {
        XCTAssertEqual(FoodText.portion(1, of: "medium banana"), "1 medium banana")
        XCTAssertEqual(FoodText.portion(1, of: "serving (28 g)"), "1 serving (28 g)")
        XCTAssertEqual(FoodText.portion(1, of: "meal"), "1 meal")
    }

    func test_wholeCounts_arePlural() {
        XCTAssertEqual(FoodText.portion(3, of: "slice"), "3 slices")
        XCTAssertEqual(FoodText.portion(2, of: "large egg"), "2 large eggs")
        XCTAssertEqual(FoodText.portion(2, of: "serving (28 g)"), "2 servings (28 g)")
        XCTAssertEqual(FoodText.portion(2, of: "glass"), "2 glasses")
        XCTAssertEqual(FoodText.portion(2, of: "patty"), "2 patties")
        XCTAssertEqual(FoodText.portion(2, of: "piece of toast"), "2 pieces of toast")
        XCTAssertEqual(FoodText.portion(2, of: "chips"), "2 chips", "already plural")
    }

    func test_measures_readAsAnAmount() {
        XCTAssertEqual(FoodText.portion(150, of: "g"), "150 g")
        XCTAssertEqual(FoodText.portion(1.5, of: "oz"), "1.5 oz")
        XCTAssertEqual(FoodText.portion(2, of: "tbsp"), "2 tbsp")
    }

    func test_aServingNamedWithItsOwnAmount_keepsTheTimes_unlessThereIsOne() {
        XCTAssertEqual(FoodText.portion(1, of: "1 egg"), "1 egg")
        XCTAssertEqual(FoodText.portion(4, of: "1 egg"), "4 × 1 egg")
        XCTAssertEqual(FoodText.portion(1, of: "100 g"), "100 g")
    }

    func test_aFractionOfSomething_keepsTheTimes() {
        XCTAssertEqual(FoodText.portion(1.5, of: "cup"), "1.5 × cup")
        XCTAssertEqual(FoodText.portion(0.5, of: "meal"), "0.5 × meal")
    }

    func test_theMacroRow_roundsToWholeGrams() {
        let line = FoodText.styledMacroLine(Macros(calories: 105, protein: 1.3, fat: 0.3, carbs: 44.5), includesCalories: false, wholeGrams: true)
        XCTAssertEqual(String(line.characters), "P 1 · F 0 · C 45")
    }
}
