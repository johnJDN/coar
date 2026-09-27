import UIKit

/// Today's check-in control for one Habit (DESIGN.md §7): a `CheckToggle` for a yes/no
/// Habit, an `AmountControl` for a quantitative one or, as "2/5", a checklist, or a tracked
/// Habit's value. The Habits tab's cards and Home's habits card share it, so a check-in looks and behaves the same from
/// both. The toggle reports through `onToggle`, the amount capsule through `onAmountTap`.
final class HabitCheckInControls: UIView {

    var onToggle: ((Bool) -> Void)?
    var onAmountTap: (() -> Void)?

    private let toggle = CheckToggleView()
    private let amountControl = AmountControlView()
    /// Only the shown control is pinned; the other is removed. Hiding one inside a stack
    /// view breaks once a recycled cell swaps kinds during an animated update (the stack's
    /// hidden count drifts and the view collapses to zero width).
    private var shown: UIView?

    init() {
        super.init(frame: .zero)
        toggle.onToggle = { [weak self] on in self?.onToggle?(on) }
        amountControl.onTap = { [weak self] in self?.onAmountTap?() }

        toggle.translatesAutoresizingMaskIntoConstraints = false
        amountControl.translatesAutoresizingMaskIntoConstraints = false
        show(toggle)
        setContentHuggingPriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(with model: HabitCardModel) {
        show(model.kind == .yesNo ? toggle : amountControl)
        switch model.kind {
        case .yesNo:
            toggle.setOn(model.isDoneToday, animated: false)
            toggle.accessibilityLabel = "Check in \(model.name)"
        case .quantitative:
            amountControl.setAmount(model.todayAmount, isMet: model.isDoneToday, animated: true)
            amountControl.accessibilityLabel = "Check in \(model.name)"
        case .checklist:
            amountControl.setCount(model.tickedItemCount, of: model.itemCount, isMet: model.isDoneToday, animated: true)
            amountControl.accessibilityLabel = "Check in \(model.name)"
        case .tracked:
            amountControl.setText(model.trackedText ?? "—", isMet: model.isDoneToday, animated: true)
            amountControl.accessibilityLabel = model.name
        }
        // A tracked Habit is read, not checked in: its capsule only shows the value.
        amountControl.isUserInteractionEnabled = model.kind != .tracked
    }

    private func show(_ control: UIView) {
        guard control !== shown else { return }
        shown?.removeFromSuperview()
        shown = control
        addSubview(control)
        NSLayoutConstraint.activate([
            control.topAnchor.constraint(equalTo: topAnchor),
            control.leadingAnchor.constraint(equalTo: leadingAnchor),
            control.trailingAnchor.constraint(equalTo: trailingAnchor),
            control.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    /// Forgets the shown state, so a recycled cell never springs from another Habit's.
    func reset() {
        toggle.reset()
        amountControl.reset()
    }
}
