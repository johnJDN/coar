import UIKit

/// Home's habits card (DESIGN.md §11): a full-width `Card` with how many Habits are done
/// today as the hero, then a `MetricRow` per active Habit with its check-in control inline,
/// a `CheckToggle` for a yes/no Habit and an `AmountControl` for a quantitative one, exactly
/// as on the Habits tab. Tapping the card opens the Habits tab; the controls report through
/// `onToggle` and `onAmountTap`, and the owner writes and re-renders. With no Habit the hero
/// is `—` and the card stays (§1.5).
final class HabitsCardControl: UIControl {

    var onToggle: ((HabitRecord.ID, Bool) -> Void)?
    var onAmountTap: ((HabitRecord.ID) -> Void)?

    private let card = CardView(title: "Habits", systemImage: "checkmark.circle.fill", iconTint: UIColor.accentGreen, accessory: .navigates)
    private let heroLabel = HeroNumberLabel()
    private let captionLabel = UILabel()
    private let rowsStack = UIStackView()
    private var rows: [HabitRecord.ID: HabitRow] = [:]

    init() {
        super.init(frame: .zero)

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
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        accessibilityTraits = .button
        render(HomeSnapshot.empty.habits)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

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

    override var isHighlighted: Bool {
        didSet { card.alpha = isHighlighted ? 0.85 : 1 }
    }
}

/// One Habit as a `MetricRow`: emoji, name, and today's control, configured as the Habits
/// tab's card header is.
private final class HabitRow: UIView {

    let id: HabitRecord.ID
    var onToggle: ((Bool) -> Void)?
    var onAmountTap: (() -> Void)?

    private let toggle = CheckToggleView()
    private let amountControl = AmountControlView()
    private let row: MetricRowView

    init(id: HabitRecord.ID) {
        self.id = id
        let controls = UIStackView(arrangedSubviews: [toggle, amountControl])
        controls.axis = .horizontal
        row = MetricRowView(trailing: controls)
        super.init(frame: .zero)

        toggle.onToggle = { [weak self] on in self?.onToggle?(on) }
        amountControl.onTap = { [weak self] in self?.onAmountTap?() }

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
    }
}
