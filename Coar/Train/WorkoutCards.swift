import UIKit

/// A Workout on the Train root's Recent workouts section or a Day's list (DESIGN.md §7
/// `Card` with a trailing `→`): its title (the Plan's name, or "Empty workout"), when it
/// ran, and what it held. Tapping opens the Workout.
final class WorkoutCardControl: CardControl {

    init(workout: WorkoutRecord) {
        super.init(card: CardView(title: workout.title, systemImage: "dumbbell.fill", iconTint: workout.isActive ? UIColor.accentGreen : UIColor.textPrimary, accessory: .navigates))

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

        isAccessibilityElement = true
        accessibilityLabel = "\(workout.title), \(when.text ?? ""), \(caption.text ?? "")"
    }

    /// "6:12 PM · 50 min" once finished; "Active · since 6:12 PM" while it is the Active Workout.
    private static func whenText(_ workout: WorkoutRecord) -> String {
        guard let finishedAt = workout.finishedAt else {
            return "Active · since \(TrainText.timeText(workout.startedAt))"
        }
        return "\(TrainText.timeText(workout.startedAt)) · \(TrainText.duration(from: workout.startedAt, to: finishedAt))"
    }
}
