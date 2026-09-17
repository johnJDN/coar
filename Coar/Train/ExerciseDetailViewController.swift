import SwiftUI
import UIKit
import os

/// An Exercise's detail page, pushed from the catalogue or an `ExerciseCard` (DESIGN.md §11):
/// Progression as the hero card (the latest Estimated 1RM as the number, the chart of one
/// point per Workout below it), then Recent sets, one card per Workout listing the sets
/// logged for the Exercise in the display unit (ADR 0004). Edit in the bar opens the Exercise
/// sheet. Reads through the façade on every appearance, after every edit, and whenever the
/// unit changes.
final class ExerciseDetailViewController: ScreenViewController {

    private static let logger = Logger(category: "Train")
    /// How many Workouts the Recent sets section lists.
    private static let recentLimit = 10

    private let dependencies: AppDependencies
    private let exerciseID: ExerciseRecord.ID
    private let heroLabel = HeroNumberLabel()
    private let captionLabel = UILabel()
    private let chart = UIHostingController(rootView: ProgressionChart(model: .init(points: [], unit: "")))
    private let recentStack = UIStackView()
    private var exercise: ExerciseRecord?
    private var unitObservation: MassUnitObservation?

    init(dependencies: AppDependencies, exerciseID: ExerciseRecord.ID) {
        self.dependencies = dependencies
        self.exerciseID = exerciseID
        super.init(title: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never

        let edit = UIBarButtonItem(title: "Edit", primaryAction: UIAction { [weak self] _ in self?.presentEdit() })
        edit.accessibilityLabel = "Edit exercise"
        navigationItem.rightBarButtonItem = edit

        captionLabel.font = UIFont.label
        captionLabel.textColor = UIColor.textSecondary
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 0

        chart.view.backgroundColor = .clear
        chart.sizingOptions = .intrinsicContentSize
        addChild(chart)

        let card = CardView(title: "Progression", systemImage: "chart.line.uptrend.xyaxis", iconTint: UIColor.accentLime)
        card.contentStack.addArrangedSubview(heroLabel)
        card.contentStack.addArrangedSubview(captionLabel)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: captionLabel)
        card.contentStack.addArrangedSubview(chart.view)
        contentStack.addArrangedSubview(card)
        chart.didMove(toParent: self)
        contentStack.setCustomSpacing(Metrics.spaceSection, after: card)

        let header = UILabel()
        header.text = "Recent sets"
        header.font = UIFont.sectionHeader
        header.textColor = UIColor.textPrimary
        header.adjustsFontForContentSizeCategory = true
        contentStack.addArrangedSubview(header)
        contentStack.setCustomSpacing(Metrics.spaceTight, after: header)
        recentStack.axis = .vertical
        recentStack.spacing = Metrics.spaceCard
        contentStack.addArrangedSubview(recentStack)

        unitObservation = dependencies.preferences.observeMassUnit { [weak self] in self?.render() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    // MARK: - Rendering

    private func render() {
        let workouts: [WorkoutRecord]
        do {
            guard let read = try dependencies.store.exercise(exerciseID) else { return }
            exercise = read
            workouts = try dependencies.store.workouts(containing: exerciseID)
        } catch {
            Self.logger.error("Failed to read Exercise Progression: \(error, privacy: .public)")
            return
        }
        guard let exercise else { return }
        let unit = dependencies.preferences.massUnit
        title = exercise.name
        navigationItem.subtitle = TrainText.details(of: exercise)

        let points = Progression.points(for: exerciseID, in: workouts)
        if let latest = points.last, let workout = workouts.first(where: { $0.id == latest.workoutID }) {
            heroLabel.setValue(TrainText.estimatedOneRepMax(latest.kilograms, in: unit), isEmpty: false)
            captionLabel.text = "Estimated 1RM · \(workout.day.shortText)"
        } else {
            heroLabel.setValue("—", isEmpty: true)
            captionLabel.text = "No sets logged for this exercise yet"
        }
        chart.rootView = ProgressionChart(model: .init(
            points: points.map { TrendPoint(date: $0.date, value: unit.displayValue(fromKilograms: $0.kilograms)) },
            unit: unit.symbol
        ))

        renderRecent(workouts, in: unit)
    }

    /// One card per Workout with a completed set of the Exercise, latest first.
    private func renderRecent(_ workouts: [WorkoutRecord], in unit: MassUnit) {
        recentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let recent = Array(workouts.reversed().lazy
            .map { ($0, $0.loggedSets(of: self.exerciseID).filter(\.isCompleted)) }
            .filter { !$0.1.isEmpty }
            .prefix(Self.recentLimit))
        if recent.isEmpty {
            recentStack.addArrangedSubview(CardView.emptyState(caption: "Sets you log for this exercise land here.", accessibilityLabel: "No sets yet. Sets you log for this exercise land here."))
        }
        for (workout, sets) in recent {
            let subtitle = "\(workout.title) · \(TrainText.timeText(workout.startedAt))"
            recentStack.addArrangedSubview(CardView.setHistory(title: workout.day.shortText, subtitle: subtitle, sets: sets, in: unit))
        }
    }

    // MARK: - Edit

    private func presentEdit() {
        guard let exercise else { return }
        present(ExerciseFormViewController.sheet(dependencies: dependencies, mode: .edit(exercise)) { [weak self] _ in self?.render() }, animated: true)
    }
}
