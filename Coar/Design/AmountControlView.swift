import UIKit

/// `AmountControl` (DESIGN.md §7): the quantitative Habit's check-in control, a capsule
/// showing today's total. `—` on `fill` when nothing is logged (§1.5), the amount on `fill`
/// while the Period is short of its target, `accentGreen` with bloom once met (§1.3, §6).
/// Tapping reports through `onTap`; the owner opens the number sheet.
final class AmountControlView: UIControl {

    var onTap: (() -> Void)?

    private enum Size {
        static let minimumWidth: CGFloat = 52
        static let height: CGFloat = 32
        static let padding: CGFloat = 12
    }

    private let bloomView = BloomView(accent: UIColor.accentGreen, shadowRadius: 5, cornerRadius: Size.height / 2)
    private let capsule = UIView()
    private let label = UILabel()
    private var amount: Double = 0
    private var isMet = false
    private var hasRendered = false

    init() {
        super.init(frame: .zero)

        bloomView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bloomView)

        capsule.layer.cornerRadius = Size.height / 2
        capsule.isUserInteractionEnabled = false
        capsule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(capsule)

        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .monospacedDigitSystemFont(ofSize: 15, weight: .semibold))
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        capsule.addSubview(label)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: Size.minimumWidth),
            heightAnchor.constraint(equalToConstant: Size.height),
            capsule.topAnchor.constraint(equalTo: topAnchor),
            capsule.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsule.trailingAnchor.constraint(equalTo: trailingAnchor),
            capsule.bottomAnchor.constraint(equalTo: bottomAnchor),
            bloomView.topAnchor.constraint(equalTo: topAnchor),
            bloomView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bloomView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bloomView.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: capsule.leadingAnchor, constant: Size.padding),
            label.trailingAnchor.constraint(equalTo: capsule.trailingAnchor, constant: -Size.padding),
        ])

        addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)

        isAccessibilityElement = true
        accessibilityTraits = .button
        render(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setAmount(_ amount: Double, isMet: Bool, animated: Bool) {
        let changed = amount != self.amount || isMet != self.isMet
        self.amount = amount
        self.isMet = isMet
        guard changed, hasRendered, animated, window != nil else { return render(animated: false) }
        capsule.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(springDuration: 0.4, bounce: 0.15) {
            self.render(animated: true)
            self.capsule.transform = .identity
        }
    }

    override var isHighlighted: Bool {
        didSet { capsule.alpha = isHighlighted ? 0.7 : 1 }
    }

    private func render(animated: Bool) {
        hasRendered = true
        let logged = amount > 0
        capsule.backgroundColor = isMet ? UIColor.accentGreen : UIColor.fill
        label.text = logged ? HabitAmount.text(amount) : "—"
        label.textColor = isMet ? .white : logged ? UIColor.textPrimary : UIColor.textSecondary
        accessibilityValue = logged ? "\(HabitAmount.text(amount)) today" + (isMet ? ", done" : "") : "Nothing logged"
        bloomView.setVisible(isMet, animated: animated)
    }
}
