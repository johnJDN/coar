import UIKit

extension UIView {
    /// One pill of a `SetRow` (DESIGN.md §7): `fill` at `radiusInner` around a baseline row
    /// of views; empty when the caller draws its own content. Shared by the Planned Sets
    /// editor and the logger.
    static func pill(_ views: [UIView]) -> UIView {
        let pill = UIView()
        pill.backgroundColor = UIColor.fill
        pill.layer.cornerRadius = Metrics.radiusInner
        pill.layer.cornerCurve = .continuous
        guard !views.isEmpty else { return pill }
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: pill.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -10),
        ])
        return pill
    }
}
