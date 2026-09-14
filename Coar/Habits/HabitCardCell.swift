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
    private let toggle = CheckToggleView()
    private let amountControl = AmountControlView()
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
        amountControl.onTap = { [weak self] in self?.onAmountTap?() }
        amountControl.setContentHuggingPriority(.required, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [emojiLabel, nameLabel, toggle, amountControl])
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
        toggle.reset()
        amountControl.reset()
    }

    func configure(with model: HabitCardModel) {
        emojiLabel.text = model.emoji
        nameLabel.text = model.name
        toggle.isHidden = model.kind != .yesNo
        amountControl.isHidden = model.kind != .quantitative
        switch model.kind {
        case .yesNo:
            toggle.setOn(model.isDoneToday, animated: false)
            toggle.accessibilityLabel = "Check in \(model.name)"
        case .quantitative:
            amountControl.setAmount(model.todayAmount, isMet: model.isDoneToday, animated: true)
            amountControl.accessibilityLabel = "Check in \(model.name)"
        }
        streak.setStreak(model.streak, unit: model.streakUnit, caption: model.weekCaption)
        heatmap.cells = model.heatmap
        heatmap.weekDots = model.weekDots
        accessibilityLabel = "\(model.name), \(model.streak) \(model.streakUnit) streak" + (model.weekCaption.map { ", \($0)" } ?? "")
    }
}
