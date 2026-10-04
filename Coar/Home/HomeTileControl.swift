import UIKit

/// One of Home's four small tiles (DESIGN.md §11), side by side under the habits card: a
/// compact `Card` with the metric's icon, one value, and a caption naming it ("Sleep",
/// "lbs", "This week"); `—` in the value slot when there is nothing (§1.5). The tile is a
/// control: tapping it opens the screen behind it, or the Apple Health prompt while a
/// Health tile `connects` (spec story 80), its caption then reading "Connect" in the accent.
final class HomeTileControl: CardControl {

    private let accent: UIColor
    private let name: String
    private let valueLabel = UILabel()
    private let captionLabel = UILabel()
    private(set) var connects = false

    init(name: String, systemImage: String, accent: UIColor) {
        self.accent = accent
        self.name = name
        super.init(card: CardView(compact: true))

        let icon = UIImageView(image: UIImage(systemName: systemImage))
        icon.tintColor = accent
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline)
        icon.contentMode = .left

        valueLabel.font = UIFont.metricNumber.withRoundedDesign
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.5

        captionLabel.font = UIFont.label
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.adjustsFontSizeToFitWidth = true
        captionLabel.minimumScaleFactor = 0.7

        card.contentStack.spacing = 2
        card.contentStack.addArrangedSubview(icon)
        card.contentStack.setCustomSpacing(Metrics.spaceTight / 2, after: icon)
        card.contentStack.addArrangedSubview(valueLabel)
        card.contentStack.addArrangedSubview(captionLabel)

        isAccessibilityElement = true
        render(HomeTile(value: nil, caption: ""))
    }

    func render(_ tile: HomeTile) {
        connects = tile.connects
        let text = tile.value ?? "—"
        let apply = { [self] in
            valueLabel.text = text
            valueLabel.textColor = tile.value == nil ? UIColor.textTertiary : UIColor.textPrimary
        }
        if valueLabel.text != text, window != nil {
            UIView.transition(with: valueLabel, duration: 0.25, options: .transitionCrossDissolve, animations: apply)
        } else {
            apply()
        }
        captionLabel.text = tile.caption
        captionLabel.textColor = tile.connects ? accent : UIColor.textSecondary
        accessibilityLabel = "\(name), \(text) \(tile.connects ? "" : tile.caption)"
        accessibilityHint = tile.connects ? "Connects Apple Health" : nil
    }
}

private extension UIFont {
    /// The same font in SF Rounded, as numbers are drawn on Home (DESIGN.md §5).
    var withRoundedDesign: UIFont {
        fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 0) } ?? self
    }
}
