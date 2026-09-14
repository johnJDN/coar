import UIKit

/// One habit as a `Card` (DESIGN.md §11): emoji, name, today's `CheckToggle`, the streak as
/// the hero number, and the heatmap. Tapping the card opens the detail; the toggle reports
/// through `onToggle`.
final class HabitCardCell: UICollectionViewCell {

    var onToggle: ((Bool) -> Void)?

    private let card = CardView()
    private let emojiLabel = UILabel()
    private let nameLabel = UILabel()
    private let toggle = CheckToggleView()
    private let streakLabel = UILabel()
    private let unitLabel = UILabel()
    private let heatmap = HeatmapView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false

        emojiLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        emojiLabel.adjustsFontForContentSizeCategory = true
        emojiLabel.setContentHuggingPriority(.required, for: .horizontal)

        nameLabel.font = UIFont.cardTitle
        nameLabel.textColor = UIColor.textPrimary
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2

        toggle.onToggle = { [weak self] on in self?.onToggle?(on) }
        toggle.setContentHuggingPriority(.required, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [emojiLabel, nameLabel, toggle])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = Metrics.spaceTight

        streakLabel.font = UIFont.heroNumber
        streakLabel.adjustsFontForContentSizeCategory = true
        streakLabel.setContentHuggingPriority(.required, for: .horizontal)
        unitLabel.font = UIFont.label
        unitLabel.textColor = UIColor.textSecondary
        unitLabel.adjustsFontForContentSizeCategory = true

        let hero = UIStackView(arrangedSubviews: [streakLabel, unitLabel])
        hero.axis = .horizontal
        hero.alignment = .firstBaseline
        hero.spacing = Metrics.spaceTight

        card.contentStack.addArrangedSubview(header)
        card.contentStack.addArrangedSubview(hero)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: hero)
        card.contentStack.addArrangedSubview(heatmap)
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

    func configure(with model: HabitCardModel) {
        emojiLabel.text = model.emoji
        nameLabel.text = model.name
        toggle.setOn(model.isDoneToday, animated: false)
        toggle.accessibilityLabel = "Check in \(model.name)"
        setStreak(model.streak, unit: model.streakUnit)
        heatmap.cells = model.heatmap
        accessibilityLabel = "\(model.name), \(model.streak) \(model.streakUnit) streak"
    }

    override var isHighlighted: Bool {
        didSet { card.alpha = isHighlighted ? 0.85 : 1 }
    }

    /// The hero is muted at zero (DESIGN.md §1.3) and cross-dissolves when it changes (§9).
    private func setStreak(_ streak: Int, unit: String) {
        let text = String(streak)
        let apply = {
            self.streakLabel.text = text
            self.streakLabel.textColor = streak == 0 ? UIColor.textTertiary : UIColor.textPrimary
            self.unitLabel.text = unit
        }
        guard streakLabel.text != nil, streakLabel.text != text, window != nil else { return apply() }
        UIView.transition(with: streakLabel, duration: 0.25, options: .transitionCrossDissolve, animations: apply)
    }
}
