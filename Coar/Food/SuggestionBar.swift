import UIKit

/// The user's own foods offered above the keyboard while a Describe line is typed
/// (`.scratch/describe-qol/`): a row of glass capsules, each the name over its default
/// serving and calories ("Pho / bowl · 450 cal"). Tapping one fills the line from Foods at
/// once, with no model. Shown as the line field's input accessory only while there is
/// something to offer.
final class SuggestionBar: UIView {

    var onPick: ((FoodLibrary.Suggestion) -> Void)?

    private let scroll = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: frame.width, height: 56))
        autoresizingMask = .flexibleWidth
        backgroundColor = .clear

        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        stack.axis = .horizontal
        stack.spacing = Metrics.spaceTight
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: Metrics.spaceTight),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -Metrics.spaceTight),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 56)
    }

    func show(_ suggestions: [FoodLibrary.Suggestion]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for suggestion in suggestions {
            var configuration = UIButton.Configuration.glass()
            configuration.title = suggestion.name
            configuration.subtitle = suggestion.detail
            configuration.titleAlignment = .leading
            configuration.cornerStyle = .capsule
            configuration.baseForegroundColor = UIColor.textPrimary
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14)
            configuration.titleTextAttributesTransformer = .cardTitle
            configuration.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.label
                attributes.foregroundColor = UIColor.textSecondary
                return attributes
            }
            let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in self?.onPick?(suggestion) })
            button.accessibilityLabel = "\(suggestion.name), your food, \(suggestion.detail)"
            stack.addArrangedSubview(button)
        }
        scroll.contentOffset = .zero
    }
}
