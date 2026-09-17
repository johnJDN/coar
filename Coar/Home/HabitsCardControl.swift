import UIKit

/// Home's habits card (DESIGN.md §11): a full-width `Card` with how many Habits are done
/// today as the hero, then a `MetricRow` per active Habit with its check-in control inline,
/// a `CheckToggle` for a yes/no Habit and an `AmountControl` for a quantitative one, exactly
/// as on the Habits tab. Tapping the card opens the Habits tab; the controls report through
/// `onToggle` and `onAmountTap`, and the owner writes and re-renders. With no Habit the hero
/// is `—` and the card stays (§1.5).
final class HabitsCardControl: CardControl {

    var onToggle: ((HabitRecord.ID, Bool) -> Void)?
    var onAmountTap: ((HabitRecord.ID) -> Void)?

    private let heroLabel = HeroNumberLabel()
    private let captionLabel = UILabel()
    private let rowsStack = UIStackView()
    private var rows: [HabitRecord.ID: HabitRow] = [:]

    init() {
        super.init(card: CardView(title: "Habits", systemImage: "checkmark.circle.fill", iconTint: UIColor.accentGreen, accessory: .navigates), interactiveContent: true)

        heroLabel.setContentHuggingPriority(.required, for: .horizontal)
        captionLabel.font = UIFont.label
        captionLabel.textColor = UIColor.textSecondary
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 2

        let hero = UIStackView(arrangedSubviews: [heroLabel, captionLabel])
        hero.axis = .horizontal
        hero.alignment = .firstBaseline
        hero.spacing = Metrics.spaceTight

        rowsStack.axis = .vertical
        rowsStack.spacing = Metrics.spaceTight

        card.contentStack.addArrangedSubview(hero)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: hero)
        card.contentStack.addArrangedSubview(rowsStack)
        render(HomeSnapshot.placeholder.habits)
    }

    /// Rows keep their views between renders, so a toggle's spring is not cut short by the
    /// re-render its own write triggers; the stack is rebuilt only when the Habits change.
    func render(_ model: HomeSnapshot.Habits) {
        heroLabel.setValue(model.hero ?? "—", isEmpty: model.hero == nil)
        captionLabel.text = model.caption
        accessibilityLabel = "Habits, \(model.hero ?? "—") \(model.caption)"

        let ids = model.rows.map(\.id)
        if rowsStack.arrangedSubviews.compactMap({ ($0 as? HabitRow)?.id }) != ids {
            for view in rowsStack.arrangedSubviews {
                view.removeFromSuperview()
            }
            rows = rows.filter { ids.contains($0.key) }
            for id in ids {
                rowsStack.addArrangedSubview(rows[id] ?? makeRow(id))
            }
        }
        for row in model.rows {
            rows[row.id]?.configure(with: row)
        }
        rowsStack.isHidden = ids.isEmpty
    }

    private func makeRow(_ id: HabitRecord.ID) -> HabitRow {
        let row = HabitRow(id: id)
        row.onToggle = { [weak self] on in self?.onToggle?(id, on) }
        row.onAmountTap = { [weak self] in self?.onAmountTap?(id) }
        rows[id] = row
        return row
    }
}

/// One Habit as a `MetricRow`: emoji, name, and today's control, the same
/// `HabitCheckInControls` the Habits tab's card has.
private final class HabitRow: UIView {

    let id: HabitRecord.ID
    var onToggle: ((Bool) -> Void)?
    var onAmountTap: (() -> Void)?

    private let controls = HabitCheckInControls()
    private let row: MetricRowView

    init(id: HabitRecord.ID) {
        self.id = id
        row = MetricRowView(trailing: controls)
        super.init(frame: .zero)

        controls.onToggle = { [weak self] on in self?.onToggle?(on) }
        controls.onAmountTap = { [weak self] in self?.onAmountTap?() }

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

    func configure(with model: HabitCardModel) {
        row.configure(leading: .emoji(model.emoji), title: model.name)
        controls.configure(with: model)
    }
}
