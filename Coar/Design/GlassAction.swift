import UIKit

extension UIButton {
    /// A glass capsule action floating on the screen ground (DESIGN.md §2): a leading symbol
    /// and a card-title label. The Train root's New plan and the logger's Add exercise.
    static func glassAction(title: String, systemImage: String, handler: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.glass()
        configuration.title = title
        configuration.image = UIImage(systemName: systemImage)
        configuration.imagePadding = Metrics.spaceTight
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .headline)
        configuration.cornerStyle = .capsule
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.titleTextAttributesTransformer = .cardTitle
        return UIButton(configuration: configuration, primaryAction: UIAction { _ in handler() })
    }

    /// A capsule action inside a card (DESIGN.md §3 `fill` "secondary buttons", §4 capsule):
    /// a leading symbol and a card-title label on `fill`. Home's Set targets.
    static func inCardAction(title: String, systemImage: String, handler: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: systemImage)
        configuration.imagePadding = Metrics.spaceTight
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .headline)
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.titleTextAttributesTransformer = .cardTitle
        return UIButton(configuration: configuration, primaryAction: UIAction { _ in handler() })
    }
}

/// `UIButton.glassAction` as a leading-aligned list item.
final class GlassActionCell: UICollectionViewCell {

    private var button: UIButton?

    func configure(title: String, systemImage: String, onTap: @escaping () -> Void) {
        button?.removeFromSuperview()
        let button = UIButton.glassAction(title: title, systemImage: systemImage, handler: onTap)
        button.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: contentView.topAnchor),
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            button.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor),
        ])
        self.button = button
    }
}
