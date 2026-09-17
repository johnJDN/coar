import UIKit

/// A `Card` the user taps as one thing (DESIGN.md §7, trailing `→`): the card fills the
/// control and dims while pressed. Subclasses put content in `card.contentStack`. With
/// `interactiveContent`, controls inside the card (a `CheckToggle`, a capsule, a tappable
/// empty value) take their own taps and the card takes the rest; without it the card's
/// content is inert and every tap is the card's.
class CardControl: UIControl {

    let card: CardView

    init(card: CardView, interactiveContent: Bool = false) {
        self.card = card
        super.init(frame: .zero)
        card.isUserInteractionEnabled = interactiveContent
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { card.alpha = isHighlighted ? 0.85 : 1 }
    }
}
