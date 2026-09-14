import UIKit

/// The Streak as a hero number with its Period unit beside it ("12 days"). Muted at zero
/// (DESIGN.md §1.3: zero is a value, not missing data) and cross-dissolving on change (§9).
final class StreakHeroView: UIView {

    private let numberLabel = UILabel()
    private let unitLabel = UILabel()

    init() {
        super.init(frame: .zero)
        numberLabel.font = UIFont.heroNumber
        numberLabel.adjustsFontForContentSizeCategory = true
        numberLabel.setContentHuggingPriority(.required, for: .horizontal)
        unitLabel.font = UIFont.label
        unitLabel.textColor = UIColor.textSecondary
        unitLabel.adjustsFontForContentSizeCategory = true

        let row = UIStackView(arrangedSubviews: [numberLabel, unitLabel])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = Metrics.spaceTight
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setStreak(_ streak: Int, unit: String) {
        let text = String(streak)
        let apply = {
            self.numberLabel.text = text
            self.numberLabel.textColor = streak == 0 ? UIColor.textTertiary : UIColor.textPrimary
            self.unitLabel.text = unit
        }
        guard numberLabel.text != nil, numberLabel.text != text, window != nil else { return apply() }
        UIView.transition(with: numberLabel, duration: 0.25, options: .transitionCrossDissolve, animations: apply)
    }

    /// Forgets the shown value so the next `setStreak` does not animate from another Habit's.
    func reset() {
        numberLabel.text = nil
    }
}
