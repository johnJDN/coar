import UIKit

/// The Workout in the bottom accessory slot (DESIGN.md §2, §8 "Rest timer / in-progress").
/// Away from the logger it is the Workout's title, how long it has run, and a chevron back
/// to the logger. While the rest timer runs it is the countdown as the hero with a dismiss
/// button, on every tab, logger included; a tap still returns to the logger. When the tab
/// bar minimises the accessory goes inline and only icon and title fit, so the detail line
/// hides. Liquid Glass comes from the `UITabAccessory` itself; this view stays clear.
final class ActiveWorkoutBar: UIControl {

    struct Model: Equatable {
        let title: String
        let startedAt: Date
        /// When the rest timer ends; nil while none runs.
        let restEndsAt: Date?
    }

    var onTap: (() -> Void)?
    var onDismissRest: (() -> Void)?

    private let icon = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let dismissButton = UIButton(configuration: .plain())
    private var model: Model?
    private var ticker: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)

        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .headline)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.adjustsFontForContentSizeCategory = true

        detailLabel.font = UIFont.label
        detailLabel.textColor = UIColor.textSecondary
        detailLabel.adjustsFontForContentSizeCategory = true

        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 1

        chevron.tintColor = UIColor.textTertiary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        dismissButton.configuration?.image = UIImage(systemName: "xmark.circle.fill")
        dismissButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .title3)
        dismissButton.configuration?.baseForegroundColor = UIColor.textSecondary
        dismissButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 0)
        dismissButton.accessibilityLabel = "Dismiss rest timer"
        dismissButton.setContentHuggingPriority(.required, for: .horizontal)
        dismissButton.addAction(UIAction { [weak self] _ in self?.onDismissRest?() }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [icon, text, chevron, dismissButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metrics.spaceTight
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.spaceTight),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.spaceInner),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.spaceInner),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Metrics.spaceTight),
        ])

        addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
        registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) { (self: Self, _) in
            self.applyEnvironment()
        }
        applyEnvironment()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        ticker?.invalidate()
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    /// The dismiss button keeps its own touches; everything else is the bar.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        return hit.isDescendant(of: dismissButton) && !dismissButton.isHidden ? hit : self
    }

    func configure(with model: Model) {
        let restarts = self.model?.restEndsAt != model.restEndsAt || ticker == nil
        self.model = model
        tick()
        guard restarts else { return }
        ticker?.invalidate()
        let ticker = Timer(timeInterval: model.restEndsAt == nil ? 60 : 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    /// Stops the ticker while the bar is off screen.
    func stop() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let model else { return }
        let now = Date()
        if let restEndsAt = model.restEndsAt {
            let remaining = max(0, Int(restEndsAt.timeIntervalSince(now).rounded(.up)))
            icon.image = UIImage(systemName: "timer")
            icon.tintColor = UIColor.accentGreen
            titleLabel.font = UIFont.cardTitleMonospaced
            titleLabel.textColor = UIColor.accentGreen
            titleLabel.text = TrainText.countdown(remaining)
            detailLabel.text = "Rest · \(model.title)"
            chevron.isHidden = true
            dismissButton.isHidden = false
            accessibilityLabel = "Rest, \(TrainText.count(remaining, "second")) left, \(model.title)"
            accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: "Dismiss rest timer") { [weak self] _ in
                    self?.onDismissRest?()
                    return true
                },
            ]
        } else {
            icon.image = UIImage(systemName: "dumbbell.fill")
            icon.tintColor = UIColor.accentGreen
            titleLabel.font = UIFont.cardTitle
            titleLabel.textColor = UIColor.textPrimary
            titleLabel.text = model.title
            detailLabel.text = "Active · \(TrainText.duration(from: model.startedAt, to: now))"
            chevron.isHidden = false
            dismissButton.isHidden = true
            accessibilityLabel = "\(model.title), \(detailLabel.text ?? ""). Return to workout"
            accessibilityCustomActions = nil
        }
    }

    /// Inline (the tab bar minimised) has room for the icon and title only.
    private func applyEnvironment() {
        detailLabel.isHidden = traitCollection.tabAccessoryEnvironment == .inline
    }
}
