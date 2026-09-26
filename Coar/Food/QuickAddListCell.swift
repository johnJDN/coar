import UIKit

/// A list row with the `ListRow` trailing square "+" (DESIGN.md §7) that logs the row once.
/// The cell owns one button for its whole life and only swaps what it does, so reconfiguring
/// or filtering never rebuilds the accessory: a new accessory view animates in from the
/// trailing edge on every apply.
final class QuickAddListCell: UICollectionViewListCell {

    private var action: (() -> Void)?

    private lazy var button: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(textStyle: .footnote).applying(UIImage.SymbolConfiguration(weight: .bold)))
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = Metrics.radiusTile
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.contentInsets = .zero
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in self?.action?() })
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32),
        ])
        return button
    }()

    func configureQuickAdd(name: String, isEnabled: Bool, action: @escaping () -> Void) {
        self.action = action
        button.isEnabled = isEnabled
        button.accessibilityLabel = "Add \(name) now"
        if accessories.isEmpty {
            accessories = [.customView(configuration: .init(customView: button, placement: .trailing()))]
        }
    }
}
