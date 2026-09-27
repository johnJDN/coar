import UIKit
import os

/// The live logger, pushed from the Train root's Start (or Resume) and from the accessory
/// bar: one `ExerciseCard` per row of the Active Workout with its `SetRow`s, an Add exercise
/// row over the catalogue picker, Finish in the bar, and Discard in the `…` menu. Every
/// keystroke and check writes through the façade at once, so nothing is lost if the app
/// closes mid-set (CONTEXT.md "Active Workout"). Completing a set starts the rest timer
/// when `RestTimerRule` says so (never between the Exercises of a Superset); grouped cards
/// stay where they are with a link between them, and nothing scrolls or moves focus on
/// completion. Finish drops the sets never completed and then offers to move today's
/// weights into the Plan.
///
/// In `.editing` mode the same screen edits a finished Workout (a past one logged after
/// the fact, or any from its detail): no rest timer, no accessory bar, no Finish; Done, and
/// leaving drops the sets left unticked, as Finish does, after asking.
final class WorkoutLoggerViewController: UIViewController {

    enum Mode {
        case active, editing
    }

    private static let logger = Logger(category: "Train")

    private enum Item: Hashable {
        case exercise(WorkoutExerciseRecord.ID)
        /// The gap under a card: air, or the Superset link when the next card is grouped
        /// with it. The cards themselves have no spacing, so the gaps are items.
        case gap(after: WorkoutExerciseRecord.ID)
        case link(after: WorkoutExerciseRecord.ID)
        case addExercise
    }

    private let dependencies: AppDependencies
    /// Read by the shell to find the Active Workout's logger in the Train stack.
    let workoutID: WorkoutRecord.ID
    let mode: Mode
    private var backGuard: BackGuard?
    private var workout: WorkoutRecord?
    /// Equipment is not snapshotted; it is read live for the card subtitle.
    private var equipment: [ExerciseRecord.ID: String] = [:]
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Item>!
    private var unitObservation: MassUnitObservation?
    /// False once a render finds the Workout gone (finished or discarded elsewhere); the
    /// screen pops itself once fully on screen, never mid-transition.
    private var workoutExists = true

