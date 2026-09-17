import UIKit

/// A Sleep or Steps square on Home (DESIGN.md §11): a `Card` with the metric's icon and
/// title, its hero value for the current Day, and a caption; `No data` in the value slot
/// when Apple Health has none (§1.5). Tapping the square opens the 30-day detail; while the
/// Apple Health prompt has never been shown, tapping the empty value slot shows it instead
/// (spec story 80). Wrapped as a control the way the Train root's cards are.
final class HealthSquareControl: UIControl {

    struct Model: Equatable {
        /// The value for the current Day, in the metric's unit; nil when Health has none.
        var value: Double?
        /// Whether tapping the empty value slot can show the Apple Health prompt.
        var canConnect: Bool
    }

    let metric: HealthMetric
    /// Runs when the empty value slot is tapped while `canConnect`.
    var onConnect: (() -> Void)?

    private let card: CardView
    private let heroLabel = HeroNumberLabel()
    private let captionLabel = UILabel()

    init(metric: HealthMetric) {
        self.metric = metric
        card = CardView(title: metric.title, systemImage: metric.systemImage, iconTint: metric.accent, accessory: .navigates)
        super.init(frame: .zero)

        heroLabel.adjustsFontSizeToFitWidth = true
        heroLabel.minimumScaleFactor = 0.5
        heroLabel.onTapEmpty = { [weak self] in self?.onConnect?() }

        captionLabel.font = UIFont.label
        captionLabel.textColor = UIColor.textSecondary
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 2

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        card.contentStack.addArrangedSubview(spacer)
        card.contentStack.addArrangedSubview(heroLabel)
        card.contentStack.addArrangedSubview(captionLabel)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalTo: widthAnchor),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        render(Model(value: nil, canConnect: false))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func render(_ model: Model) {
        let valueText = model.value.map(metric.text)
        heroLabel.setValue(valueText ?? "No data", isEmpty: valueText == nil)
        let canConnect = model.value == nil && model.canConnect
        captionLabel.text = canConnect ? "Tap to connect Apple Health" : metric.periodCaption

        accessibilityLabel = "\(metric.title), \(valueText ?? "No data"), \(captionLabel.text ?? "")"
        accessibilityCustomActions = canConnect
            ? [UIAccessibilityCustomAction(name: "Connect Apple Health") { [weak self] _ in self?.onConnect?(); return true }]
            : []
    }

    override var isHighlighted: Bool {
        didSet { card.alpha = isHighlighted ? 0.85 : 1 }
    }
}
