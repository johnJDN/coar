import UIKit

/// The Superset link between two grouped `ExerciseCard`s in the logger (DESIGN.md §7): a
/// small `link` badge on the screen ground, `accentLavender` like the Plan editor's link
/// button. The logger lays its cards out with no spacing of their own, so this cell is the
/// whole gap between two grouped cards, as `CardGapCell` is between two on their own.
final class SupersetLinkCell: UICollectionViewCell {

    static let height: CGFloat = 24

    override init(frame: CGRect) {
        super.init(frame: frame)
        let badge = UIImageView(image: UIImage(systemName: "link"))
        badge.tintColor = UIColor.accentLavender
        badge.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        badge.contentMode = .center
        badge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badge)
        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(equalToConstant: Self.height),
            badge.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
        isAccessibilityElement = true
        accessibilityLabel = "Superset, continues below"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// `spaceCard` of air between two cards that are not linked.
final class CardGapCell: UICollectionViewCell {

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.heightAnchor.constraint(equalToConstant: Metrics.spaceCard).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
