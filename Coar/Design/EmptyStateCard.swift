import UIKit

extension CardView {
    /// The empty state (DESIGN.md §1.5): the card the first record will occupy, with `—` in
    /// the value's slot and a caption saying how to fill it.
    static func emptyState(caption text: String, accessibilityLabel: String) -> CardView {
        let card = CardView()
        let hero = UILabel()
        hero.text = "—"
        hero.font = UIFont.heroNumber
        hero.textColor = UIColor.textTertiary
        hero.adjustsFontForContentSizeCategory = true
        let caption = UILabel()
        caption.text = text
        caption.font = UIFont.label
        caption.textColor = UIColor.textSecondary
        caption.adjustsFontForContentSizeCategory = true
        caption.numberOfLines = 0
        card.contentStack.addArrangedSubview(hero)
        card.contentStack.addArrangedSubview(caption)
        card.isAccessibilityElement = true
        card.accessibilityLabel = accessibilityLabel
        return card
    }
}
