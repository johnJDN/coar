import UIKit
import XCTest
@testable import Coar

final class MacroLineTests: XCTestCase {

    func test_styledMacroLine_readsLikeThePlainLine_withEachGramMacroInItsAccent() {
        let macros = Macros(calories: 140, protein: 12, fat: 10, carbs: 0)
        let line = FoodText.styledMacroLineUIKit(macros)
        XCTAssertEqual(line.string, FoodText.macroLine(macros))

        for macro in [Macro.protein, .fat, .carbs] {
            let range = (line.string as NSString).range(of: "\(macro.abbreviation) ")
            XCTAssertNotEqual(range.location, NSNotFound)
            let colour = line.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor
            XCTAssertEqual(colour, macro.uiAccent, "\(macro)")
        }
        XCTAssertNil(line.attribute(.foregroundColor, at: 0, effectiveRange: nil), "kcal keeps the label's colour")
    }
}
