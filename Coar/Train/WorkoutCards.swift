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

    /// The linked Health Workout's effort under the caption ("🔥 320 cal · 118 bpm"), read
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

/// A walk on a Day's list: what the Watch called it, when it ran, what its note adds, and its
/// effort. Tapping opens its note.
final class WalkCardControl: CardControl {

    init(walk: HealthWorkout, note: WorkoutNoteRecord?) {
        super.init(card: CardView(title: walk.name, systemImage: "figure.walk", iconTint: UIColor.accentAmber, accessory: .navigates))

        let when = UILabel()
        when.text = "\(TrainText.timeText(walk.start)) · \(TrainText.duration(from: walk.start, to: walk.end))"
        when.font = UIFont.metricNumber
        when.textColor = UIColor.textPrimary
        when.adjustsFontForContentSizeCategory = true
        card.contentStack.addArrangedSubview(when)

        let added = [note?.settingsText, note?.usedInhaler == true ? "inhaler" : nil].compactMap { $0 }.joined(separator: " · ")
        if !added.isEmpty {
            let caption = UILabel()
            caption.text = added
            caption.font = UIFont.label
            caption.textColor = UIColor.textSecondary
            caption.adjustsFontForContentSizeCategory = true
            caption.numberOfLines = 2
            card.contentStack.addArrangedSubview(caption)
        }
        if let effort = walk.effortText {
            let label = UILabel()
            label.attributedText = WorkoutEffort.line(effort)
            label.adjustsFontForContentSizeCategory = true
            card.contentStack.addArrangedSubview(label)
        }

        isAccessibilityElement = true
        accessibilityLabel = [walk.name, when.text, added.isEmpty ? nil : added, walk.effortText].compactMap { $0 }.joined(separator: ", ")
    }
}
