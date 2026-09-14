import UIKit

/// Bloom (DESIGN.md §6): the accent-coloured second shadow under a filled dot, active point,
/// or toggle. Sits beneath the filled shape with the same frame and corner radius, and
/// appears with a `bloomFade` rather than popping (§9). Light mode lowers the opacity.
final class BloomView: UIView {

    private let accent: UIColor

    /// The corner radius of the shape above; `nil` keeps it circular.
    var cornerRadius: CGFloat? {
        didSet { setNeedsLayout() }
    }

    init(accent: UIColor, shadowRadius: CGFloat, cornerRadius: CGFloat? = nil) {
        self.accent = accent
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        backgroundColor = accent
        layer.shadowOffset = .zero
        layer.shadowRadius = shadowRadius
        alpha = 0
        isUserInteractionEnabled = false
        applyShadow()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in self.applyShadow() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = cornerRadius ?? bounds.width / 2
        layer.cornerRadius = radius
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
    }

    /// Shows or hides the bloom; animated, it fades over `bloomFade`.
    func setVisible(_ visible: Bool, animated: Bool) {
        let target: CGFloat = visible ? 1 : 0
        guard alpha != target else { return }
        guard animated, window != nil else { return alpha = target }
        UIView.animate(withDuration: Elevation.bloomFade) { self.alpha = target }
    }

    private func applyShadow() {
        layer.shadowColor = accent.resolvedColor(with: traitCollection).cgColor
        layer.shadowOpacity = Float(Elevation.bloomOpacity(for: traitCollection.userInterfaceStyle))
    }
}
