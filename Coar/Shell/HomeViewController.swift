import UIKit

/// Home. Holds one placeholder `Card` until ticket 14 builds the real layout. The avatar
/// button opens Settings as a sheet.
final class HomeViewController: ScreenViewController {

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(title: "Home")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let avatar = UIBarButtonItem(
            image: UIImage(systemName: "person.crop.circle"),
            primaryAction: UIAction { [weak self] _ in self?.presentSettings() }
        )
        avatar.accessibilityLabel = "Settings"
        navigationItem.rightBarButtonItem = avatar

        let card = CardView(title: "Today", systemImage: "sun.max.fill", accessory: .navigates)
        let value = UILabel()
        value.text = "—"
        value.font = UIFont.heroNumber
        value.textColor = UIColor.textTertiary
        value.adjustsFontForContentSizeCategory = true
        card.contentStack.addArrangedSubview(value)
        contentStack.addArrangedSubview(card)
    }

    private func presentSettings() {
        present(SettingsViewController.sheet(dependencies: dependencies), animated: true)
    }
}
