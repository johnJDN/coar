import UIKit

extension UIView {
    /// One Logged Set as history lists it: the set number in `textTertiary`, then
    /// "135 lbs × 5" in the metric style. Shared by the Workout detail and the Exercise
    /// detail's recent sets.
    static func setLine(number: Int, text: String) -> UIView {
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