    init(dependencies: AppDependencies, workoutID: WorkoutRecord.ID, mode: Mode = .active) {
        self.dependencies = dependencies
        self.workoutID = workoutID
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .never

        switch mode {
        case .active:
            let finish = UIBarButtonItem(title: "Finish", primaryAction: UIAction { [weak self] _ in self?.finish() })
            finish.tintColor = UIColor.accentCoral
            let discard = UIAction(title: "Discard workout", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.confirmDiscard()
            }
            let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: [discard]))
            more.accessibilityLabel = "More"
            navigationItem.rightBarButtonItems = [finish, more]
        case .editing:
            let done = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.doneEditing() })
            let time = UIAction(title: "Date and time", image: UIImage(systemName: "calendar")) { [weak self] _ in self?.presentTime() }
            let delete = UIAction(title: "Delete workout", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.confirmDelete()
            }
            let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: [time, delete]))
            more.accessibilityLabel = "More"
            navigationItem.rightBarButtonItems = [done, more]
            backGuard = BackGuard(controller: self, verdict: { [weak self] in self?.leaveVerdict ?? .leave }, onDiscard: { [weak self] in
                self?.dropUnticked()
            })
        }

        configureCollectionView()
        unitObservation = dependencies.preferences.observeMassUnit { [weak self] in self?.render() }
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if mode == .active {
            (tabBarController as? RootTabBarController)?.loggerIsInTrainStack = true
        }
        render()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        popIfGone()
    }

    /// Only leaving the stack (a pop) frees the accessory slot; a picker pushed over the
    /// logger, or a switch to another tab, keeps the logger where it is.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backGuard?.release()
        if isMovingFromParent, mode == .active {
            (tabBarController as? RootTabBarController)?.loggerIsInTrainStack = false
        }
    }

    // MARK: - Collection view

    private func configureCollectionView() {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(200))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: Metrics.spaceCard, leading: Metrics.spaceEdge, bottom: Metrics.spaceCard, trailing: Metrics.spaceEdge)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.dismissesKeyboardOnDrag()
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        collectionView.insetsContentAboveKeyboard(in: view)

        let exerciseCell = UICollectionView.CellRegistration<ExerciseCardCell, WorkoutExerciseRecord.ID> { [weak self] cell, _, id in
            guard let self, let workout, let row = workout.exercises.first(where: { $0.id == id }) else { return }
            cell.configure(with: cardModel(for: row, in: workout))
            cell.onChangeSet = { [weak self] setID, weight, reps in self?.setChanged(setID, weight: weight, reps: reps) }
            cell.onToggleSet = { [weak self] setID, completed in self?.setToggled(setID, completed: completed) }
            cell.onRemoveSet = { [weak self] setID in self?.removeSet(setID) }
            cell.onAddSet = { [weak self] in self?.addSet(to: id) }
            cell.onRemoveExercise = { [weak self] in self?.removeExercise(id) }
            cell.onStartRest = { [weak self] seconds in self?.dependencies.restTimer.start(seconds: seconds) }
            cell.onOpenProgression = { [weak self] in
                guard let exerciseID = row.exerciseID else { return }
                self?.showProgression(of: exerciseID)
            }
        }
        let gapCell = UICollectionView.CellRegistration<CardGapCell, Item> { _, _, _ in }
        let linkCell = UICollectionView.CellRegistration<SupersetLinkCell, Item> { _, _, _ in }
        let addCell = UICollectionView.CellRegistration<GlassActionCell, Item> { [weak self] cell, _, _ in
            cell.configure(title: "Add exercise", systemImage: "plus") { [weak self] in self?.pushPicker() }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .exercise(let id):
                return collectionView.dequeueConfiguredReusableCell(using: exerciseCell, for: indexPath, item: id)
            case .gap:
                return collectionView.dequeueConfiguredReusableCell(using: gapCell, for: indexPath, item: item)
            case .link:
                return collectionView.dequeueConfiguredReusableCell(using: linkCell, for: indexPath, item: item)
            case .addExercise:
                return collectionView.dequeueConfiguredReusableCell(using: addCell, for: indexPath, item: item)
            }
        }
    }

    // MARK: - Rendering

    private func render() {
        guard reload() else { return }
        guard let workout else { return }
        title = workout.title
        switch mode {
        case .active:
            navigationItem.subtitle = "Started \(TrainText.timeText(workout.startedAt))"
        case .editing:
            navigationItem.subtitle = TrainText.when(workout)
            backGuard?.refresh()
        }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        snapshot.appendItems(Self.items(for: workout.exercises), toSection: 0)
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)
    }

    /// One card per row, a gap after each, the gap a Superset link when the row below
    /// shares the row's group, then Add exercise.
    private static func items(for rows: [WorkoutExerciseRecord]) -> [Item] {
        var items: [Item] = []
        for (index, row) in rows.enumerated() {
            items.append(.exercise(row.id))
            let next = rows.indices.contains(index + 1) ? rows[index + 1] : nil
            let linked = row.supersetGroup != nil && next?.supersetGroup == row.supersetGroup
            items.append(linked ? .link(after: row.id) : .gap(after: row.id))
        }
        return items + [.addExercise]
    }

    /// Re-reads the Workout; false when it is gone, in which case the screen leaves.
    @discardableResult
    private func reload() -> Bool {
        do {
            guard let read = try dependencies.store.workout(workoutID) else {
                workoutExists = false
                popIfGone()
                return false
            }
            workout = read
            for row in read.exercises {
                guard let exerciseID = row.exerciseID, equipment[exerciseID] == nil else { continue }
                equipment[exerciseID] = try dependencies.store.exercise(exerciseID)?.equipment ?? ""
            }
            return true
        } catch {
            Self.logger.error("Failed to read Workout: \(error, privacy: .public)")
            return false
        }
    }

    private func popIfGone() {
        guard !workoutExists, viewIfLoaded?.window != nil, presentedViewController == nil,
              navigationController?.transitionCoordinator == nil
        else { return }
        navigationController?.popViewController(animated: true)
    }

    private func cardModel(for row: WorkoutExerciseRecord, in workout: WorkoutRecord) -> ExerciseCardCell.Model {
        let unit = dependencies.preferences.massUnit
        let equipment = row.exerciseID.flatMap { self.equipment[$0] }.flatMap { $0.isEmpty ? nil : $0 }
        let subtitle = [workout.supersetLabel(for: row.id), equipment, TrainText.count(row.sets.count, "set")]
            .compactMap { $0 }.joined(separator: " · ")
        let sets = row.sets.enumerated().map { index, set in
            SetRowView.Model(
                id: set.id,
                number: index + 1,
                weight: set.kilograms > 0 ? TrainText.weightValue(set.kilograms, in: unit) : "",
                reps: set.reps > 0 ? "\(set.reps)" : "",
                repsHint: set.target?.reps.text,
                unitSymbol: unit.symbol,
                isCompleted: set.isCompleted
            )
        }
        return ExerciseCardCell.Model(
            name: row.name,
            subtitle: subtitle,
            restSeconds: mode == .active ? RestTimerRule.seconds(restDefault: row.restSeconds) : nil,
            sets: sets,
            canOpenProgression: row.exerciseID != nil
        )
    }

    // MARK: - Set writes

    private func loggedSet(_ id: LoggedSetRecord.ID) -> LoggedSetRecord? {
        workout?.exercises.lazy.flatMap(\.sets).first { $0.id == id }
    }

    /// Writes what was typed without re-rendering, so the keyboard and cursor stay put. A
    /// field that does not parse leaves the stored value alone.
    private func setChanged(_ id: LoggedSetRecord.ID, weight: String, reps: String) {
        guard let set = loggedSet(id) else { return }
        let unit = dependencies.preferences.massUnit
        let weightText = weight.trimmingCharacters(in: .whitespaces)
        let repsText = reps.trimmingCharacters(in: .whitespaces)
        let kilograms: Double
        if weightText.isEmpty {
            kilograms = 0
        } else {
            guard let typed = Double(typed: weightText), typed >= 0 else { return }
            kilograms = unit.kilograms(fromDisplayValue: typed)
        }
        let count: Int
        if repsText.isEmpty {
            count = 0
        } else {
            guard let typed = Int(repsText), typed >= 0 else { return }
            count = typed
        }
        do {
            try dependencies.store.updateLoggedSet(id, kilograms: kilograms, reps: count, isCompleted: set.isCompleted)
            reload()
        } catch {
            Self.logger.error("Failed to write Logged Set: \(error, privacy: .public)")
        }
    }

    /// Completing a set is what starts the rest timer; un-completing never does.
    private func setToggled(_ id: LoggedSetRecord.ID, completed: Bool) {
        guard let set = loggedSet(id) else { return }
        do {
            try dependencies.store.updateLoggedSet(id, kilograms: set.kilograms, reps: set.reps, isCompleted: completed)
        } catch {
            Self.logger.error("Failed to complete Logged Set: \(error, privacy: .public)")
        }
        render()
        if mode == .active, completed, let workout, let row = workout.exercises.first(where: { $0.sets.contains { $0.id == id } }),
           let seconds = workout.restSeconds(afterSetOn: row.id) {
            dependencies.restTimer.start(seconds: seconds)
        }
    }

    private func addSet(to rowID: WorkoutExerciseRecord.ID) {
        view.endEditing(true)
        do {
            try dependencies.store.addLoggedSet(to: rowID)
        } catch {
            Self.logger.error("Failed to add Logged Set: \(error, privacy: .public)")
        }
        render()
    }

    private func removeSet(_ id: LoggedSetRecord.ID) {
        view.endEditing(true)
        do {
            try dependencies.store.removeLoggedSet(id)
        } catch {
            Self.logger.error("Failed to remove Logged Set: \(error, privacy: .public)")
        }
        render()
    }

    private func removeExercise(_ id: WorkoutExerciseRecord.ID) {
        view.endEditing(true)
        do {
            try dependencies.store.removeExercise(id)
        } catch {
            Self.logger.error("Failed to remove exercise row: \(error, privacy: .public)")
        }
        render()
    }

    /// The Exercise's detail page over the logger; the logger stays in the stack, so the
    /// accessory bar stays hidden as it does under the picker.
    private func showProgression(of exerciseID: ExerciseRecord.ID) {
        view.endEditing(true)
        navigationController?.pushViewController(ExerciseDetailViewController(dependencies: dependencies, exerciseID: exerciseID), animated: true)
    }

    private func pushPicker() {
        view.endEditing(true)
        let picker = ExercisePickerViewController(dependencies: dependencies) { [weak self] exercise in
            guard let self else { return }
            do {
                try dependencies.store.addExercise(exercise.id, to: workoutID)
            } catch {
                Self.logger.error("Failed to add exercise row: \(error, privacy: .public)")
            }
            navigationController?.popToViewController(self, animated: true)
        }
        navigationController?.pushViewController(picker, animated: true)
    }

    // MARK: - Finish and discard

    /// Nothing completed: offer to discard instead, so history never holds an empty
    /// Workout by accident. Sets left uncompleted: say how many will be dropped first.
    private func finish() {
        view.endEditing(true)
        guard let workout else { return }
        if workout.completedSetCount == 0 {
            let alert = UIAlertController(
                title: "Nothing logged yet",
                message: "No set was completed. Discard this workout, or keep logging?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in self?.discard() })
            alert.addAction(UIAlertAction(title: "Keep logging", style: .cancel))
            present(alert, animated: true)
        } else if workout.uncompletedSetCount > 0 {
            let dropped = TrainText.count(workout.uncompletedSetCount, "set")
            let alert = UIAlertController(
                title: "Finish workout?",
                message: "\(dropped) you did not complete will be dropped.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Finish", style: .default) { [weak self] _ in self?.performFinish() })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        } else {
            performFinish()
        }
    }

    private func performFinish() {
        let finished: WorkoutRecord
        do {
            finished = try dependencies.store.finishWorkout(workoutID)
        } catch {
            Self.logger.error("Failed to finish Workout: \(error, privacy: .public)")
            return
        }
        let hasWeights = finished.exercises.contains { $0.sets.contains { $0.isCompleted && $0.kilograms > 0 } }
        guard finished.planID != nil, hasWeights else { return leave() }
        let alert = UIAlertController(
            title: "Update plan targets with today's weights?",
            message: "Only the weights change; reps and exercises stay as planned.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Update", style: .default) { [weak self] _ in
            guard let self else { return }
            do {
                try dependencies.store.updatePlanTargets(from: workoutID)
            } catch {
                Self.logger.error("Failed to update Plan targets: \(error, privacy: .public)")
            }
            leave()
        })
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel) { [weak self] _ in self?.leave() })
        present(alert, animated: true)
    }

    private func confirmDiscard() {
        view.endEditing(true)
        let alert = UIAlertController(
            title: "Discard this workout?",
            message: "Every set logged in it is deleted. This cannot be undone.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Discard workout", style: .destructive) { [weak self] _ in self?.discard() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func discard() {
        do {
            try dependencies.store.discardWorkout(workoutID)
        } catch {
            Self.logger.error("Failed to discard Workout: \(error, privacy: .public)")
            return
        }
        leave()
    }

    private func leave() {
        navigationController?.popToRootViewController(animated: true)
    }

    // MARK: - Editing a finished Workout

    /// Unticked sets are dropped on the way out, as Finish drops them; asking first.
    private var leaveVerdict: BackGuard.Verdict {
        guard let workout, workout.uncompletedSetCount > 0 else { return .leave }
        let count = TrainText.count(workout.uncompletedSetCount, "set")
        return .ask(title: "Drop \(count) left unticked?", message: "A finished workout keeps only the sets you ticked.", discard: "Drop and Leave")
    }

    private func doneEditing() {
        view.endEditing(true)
        guard case .ask(let title, let message, let discard) = leaveVerdict else {
            navigationController?.popViewController(animated: true)
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel))
        alert.addAction(UIAlertAction(title: discard, style: .destructive) { [weak self] _ in
            self?.dropUnticked()
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func dropUnticked() {
        do {
            try dependencies.store.dropUncompletedSets(workoutID)
        } catch {
            Self.logger.error("Failed to drop unticked sets: \(error, privacy: .public)")
        }
    }

    private func presentTime() {
        view.endEditing(true)
        guard let workout else { return }
        present(PastWorkoutViewController.sheet(dependencies: dependencies, purpose: .editTime(workout), onChange: { [weak self] in self?.render() }), animated: true)
    }

    private func confirmDelete() {
        view.endEditing(true)
        let alert = DeletePermanently.confirmation(name: "this workout", consequences: ["Its sets leave your history and progression charts."]) { [weak self] in
            guard let self else { return }
            do {
                try dependencies.store.discardWorkout(workoutID)
            } catch {
                Self.logger.error("Failed to delete Workout: \(error, privacy: .public)")
                return
            }
            backGuard?.release()
            navigationController?.popViewController(animated: true)
        }
        present(alert, animated: true)
    }
}

extension WorkoutLoggerViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        false
    }
}
