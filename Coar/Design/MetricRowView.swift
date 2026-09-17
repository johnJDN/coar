import UIKit

/// `MetricRow` (DESIGN.md §7): a leading emoji or tinted icon, a label, an optional trailing
/// value in `textSecondary`, and a trailing slot for a control (a `CheckToggle`, an
/// `AmountControl`, a square `→`). Home's habits card is one per Habit.
final class MetricRowView: UIView {

    enum Leading: Equatable {
        case emoji(String)
        case symbol(String, tint: UIColor)
    }

    private let emojiLabel = UILabel()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    init(trailing: UIView? = nil) {
        super.init(frame: .zero)

        emojiLabel.font = UIFont.preferredFont(forTextStyle: .title3)
        emojiLabel.adjustsFontForContentSizeCategory = true
        emojiLabel.setContentHuggingPriority(.required, for: .horizontal)

        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = UIFont.bodyText
        titleLabel.textColor = UIColor.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2

        valueLabel.font = UIFont.bodyText
        valueLabel.textColor = UIColor.textSecondary
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [emojiLabel, iconView, titleLabel, valueLabel] + (trailing.map { [$0] } ?? []))
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metrics.spaceTight
        row.translatesAutoresizingMaskIntoConstraints = false
        trailing?.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: CapsuleControlView.height),
        ])
        configure(leading: .emoji(""), title: "", value: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(leading: Leading, title: String, value: String? = nil) {
        switch leading {
        case .emoji(let emoji):
            emojiLabel.text = emoji
            emojiLabel.isHidden = false
            iconView.isHidden = true
        case .symbol(let name, let tint):
            iconView.image = UIImage(systemName: name)
            iconView.tintColor = tint
            iconView.isHidden = false
            emojiLabel.isHidden = true
        }
        titleLabel.text = title
        valueLabel.text = value
        valueLabel.isHidden = value == nil
    }
}
