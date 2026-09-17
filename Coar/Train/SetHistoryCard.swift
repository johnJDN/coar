import UIKit

extension CardView {
    /// A `Card` of Logged Sets as history lists them: a titled header, a `label`-style
    /// subtitle, then one line per set, "135 lbs × 5" in the metric style with its number in
    /// `textTertiary`. Shared by the Workout detail (one per row) and the Exercise detail's
    /// Recent sets (one per Workout).
    static func setHistory(title: String, subtitle: String, sets: [LoggedSetRecord], in unit: MassUnit) -> CardView {
        let card = CardView(title: title, systemImage: "dumbbell.fill")
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.label
        subtitleLabel.textColor = UIColor.textSecondary
        subtitleLabel.adjustsFontForContentSizeCategory = true
        card.contentStack.addArrangedSubview(subtitleLabel)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: subtitleLabel)
        for (index, set) in sets.enumerated() {
            card.contentStack.addArrangedSubview(setLine(number: index + 1, text: TrainText.setLine(set, in: unit)))
        }
        return card
    }

    private static func setLine(number: Int, text: String) -> UIView {
        let numberLabel = UILabel()
        numberLabel.text = "\(number)"
        numberLabel.font = UIFont.label
        numberLabel.textColor = UIColor.textTertiary
        numberLabel.adjustsFontForContentSizeCategory = true
        numberLabel.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let value = UILabel()
        value.text = text
        value.font = UIFont.metricNumber
        value.textColor = UIColor.textPrimary
        value.adjustsFontForContentSizeCategory = true

        let line = UIStackView(arrangedSubviews: [numberLabel, value])
        line.axis = .horizontal
        line.alignment = .firstBaseline
        line.spacing = Metrics.spaceTight
        line.isAccessibilityElement = true
        line.accessibilityLabel = "Set \(number), \(text)"
        return line
    }
}
