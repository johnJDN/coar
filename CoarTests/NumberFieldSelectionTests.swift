import UIKit
import XCTest
@testable import Coar

@MainActor
final class NumberFieldSelectionTests: XCTestCase {

    func test_numberAndDecimalPads_areNumberFields_textFieldsAreNot() {
        let field = UITextField()
        field.keyboardType = .numberPad
        XCTAssertTrue(NumberFieldSelection.isNumberField(field))
        field.keyboardType = .decimalPad
        XCTAssertTrue(NumberFieldSelection.isNumberField(field))
        field.keyboardType = .default
        XCTAssertFalse(NumberFieldSelection.isNumberField(field))
    }

    func test_beginningToEdit_selectsTheWholeValue() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let field = UITextField(frame: CGRect(x: 0, y: 0, width: 100, height: 44))
        field.keyboardType = .numberPad
        field.text = "1"
        window.addSubview(field)
        window.makeKeyAndVisible()
        NumberFieldSelection.install()

        field.becomeFirstResponder()
        let selected = expectation(description: "selected")
        DispatchQueue.main.async { DispatchQueue.main.async { selected.fulfill() } }
        wait(for: [selected], timeout: 1)

        let range = try? XCTUnwrap(field.selectedTextRange)
        XCTAssertEqual(range.map { field.text(in: $0) }, "1")
    }
}
