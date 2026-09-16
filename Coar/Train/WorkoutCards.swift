import UIKit

/// A Workout on the Train root's Recent workouts section or a Day's list (DESIGN.md §7
/// `Card` with a trailing `→`): its title (the Plan's name, or "Empty workout"), when it
/// ran, and what it held. Tapping opens the Workout.
final class WorkoutCardControl: UIControl {

    private let card: CardView

    init(workout: WorkoutRecord) {
        card = CardView(title: workout.title, systemImage: "dumbbell.fill", iconTint: workout.isActive ? UIColor.accentGreen : UIColor.textPrimary, accessory: .navigates)
        super.init(frame: .zero)

        let when = UILabel()
        when.text = Self.whenText(workout)
        when.font = UIFont.metricNumber
        when.textColor = workout.isActive ? UIColor.accentGreen : UIColor.textPrimary
        when.adjustsFontForContentSizeCategory = true

        let caption = UILabel()
        caption.text = TrainText.caption(of: workout)
        caption.font = UIFont.label
        caption.textColor = UIColor.textSecondary
        caption.adjustsFontForContentSizeCategory = true
        caption.numberOfLines = 2

        card.contentStack.addArrangedSubview(when)
        card.contentStack.addArrangedSubview(caption)
        card.isUserInteractionEnabled = false
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "\(workout.title), \(when.text ?? ""), \(caption.text ?? "")"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { card.alpha = isHighlighted ? 0.85 : 1 }
    }

    /// "6:12 PM · 50 min" once finished; "In progress · since 6:12 PM" while active.
    private static func whenText(_ workout: WorkoutRecord) -> String {
        guard let finishedAt = workout.finishedAt else {
            return "In progress · since \(TrainText.timeText(workout.startedAt))"
        }
        return "\(TrainText.timeText(workout.startedAt)) · \(TrainText.duration(from: workout.startedAt, to: finishedAt))"
    }
}
