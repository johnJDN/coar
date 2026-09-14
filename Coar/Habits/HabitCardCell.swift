import UIKit

/// One habit as a `Card` (DESIGN.md §11): emoji, name, today's `CheckToggle`, the streak as
/// the hero number, and the heatmap. Tapping the card opens the detail; the toggle reports
/// through `onToggle`.
final class HabitCardCell: CardCell {

    var onToggle: ((Bool) -> Void)?

    private let emojiLabel = UILabel()
    private let nameLabel = UILabel()
    private let toggle = CheckToggleView()
    private let streak = StreakHeroView()
    private let heatmap = HeatmapView()

    override init(frame: CGRect) {
        super.init(frame: frame)

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

        card.contentStack.addArrangedSubview(header)
        card.contentStack.addArrangedSubview(streak)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: streak)
        card.contentStack.addArrangedSubview(heatmap)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        streak.reset()
    }

    func configure(with model: HabitCardModel) {
        emojiLabel.text = model.emoji
        nameLabel.text = model.name
        toggle.setOn(model.isDoneToday, animated: false)
        toggle.accessibilityLabel = "Check in \(model.name)"
        streak.setStreak(model.streak, unit: model.streakUnit)
        heatmap.cells = model.heatmap
        accessibilityLabel = "\(model.name), \(model.streak) \(model.streakUnit) streak"
    }
}
