import UIKit

extension UIScrollView {
    /// Keeps the scroll view full height and lifts its content above the keyboard with a
    /// bottom inset. Pinning the scroll view to the keyboard layout guide instead shrinks it
    /// with the keyboard of the screen it slides back over (a picker's filter field): for
    /// the length of the pop, everything below that keyboard's top draws blank.
    func insetsContentAboveKeyboard(in view: UIView) {
        let tracker = KeyboardOverlapView(scrollView: self)
        view.addSubview(tracker)
        NSLayoutConstraint.activate([
            tracker.topAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            tracker.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tracker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tracker.widthAnchor.constraint(equalToConstant: 0),
        ])
    }
}

/// An invisible view spanning the keyboard's overlap with the screen. With no keyboard the
/// guide sits on the bottom safe area, which the scroll view already insets for, so only
/// the height past it becomes extra inset.
private final class KeyboardOverlapView: UIView {

    private weak var scrollView: UIScrollView?

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isHidden = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let scrollView, let superview else { return }
        let inset = max(0, bounds.height - superview.safeAreaInsets.bottom)
        guard scrollView.contentInset.bottom != inset else { return }
        scrollView.contentInset.bottom = inset
        scrollView.verticalScrollIndicatorInsets.bottom = inset
    }
}
