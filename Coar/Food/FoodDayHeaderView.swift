import UIKit

/// The Food timeline's pinned header: the week strip over the macro summary row. The Food
/// screen owns the one strip and one summary and hands them to whichever header view the
/// timeline dequeues, so their state (selected Day, scroll position) survives reuse.
/// Opaque `background`, so hour rows scroll beneath it rather than through it.
final class FoodDayHeaderView: UICollectionReusableView {

    static let elementKind = "food-day-header"

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.background
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func hold(strip: UIView, summary: UIView) {
        guard strip.superview !== stack else { return }
        for view in [strip, summary] {
            view.removeFromSuperview()
            view.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(view)
        }
    }
}
