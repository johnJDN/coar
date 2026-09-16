import UIKit
import os

/// A finished Workout, pushed from the month grid or Recent workouts: the Plan's name as the
/// title, when it ran, and one `Card` per Exercise row listing its Logged Sets in the
/// display unit (ADR 0004). Read-only: history is a record of what happened (ADR 0003).
final class WorkoutDetailViewController: ScreenViewController {

    private static let logger = Logger(category: "Train")

    private let dependencies: AppDependencies
    private let workoutID: WorkoutRecord.ID
    private var unitObserver: NSObjectProtocol?

    init(dependencies: AppDependencies, workoutID: WorkoutRecord.ID) {
        self.dependencies = dependencies
        self.workoutID = workoutID
        super.init(title: "")
    }

    deinit {
        if let unitObserver { NotificationCenter.default.removeObserver(unitObserver) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        unitObserver = NotificationCenter.default.addObserver(
            forName: Preferences.massUnitDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.render() }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    private func render() {
        let workout: WorkoutRecord
        do {
            guard let read = try dependencies.store.workout(workoutID) else { return }
            workout = read
        } catch {
            Self.logger.error("Failed to read Workout: \(error, privacy: .public)")
            return
        }
        let unit = dependencies.preferences.massUnit
        title = workout.title
        navigationItem.subtitle = Self.subtitle(for: workout)

        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if workout.exercises.isEmpty {
            contentStack.addArrangedSubview(Self.emptyCard())
        }
        for row in workout.exercises {
            let card = CardView(title: row.name, systemImage: "dumbbell.fill")
            let subtitle = UILabel()
            subtitle.text = [workout.supersetLabel(for: row.id), TrainText.count(row.sets.count, "set")].compactMap { $0 }.joined(separator: " · ")
            subtitle.font = UIFont.label
            subtitle.textColor = UIColor.textSecondary
            subtitle.adjustsFontForContentSizeCategory = true
            card.contentStack.addArrangedSubview(subtitle)
            card.contentStack.setCustomSpacing(Metrics.spaceInner, after: subtitle)
            for (index, set) in row.sets.enumerated() {
                card.contentStack.addArrangedSubview(Self.setLine(number: index + 1, text: TrainText.setLine(set, in: unit)))
            }
            contentStack.addArrangedSubview(card)
        }
    }

    /// "Sep 10 · 6:12 PM · 50 min".
    private static func subtitle(for workout: WorkoutRecord) -> String {
        var parts = [TrainText.dayText(workout.day), TrainText.timeText(workout.startedAt)]
        if let finishedAt = workout.finishedAt {
            parts.append(TrainText.duration(from: workout.startedAt, to: finishedAt))
        }
        return parts.joined(separator: " · ")
    }

    private static func setLine(number: Int, text: String) -> UIView {
        let numberLabel = UILabel()
        numberLabel.text = "\(number)"
        numberLabel.font = UIFont.label
        numberLabel.textColor = UIColor.textTertiary
        numberLabel.adjustsFontForContentSizeCategory = true
        numberLabel.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let value = UILabel()
        value.text = text
        value.font = UIFont.metricNumber
        value.textColor = UIColor.textPrimary
        value.adjustsFontForContentSizeCategory = true

        let line = UIStackView(arrangedSubviews: [numberLabel, value])
        line.axis = .horizontal
        line.alignment = .firstBaseline
        line.spacing = Metrics.spaceTight
        line.isAccessibilityElement = true
        line.accessibilityLabel = "Set \(number), \(text)"
        return line
    }

    private static func emptyCard() -> UIView {
        let card = CardView()
        let hero = UILabel()
        hero.text = "—"
        hero.font = UIFont.heroNumber
        hero.textColor = UIColor.textTertiary
        hero.adjustsFontForContentSizeCategory = true
        let caption = UILabel()
        caption.text = "No sets were logged."
        caption.font = UIFont.label
        caption.textColor = UIColor.textSecondary
        caption.adjustsFontForContentSizeCategory = true
        card.contentStack.addArrangedSubview(hero)
        card.contentStack.addArrangedSubview(caption)
        return card
    }
}
