import UIKit

/// The capsule shared by `CheckToggle` and `AmountControl` (DESIGN.md §7): `fill` while
/// muted, `accentGreen` with bloom while alive (§1.3, §6), the §9 spring on a state change,
/// dimmed while pressed. Subclasses put their content in `capsule`, draw it in
/// `render(animated:)`, and report a state change through `stateChanged(animated:)`.
class CapsuleControlView: UIControl {

    static let height: CGFloat = 32

    let capsule = UIView()
    private let bloomView = BloomView(accent: UIColor.accentGreen, shadowRadius: 5, cornerRadius: CapsuleControlView.height / 2)
    /// False until the first render, so a recycled cell never springs from another Habit's state.
    private var hasRendered = false

    init() {
        super.init(frame: .zero)

        bloomView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bloomView)

        capsule.layer.cornerRadius = Self.height / 2
        capsule.isUserInteractionEnabled = false
        capsule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(capsule)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            capsule.topAnchor.constraint(equalTo: topAnchor),
            capsule.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsule.trailingAnchor.constraint(equalTo: trailingAnchor),
            capsule.bottomAnchor.constraint(equalTo: bottomAnchor),
            bloomView.topAnchor.constraint(equalTo: topAnchor),
            bloomView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bloomView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bloomView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { capsule.alpha = isHighlighted ? 0.7 : 1 }
    }

    /// Draws the current state; `animated` when the change should fade the bloom in.
    func render(animated: Bool) {}

    /// The capsule's fill and bloom for the alive (met, done) or muted state.
    func setAlive(_ alive: Bool, animated: Bool) {
        capsule.backgroundColor = alive ? UIColor.accentGreen : UIColor.fill
        bloomView.setVisible(alive, animated: animated)
    }

    /// Re-renders after a state change: with the §9 spring when it happens on screen after a
    /// first render, plainly otherwise.
    func stateChanged(animated: Bool) {
        let spring = animated && hasRendered && window != nil
        hasRendered = true
        guard spring else { return render(animated: false) }
        capsule.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(springDuration: 0.4, bounce: 0.15) {
            self.render(animated: true)
            self.capsule.transform = .identity
        }
    }

    /// Forgets that anything was shown, so the next change does not spring from a recycled
    /// cell's previous Habit.
    func reset() {
        hasRendered = false
    }
}
