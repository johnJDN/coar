import UIKit

/// `CheckToggle` (DESIGN.md §7): the two-state `— / ✓` capsule for yes/no Check-ins. Off is
/// muted `fill`; on is `accentGreen` with bloom (§1.3, §6). There is no recorded miss: an
/// empty Day is the miss. Tapping flips the state with the §9 spring and reports the new
/// value; the owner writes it and re-renders, so a failed write snaps the control back.
final class CheckToggleView: CapsuleControlView {

    private(set) var isOn = false
    var onToggle: ((Bool) -> Void)?

    private static let width: CGFloat = 52

    private let symbol = UIImageView()

    override init() {
        super.init()

        symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        symbol.contentMode = .center
        symbol.translatesAutoresizingMaskIntoConstraints = false
        capsule.addSubview(symbol)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.width),
            symbol.centerXAnchor.constraint(equalTo: capsule.centerXAnchor),
            symbol.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
        ])

        addAction(UIAction { [weak self] _ in self?.tapped() }, for: .touchUpInside)
        stateChanged(animated: false)
    }

    func setOn(_ on: Bool, animated: Bool) {
        guard on != isOn else { return }
        isOn = on
        stateChanged(animated: animated)
    }

    private func tapped() {
        setOn(!isOn, animated: true)
        onToggle?(isOn)
    }

    override func render(animated: Bool) {
        symbol.image = UIImage(systemName: isOn ? "checkmark" : "minus")
        symbol.tintColor = isOn ? .white : UIColor.textSecondary
        accessibilityValue = isOn ? "Done" : "Not done"
        setAlive(isOn, animated: animated)
    }
}
