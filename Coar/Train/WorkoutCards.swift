import UIKit

/// A Workout on the Train root's Recent workouts section or a Day's list (DESIGN.md §7
/// `Card` with a trailing `→`): its title (the Plan's name, or "Empty workout"), when it
/// ran, and what it held. Tapping opens the Workout.
final class WorkoutCardControl: CardControl {

    init(workout: WorkoutRecord, distanceUnit: DistanceUnit = .miles) {
        let icon = workout.activity == nil ? "dumbbell.fill" : "figure.run"
        super.init(card: CardView(title: workout.title, systemImage: icon, iconTint: workout.isActive ? UIColor.accentGreen : UIColor.textPrimary, accessory: .navigates))

        let when = UILabel()
        when.text = Self.whenText(workout)
        when.font = UIFont.metricNumber
        when.textColor = workout.isActive ? UIColor.accentGreen : UIColor.textPrimary
        when.adjustsFontForContentSizeCategory = true

        let caption = UILabel()
        caption.text = TrainText.caption(of: workout, distanceUnit: distanceUnit)
        caption.font = UIFont.label
        caption.textColor = UIColor.textSecondary
        caption.adjustsFontForContentSizeCategory = true
        caption.numberOfLines = 2

        card.contentStack.addArrangedSubview(when)
        card.contentStack.addArrangedSubview(caption)

        isAccessibilityElement = true
        accessibilityLabel = "\(workout.title), \(when.text ?? ""), \(caption.text ?? "")"
    }

    private let effortLabel = UILabel()

    /// The linked Health Workout's effort under the caption ("🔥 320 kcal · 118 bpm"), read
    /// after the card is on screen; nil takes it away again.
    func showEffort(_ text: String?) {
        guard let text else { return effortLabel.removeFromSuperview() }
        effortLabel.attributedText = WorkoutEffort.line(text)
        effortLabel.adjustsFontForContentSizeCategory = true
        if effortLabel.superview == nil { card.contentStack.addArrangedSubview(effortLabel) }
        accessibilityLabel = (accessibilityLabel ?? "") + ", \(text) from Apple Watch"
    }

    /// "6:12 PM · 50 min" once finished; "Active · since 6:12 PM" while it is the Active Workout.
    private static func whenText(_ workout: WorkoutRecord) -> String {
        guard let finishedAt = workout.finishedAt else {
            return "Active · since \(TrainText.timeText(workout.startedAt))"
        }
        return "\(TrainText.timeText(workout.startedAt)) · \(TrainText.duration(from: workout.startedAt, to: finishedAt))"
    }
}
