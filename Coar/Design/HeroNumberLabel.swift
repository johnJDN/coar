import UIKit

/// The hero number of a card (DESIGN.md §5): the biggest, boldest thing on it. Changes
/// cross-dissolve (§9); the empty value (`—`) takes `textTertiary` (§5).
final class HeroNumberLabel: UILabel {

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = UIFont.heroNumber
        adjustsFontForContentSizeCategory = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Shows the value; on screen, a change cross-dissolves rather than pops.
    func setValue(_ text: String, isEmpty: Bool) {
        let apply = {
            self.text = text
            self.textColor = isEmpty ? UIColor.textTertiary : UIColor.textPrimary
        }
        guard self.text != text, window != nil else { return apply() }
        UIView.transition(with: self, duration: 0.25, options: .transitionCrossDissolve, animations: apply)
    }
}
