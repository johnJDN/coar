import UIKit

/// A collection view cell that is one `Card` edge to edge, with the §6 shadow allowed to
/// escape the cell. Subclasses add content to `card.contentStack` and may name a header.
class CardCell: UICollectionViewCell {

    /// The card's header row, if the subclass wants one.
    class var header: (title: String, systemImage: String, iconTint: UIColor)? { nil }

    let card: CardView

    override init(frame: CGRect) {
        let header = Self.header
        card = CardView(title: header?.title, systemImage: header?.systemImage, iconTint: header?.iconTint ?? UIColor.textPrimary)
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { card.alpha = isHighlighted ? 0.85 : 1 }
    }
}
