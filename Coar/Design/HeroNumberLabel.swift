import UIKit

/// The hero number of a card (DESIGN.md §5): the biggest, boldest thing on it. Changes
/// cross-dissolve (§9); the empty value (`—`, `No data`) takes `textTertiary` (§5). An empty
/// value the user can do something about (connect Apple Health) can be made tappable.
final class HeroNumberLabel: UILabel {

    /// Runs when the empty value is tapped. While set, an empty label is a tap target; a
    /// label showing a value, or with nothing to run, is inert.
    var onTapEmpty: (() -> Void)? {
        didSet { updateTapTarget() }
    }

    private(set) var isEmpty = false
    private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(tapped))

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = UIFont.heroNumber
        adjustsFontForContentSizeCategory = true
        // The tap ends the touch for the card beneath, so a control wrapping the card
        // does not also fire (a Home square opens its detail on every other tap).
        tap.cancelsTouchesInView = true
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Shows the value; on screen, a change cross-dissolves rather than pops.
    func setValue(_ text: String, isEmpty: Bool) {
        self.isEmpty = isEmpty
        updateTapTarget()
        let apply = {
            self.text = text
            self.textColor = isEmpty ? UIColor.textTertiary : UIColor.textPrimary
        }
        guard self.text != text, window != nil else { return apply() }
        UIView.transition(with: self, duration: 0.25, options: .transitionCrossDissolve, animations: apply)
    }

    private func updateTapTarget() {
        let tappable = isEmpty && onTapEmpty != nil
        isUserInteractionEnabled = tappable
        tap.isEnabled = tappable
        accessibilityTraits = tappable ? .button : .staticText
    }

    @objc private func tapped() {
        onTapEmpty?()
    }
}
