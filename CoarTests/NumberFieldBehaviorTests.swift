import UIKit
import XCTest
@testable import Coar

@MainActor
final class NumberFieldBehaviorTests: XCTestCase {

    func test_numberAndDecimalPads_areNumberFields_textFieldsAreNot() {
        let field = UITextField()
        field.keyboardType = .numberPad
        XCTAssertTrue(NumberFieldBehavior.isNumberField(field))
        field.keyboardType = .decimalPad
        XCTAssertTrue(NumberFieldBehavior.isNumberField(field))
        field.keyboardType = .default
        XCTAssertFalse(NumberFieldBehavior.isNumberField(field))
    }

    func test_beginningToEdit_selectsTheWholeValue() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let field = UITextField(frame: CGRect(x: 0, y: 0, width: 100, height: 44))
        field.keyboardType = .numberPad
        field.text = "1"
        window.addSubview(field)
        window.makeKeyAndVisible()
        NumberFieldBehavior.install()

        field.becomeFirstResponder()
        let selected = expectation(description: "selected")
        DispatchQueue.main.async { DispatchQueue.main.async { selected.fulfill() } }
        wait(for: [selected], timeout: 1)

        let range = try? XCTUnwrap(field.selectedTextRange)
        XCTAssertEqual(range.map { field.text(in: $0) }, "1")
        XCTAssertNotNil(field.inputAccessoryView, "a number pad gets a Done bar")
    }

    func test_aFieldWithItsOwnAccessory_keepsIt() {
        let field = UITextField()
        let own = UIView()
        field.inputAccessoryView = own
        NumberFieldBehavior.attachDoneBar(to: field)
        XCTAssertTrue(field.inputAccessoryView === own)
    }
}

