import UIKit

/// Home's habits card (DESIGN.md §11): a full-width `Card` titled Habits with how many are
/// done ("3 of 7 done") in its header, then a `MetricRow` per check-in Habit still to do
/// today, its check-in control inline: a `CheckToggle` for a yes/no Habit and an
/// `AmountControl` for a quantitative or checklist one, exactly as on the Habits tab. Done
/// Habits (today, or this week) are hidden behind a Show done button; with nothing left a
/// line says so. Tracked Habits are not on Home. Tapping the card opens the Habits tab; the
/// controls report through `onToggle` and `onAmountTap`, and the owner writes and
/// re-renders. With no check-in Habit the header says why and the card stays (§1.5).
final class HabitsCardControl: CardControl {

    var onToggle: ((HabitRecord.ID, Bool) -> Void)?
    var onAmountTap: ((HabitRecord.ID) -> Void)?

    private let summaryLabel = UILabel()
    private let rowsStack = UIStackView()
    private let allDoneLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private var rows: [HabitRecord.ID: HabitRow] = [:]
    private var model = HomeSnapshot.placeholder.habits
    /// Whether done Habits are listed; kept while the app runs.
    private var showsDone = false

    init() {
        summaryLabel.font = UIFont.label
        summaryLabel.textColor = UIColor.textSecondary
        summaryLabel.adjustsFontForContentSizeCategory = true
        super.init(card: CardView(title: "Habits", systemImage: "checkmark.circle.fill", iconTint: UIColor.accentGreen, detail: summaryLabel, accessory: .navigates), interactiveContent: true)

        rowsStack.axis = .vertical
        rowsStack.spacing = Metrics.spaceTight / 2

        allDoneLabel.text = "All done for today"
        allDoneLabel.font = UIFont.bodyText
        allDoneLabel.textColor = UIColor.textSecondary
        allDoneLabel.adjustsFontForContentSizeCategory = true

        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = UIColor.textSecondary
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 4
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.label
            return attributes
        }
        doneButton.configuration = configuration
        doneButton.addAction(UIAction { [weak self] _ in self?.toggleShowsDone() }, for: .touchUpInside)

        card.contentStack.addArrangedSubview(rowsStack)
        card.contentStack.addArrangedSubview(allDoneLabel)
        card.contentStack.addArrangedSubview(doneButton)
        render(model)
    }

    /// Rows keep their views between renders, so a toggle's spring is not cut short by the
    /// re-render its own write triggers. A row whose Habit becomes done leaves once its
    /// control has settled; rows are moved and hidden in place, never removed, for the same
    /// reason.
    func render(_ model: HomeSnapshot.Habits) {
        let newlyDone = Set(model.done.map(\.id)).subtracting(self.model.done.map(\.id))
        let settles = !newlyDone.isEmpty && newlyDone.isSubset(of: self.model.toDo.map(\.id))
        self.model = model
        summaryLabel.text = model.summary
        accessibilityLabel = "Habits, \(model.summary)"

        let all = model.toDo + model.done
        let ids = Set(all.map(\.id))
        rows = rows.filter { id, row in
            if !ids.contains(id) { row.removeFromSuperview() }
            return ids.contains(id)
        }
        for habit in all {
            (rows[habit.id] ?? makeRow(habit.id)).configure(with: habit)
        }
        layout(animated: window != nil, delay: settles ? 0.35 : 0)
    }

    private func toggleShowsDone() {
        showsDone.toggle()
        layout(animated: window != nil, delay: 0)
    }

    /// Orders the rows (to do, then done), hides the done ones unless asked for, and sets
    /// the footer; animated, the card grows or shrinks with them.
    private func layout(animated: Bool, delay: TimeInterval) {
        let order = (model.toDo + model.done).compactMap { rows[$0.id] }
        let visible = Set(model.toDo.map(\.id)).union(showsDone ? model.done.map(\.id) : [])
        let isAllDone = model.toDo.isEmpty && !model.done.isEmpty && !showsDone

        var title = AttributedString(showsDone ? "Hide done" : "Show \(model.done.count) done")
        title.font = UIFont.label
        doneButton.configuration?.attributedTitle = title
        doneButton.configuration?.image = UIImage(systemName: showsDone ? "chevron.up" : "chevron.down")

        let apply = { [self] in
            for (index, row) in order.enumerated() where rowsStack.arrangedSubviews.firstIndex(of: row) != index {
                rowsStack.insertArrangedSubview(row, at: index)
            }
            for row in order {
                let hidden = !visible.contains(row.id)
                // Only on a change: a stack view's hidden count drifts when set repeatedly.
                if row.isHidden != hidden { row.isHidden = hidden }
                row.alpha = hidden ? 0 : 1
            }
            if rowsStack.isHidden != visible.isEmpty { rowsStack.isHidden = visible.isEmpty }
            if allDoneLabel.isHidden == isAllDone { allDoneLabel.isHidden = !isAllDone }
            if doneButton.isHidden != model.done.isEmpty { doneButton.isHidden = model.done.isEmpty }
        }
        guard animated, !UIAccessibility.isReduceMotionEnabled else { return apply() }
        let container = enclosingScrollView ?? self
        UIView.animate(springDuration: 0.5, bounce: 0, delay: delay, options: [.allowUserInteraction, .beginFromCurrentState]) {
            apply()
            container.layoutIfNeeded()
        }
    }

    /// The screen's scroll view, so cards below slide with this one as it changes height.
    private var enclosingScrollView: UIScrollView? {
        sequence(first: superview, next: { $0?.superview }).lazy.compactMap { $0 as? UIScrollView }.first
    }

    private func makeRow(_ id: HabitRecord.ID) -> HabitRow {
        let row = HabitRow(id: id)
        row.onToggle = { [weak self] on in self?.onToggle?(id, on) }
        row.onAmountTap = { [weak self] in self?.onAmountTap?(id) }
        row.isHidden = true
        rows[id] = row
        rowsStack.addArrangedSubview(row)
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
