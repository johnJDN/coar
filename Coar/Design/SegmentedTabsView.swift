import UIKit

/// `SegmentedTabs` (DESIGN.md §7): text tabs with an underline indicator at the top of a
/// sheet (Foods / Meals). The selected title is `textPrimary`, the rest `textSecondary`; the
/// indicator springs between them (§9). Reports a selection through `onSelect`.
final class SegmentedTabsView: UIView {

    var onSelect: ((Int) -> Void)?

    private(set) var selectedIndex = 0
    private let buttons: [UIButton]
    private let indicator = UIView()
    private var indicatorConstraints: [NSLayoutConstraint] = []

    init(titles: [String]) {
        buttons = titles.map { title in
            var configuration = UIButton.Configuration.plain()
            configuration.title = title
            configuration.titleTextAttributesTransformer = .cardTitle
            configuration.contentInsets = NSDirectionalEdgeInsets(top: Metrics.spaceTight, leading: 0, bottom: Metrics.spaceTight + 6, trailing: 0)
            return UIButton(configuration: configuration)
        }
        super.init(frame: .zero)

        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        indicator.backgroundColor = UIColor.textPrimary
        indicator.layer.cornerRadius = 1.5
        indicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indicator)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            indicator.bottomAnchor.constraint(equalTo: bottomAnchor),
            indicator.heightAnchor.constraint(equalToConstant: 3),
        ])

        for (index, button) in buttons.enumerated() {
            button.addAction(UIAction { [weak self] _ in
                self?.select(index, animated: true)
                self?.onSelect?(index)
            }, for: .touchUpInside)
        }
        select(0, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func select(_ index: Int, animated: Bool) {
        selectedIndex = index
        for (position, button) in buttons.enumerated() {
            button.configuration?.baseForegroundColor = position == index ? UIColor.textPrimary : UIColor.textSecondary
            button.accessibilityTraits = position == index ? [.button, .selected] : .button
        }
        NSLayoutConstraint.deactivate(indicatorConstraints)
        let selected = buttons[index]
        indicatorConstraints = [
            indicator.centerXAnchor.constraint(equalTo: selected.centerXAnchor),
            indicator.widthAnchor.constraint(equalTo: selected.widthAnchor, multiplier: 0.5),
        ]
        NSLayoutConstraint.activate(indicatorConstraints)
        guard animated, window != nil else { return layoutIfNeeded() }
        UIView.animate(springDuration: 0.4, bounce: 0.15) { self.layoutIfNeeded() }
    }
}
