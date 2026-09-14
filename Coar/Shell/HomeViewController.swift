import UIKit

/// Home. Holds one placeholder `Card` until ticket 14 builds the real layout.
final class HomeViewController: ScreenViewController {

    init() {
        super.init(title: "Home")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let card = CardView(title: "Today", systemImage: "sun.max.fill", accessory: .navigates)
        let value = UILabel()
        value.text = "—"
        value.font = UIFont.heroNumber
        value.textColor = UIColor.textTertiary
        value.adjustsFontForContentSizeCategory = true
        card.contentStack.addArrangedSubview(value)
        contentStack.addArrangedSubview(card)
    }
}
