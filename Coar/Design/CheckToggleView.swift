import UIKit

/// `CheckToggle` (DESIGN.md §7): the two-state `— / ✓` capsule for yes/no Check-ins. Off is
/// muted `fill`; on is `accentGreen` with bloom (§1.3, §6). There is no recorded miss: an
/// empty Day is the miss. Tapping flips the state with the §9 spring and reports the new
/// value; the owner writes it and re-renders, so a failed write snaps the control back.
final class CheckToggleView: UIControl {

    private(set) var isOn = false
    var onToggle: ((Bool) -> Void)?

    private enum Size {
        static let width: CGFloat = 52
        static let height: CGFloat = 32
    }

    private let bloomView = BloomView(accent: UIColor.accentGreen, shadowRadius: 5, cornerRadius: Size.height / 2)
    private let capsule = UIView()
    private let symbol = UIImageView()

    init() {
        super.init(frame: .zero)

        bloomView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bloomView)

        capsule.layer.cornerRadius = Size.height / 2
        capsule.isUserInteractionEnabled = false
        capsule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(capsule)

        symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        symbol.contentMode = .center
        symbol.translatesAutoresizingMaskIntoConstraints = false
        capsule.addSubview(symbol)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Size.width),
            heightAnchor.constraint(equalToConstant: Size.height),
            capsule.topAnchor.constraint(equalTo: topAnchor),
            capsule.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsule.trailingAnchor.constraint(equalTo: trailingAnchor),
            capsule.bottomAnchor.constraint(equalTo: bottomAnchor),
            bloomView.topAnchor.constraint(equalTo: topAnchor),
            bloomView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bloomView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bloomView.bottomAnchor.constraint(equalTo: bottomAnchor),
            symbol.centerXAnchor.constraint(equalTo: capsule.centerXAnchor),
            symbol.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
        ])

        addAction(UIAction { [weak self] _ in self?.tapped() }, for: .touchUpInside)

        isAccessibilityElement = true
        accessibilityTraits = .button
        render(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setOn(_ on: Bool, animated: Bool) {
        guard on != isOn else { return }
        isOn = on
        guard animated, window != nil else { return render(animated: false) }
        capsule.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(springDuration: 0.4, bounce: 0.15) {
            self.render(animated: true)
            self.capsule.transform = .identity
        }
    }

    override var isHighlighted: Bool {
        didSet { capsule.alpha = isHighlighted ? 0.7 : 1 }
    }

    private func tapped() {
        setOn(!isOn, animated: true)
        onToggle?(isOn)
    }

    private func render(animated: Bool) {
        capsule.backgroundColor = isOn ? UIColor.accentGreen : UIColor.fill
        symbol.image = UIImage(systemName: isOn ? "checkmark" : "minus")
        symbol.tintColor = isOn ? .white : UIColor.textSecondary
        accessibilityValue = isOn ? "Done" : "Not done"
        bloomView.setVisible(isOn, animated: animated)
    }
}
