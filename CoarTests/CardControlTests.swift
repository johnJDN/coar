import UIKit
import XCTest
@testable import Coar

/// A card with controls inside (Home's Habits card, the Health squares) takes every tap
/// that is not on one of those controls; a tap on a label inside it used to reach neither.
@MainActor
final class CardControlTests: XCTestCase {

    private func makeCard() -> (control: CardControl, label: UILabel, button: UIButton) {
        let control = CardControl(card: CardView(), interactiveContent: true)
        let label = UILabel()
        label.text = "No data"
        let button = UIButton(type: .system)
        button.setTitle("Check", for: .normal)
        control.card.contentStack.addArrangedSubview(label)
        control.card.contentStack.addArrangedSubview(button)
        control.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        control.layoutIfNeeded()
        return (control, label, button)
    }

    private func center(of view: UIView, in control: UIView) -> CGPoint {
        view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: control)
    }

    func test_aTapOnALabelInsideAnInteractiveCard_isTheCards() {
        let (control, label, _) = makeCard()
        XCTAssertTrue(control.hitTest(center(of: label, in: control), with: nil) === control)
    }

    func test_aTapOnAControlInsideAnInteractiveCard_isThatControls() {
        let (control, _, button) = makeCard()
        let hit = control.hitTest(center(of: button, in: control), with: nil)
        XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
    }

    func test_aTappableEmptyValue_keepsItsTap() {
        let (control, _, _) = makeCard()
        let hero = HeroNumberLabel()
        hero.onTapEmpty = {}
        hero.setValue("No data", isEmpty: true)
        control.card.contentStack.addArrangedSubview(hero)
        control.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        control.layoutIfNeeded()
        XCTAssertTrue(control.hitTest(center(of: hero, in: control), with: nil) === hero)

        hero.setValue("7h 32m", isEmpty: false)
        XCTAssertTrue(control.hitTest(center(of: hero, in: control), with: nil) === control)
    }
}
