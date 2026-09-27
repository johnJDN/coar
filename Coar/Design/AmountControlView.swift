import UIKit

/// `AmountControl` (DESIGN.md §7): the quantitative Habit's check-in control, a capsule
/// showing today's total. `—` on `fill` when nothing has been entered (§1.5), the amount on
/// `fill` while the Period is short of its target, `accentGreen` with bloom once met (§1.3,
/// §6). Tapping reports through `onTap`; the owner opens the number sheet.
final class AmountControlView: CapsuleControlView {

    var onTap: (() -> Void)?

    private static let minimumWidth: CGFloat = 52
    private static let padding: CGFloat = 12

    private let label = UILabel()
    private var amount: Double = 0
    /// A checklist's number of Items: the capsule then reads "2/5" rather than an amount.
    private var total: Int?
    private var isMet = false

    override init() {
        super.init()

        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .monospacedDigitSystemFont(ofSize: 15, weight: .semibold))
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        // Hug the total so a row gives spare width to the Habit's name, never the capsule.
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        capsule.addSubview(label)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumWidth),
            label.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: capsule.leadingAnchor, constant: Self.padding),
            label.trailingAnchor.constraint(equalTo: capsule.trailingAnchor, constant: -Self.padding),
        ])

        addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
        stateChanged(animated: false)
    }

    func setAmount(_ amount: Double, isMet: Bool, animated: Bool) {
        let changed = amount != self.amount || isMet != self.isMet || total != nil
        self.amount = amount
        self.total = nil
        self.isMet = isMet
        stateChanged(animated: animated && changed)
    }

    /// A checklist: `ticked` of `total` Items, as "2/5".
    func setCount(_ ticked: Int, of total: Int, isMet: Bool, animated: Bool) {
        let changed = Double(ticked) != amount || isMet != self.isMet || total != self.total
        amount = Double(ticked)
        self.total = total
        self.isMet = isMet
        stateChanged(animated: animated && changed)
    }

    override func render(animated: Bool) {
        if let total {
            let ticked = Int(amount)
            label.text = "\(ticked)/\(total)"
            label.textColor = isMet ? .white : ticked > 0 ? UIColor.textPrimary : UIColor.textSecondary
            accessibilityValue = "\(ticked) of \(total) ticked" + (isMet ? ", done" : "")
            setAlive(isMet, animated: animated)
            return
        }
        let entered = amount > 0
        label.text = entered ? HabitAmount.text(amount) : "—"
        label.textColor = isMet ? .white : entered ? UIColor.textPrimary : UIColor.textSecondary
        accessibilityValue = entered ? "\(HabitAmount.text(amount)) today" + (isMet ? ", done" : "") : "Nothing today"
        setAlive(isMet, animated: animated)
    }
}
