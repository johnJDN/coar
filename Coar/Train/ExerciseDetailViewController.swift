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
    private let heroLabel = UILabel()
    private let captionLabel = UILabel()
    private let chart = UIHostingController(rootView: ProgressionChart(model: .init(points: [], unit: "")))
    private let recentStack = UIStackView()
    private var exercise: ExerciseRecord?
    private var unitObserver: NSObjectProtocol?

    init(dependencies: AppDependencies, exerciseID: ExerciseRecord.ID) {
        self.dependencies = dependencies
        self.exerciseID = exerciseID
        super.init(title: "")
    }

    deinit {
        if let unitObserver { NotificationCenter.default.removeObserver(unitObserver) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never

        let edit = UIBarButtonItem(title: "Edit", primaryAction: UIAction { [weak self] _ in self?.presentEdit() })
        edit.accessibilityLabel = "Edit exercise"
        navigationItem.rightBarButtonItem = edit

        heroLabel.font = UIFont.heroNumber
        heroLabel.adjustsFontForContentSizeCategory = true
        captionLabel.font = UIFont.label
        captionLabel.textColor = UIColor.textSecondary
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 0

        chart.view.backgroundColor = .clear
        chart.sizingOptions = .intrinsicContentSize
        addChild(chart)

        let card = CardView(title: "Progression", systemImage: "chart.line.uptrend.xyaxis", iconTint: UIColor.accentLime)
        card.contentStack.setCustomSpacing(Metrics.spaceTight, after: card.contentStack.arrangedSubviews[0])
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
            setHero(TrainText.estimatedOneRepMax(latest.kilograms, in: unit), isEmpty: false)
            captionLabel.text = "Estimated 1RM · \(TrainText.dayText(workout.day))"
        } else {
            setHero("—", isEmpty: true)
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
        let recent = workouts.reversed().lazy
            .map { ($0, $0.loggedSets(of: self.exerciseID).filter(\.isCompleted)) }
            .filter { !$0.1.isEmpty }
            .prefix(Self.recentLimit)
        if recent.isEmpty {
            recentStack.addArrangedSubview(CardView.emptyState(caption: "Sets you log for this exercise land here.", accessibilityLabel: "No sets yet. Sets you log for this exercise land here."))
        }
        for (workout, sets) in recent {
            let card = CardView(title: TrainText.dayText(workout.day), systemImage: "dumbbell.fill")
            let subtitle = UILabel()
            subtitle.text = "\(workout.title) · \(TrainText.timeText(workout.startedAt))"
            subtitle.font = UIFont.label
            subtitle.textColor = UIColor.textSecondary
            subtitle.adjustsFontForContentSizeCategory = true
            card.contentStack.addArrangedSubview(subtitle)
            card.contentStack.setCustomSpacing(Metrics.spaceInner, after: subtitle)
            for (index, set) in sets.enumerated() {
                card.contentStack.addArrangedSubview(UIView.setLine(number: index + 1, text: TrainText.setLine(set, in: unit)))
            }
            recentStack.addArrangedSubview(card)
        }
    }

    /// Number changes cross-dissolve (DESIGN.md §9); the empty value takes `textTertiary` (§5).
    private func setHero(_ text: String, isEmpty: Bool) {
        let apply = {
            self.heroLabel.text = text
            self.heroLabel.textColor = isEmpty ? UIColor.textTertiary : UIColor.textPrimary
        }
        guard heroLabel.text != text, viewIfLoaded?.window != nil else { return apply() }
        UIView.transition(with: heroLabel, duration: 0.25, options: .transitionCrossDissolve, animations: apply)
    }

    // MARK: - Edit

    private func presentEdit() {
        guard let exercise else { return }
        present(ExerciseFormViewController.sheet(dependencies: dependencies, mode: .edit(exercise)) { [weak self] _ in self?.render() }, animated: true)
    }
}
