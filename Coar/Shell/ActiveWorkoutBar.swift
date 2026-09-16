import UIKit

/// The Active Workout in the bottom accessory slot (DESIGN.md §2, §8 "in-progress"): the
/// Workout's title, how long it has run, and a chevron; tapping returns to the logger. The
/// tab bar controller shows it whenever a Workout is active and the logger is not on
/// screen. Liquid Glass comes from the `UITabAccessory` itself; this view stays clear.
final class ActiveWorkoutBar: UIControl {

    var onTap: (() -> Void)?

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private var startedAt = Date()
    private var ticker: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)

        let icon = UIImageView(image: UIImage(systemName: "dumbbell.fill"))
        icon.tintColor = UIColor.accentGreen
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .headline)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = UIFont.cardTitle
        titleLabel.textColor = UIColor.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true

        detailLabel.font = UIFont.label
        detailLabel.textColor = UIColor.textSecondary
        detailLabel.adjustsFontForContentSizeCategory = true

        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 1

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor.textTertiary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [icon, text, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metrics.spaceTight
        row.isUserInteractionEnabled = false
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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        ticker?.invalidate()
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    func configure(with workout: WorkoutRecord) {
        titleLabel.text = workout.title
        startedAt = workout.startedAt
        tick()
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    /// Stops the minute ticker while the bar is off screen.
    func stop() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        detailLabel.text = "Active · \(TrainText.duration(from: startedAt, to: Date()))"
        accessibilityLabel = "\(titleLabel.text ?? ""), \(detailLabel.text ?? ""). Return to workout"
    }
}
