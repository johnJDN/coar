import UIKit

/// One habit as a `Card` (DESIGN.md §11): emoji, name, today's control (a `CheckToggle` for
/// a yes/no Habit, an `AmountControl` for a quantitative one), the streak as the hero
/// number, and the heatmap. Tapping the card opens the detail; the toggle reports through
/// `onToggle`, the amount control through `onAmountTap`.
final class HabitCardCell: CardCell {

    var onToggle: ((Bool) -> Void)?
    var onAmountTap: (() -> Void)?

    private let emojiLabel = UILabel()
    private let nameLabel = UILabel()
    private let controls = HabitCheckInControls()
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

        controls.onToggle = { [weak self] on in self?.onToggle?(on) }
        controls.onAmountTap = { [weak self] in self?.onAmountTap?() }

        let header = UIStackView(arrangedSubviews: [emojiLabel, nameLabel, controls])
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
        controls.reset()
    }

    func configure(with model: HabitCardModel) {
        emojiLabel.text = model.emoji
        nameLabel.text = model.name
        controls.configure(with: model)
        streak.setStreak(model.streak, unit: model.streakUnit, caption: model.weekCaption)
        heatmap.cells = model.heatmap
        heatmap.weekDots = model.weekDots
        accessibilityLabel = "\(model.name), \(model.streak) \(model.streakUnit) streak" + (model.weekCaption.map { ", \($0)" } ?? "")
    }
}
