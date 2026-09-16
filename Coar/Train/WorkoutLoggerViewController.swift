import UIKit
import os

/// The live logger, pushed from the Train root's Start (or Resume) and from the accessory
/// bar: one `ExerciseCard` per row of the Active Workout with its `SetRow`s, an Add exercise
/// row over the catalogue picker, Finish in the bar, and Discard in the `…` menu. Every
/// keystroke and check writes through the façade at once, so nothing is lost if the app
/// closes mid-set (CONTEXT.md "Active Workout"). Finish drops the sets never completed and
/// then offers to move today's weights into the Plan.
final class WorkoutLoggerViewController: UIViewController {

    private static let logger = Logger(category: "Train")

    private enum Item: Hashable {
        case exercise(WorkoutExerciseRecord.ID)
        case addExercise
    }

    private let dependencies: AppDependencies
    private let workoutID: WorkoutRecord.ID
    private var workout: WorkoutRecord?
    /// Equipment is not snapshotted; it is read live for the card subtitle.
    private var equipment: [ExerciseRecord.ID: String] = [:]
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Item>!
    private var unitObserver: NSObjectProtocol?
    /// False once a render finds the Workout gone (finished or discarded elsewhere); the
    /// screen pops itself once fully on screen, never mid-transition.
    private var workoutExists = true

    init(dependencies: AppDependencies, workoutID: WorkoutRecord.ID) {
        self.dependencies = dependencies
        self.workoutID = workoutID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        if let unitObserver { NotificationCenter.default.removeObserver(unitObserver) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .never

        let finish = UIBarButtonItem(title: "Finish", primaryAction: UIAction { [weak self] _ in self?.finish() })
        finish.tintColor = UIColor.accentCoral
        let discard = UIAction(title: "Discard workout", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            self?.confirmDiscard()
        }
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: [discard]))
        more.accessibilityLabel = "More"
        navigationItem.rightBarButtonItems = [finish, more]

        configureCollectionView()
        unitObserver = NotificationCenter.default.addObserver(
            forName: Preferences.massUnitDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.render() }
        }
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as? RootTabBarController)?.isLoggerVisible = true
        render()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        popIfGone()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        (tabBarController as? RootTabBarController)?.isLoggerVisible = false
    }

    // MARK: - Collection view

    private func configureCollectionView() {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(200))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Metrics.spaceCard
        section.contentInsets = NSDirectionalEdgeInsets(top: Metrics.spaceCard, leading: Metrics.spaceEdge, bottom: Metrics.spaceCard, trailing: Metrics.spaceEdge)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .interactive
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])

        let exerciseCell = UICollectionView.CellRegistration<ExerciseCardCell, WorkoutExerciseRecord.ID> { [weak self] cell, _, id in
            guard let self, let workout, let row = workout.exercises.first(where: { $0.id == id }) else { return }
            cell.configure(with: cardModel(for: row, in: workout))
            cell.onChangeSet = { [weak self] setID, weight, reps in self?.setChanged(setID, weight: weight, reps: reps) }
            cell.onToggleSet = { [weak self] setID, completed in self?.setToggled(setID, completed: completed) }
            cell.onRemoveSet = { [weak self] setID in self?.removeSet(setID) }
            cell.onAddSet = { [weak self] in self?.addSet(to: id) }
            cell.onRemoveExercise = { [weak self] in self?.removeExercise(id) }
        }
        let addCell = UICollectionView.CellRegistration<GlassActionCell, Item> { [weak self] cell, _, _ in
            cell.configure(title: "Add exercise", systemImage: "plus") { [weak self] in self?.pushPicker() }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .exercise(let id):
                return collectionView.dequeueConfiguredReusableCell(using: exerciseCell, for: indexPath, item: id)
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
        navigationItem.subtitle = "Started \(TrainText.timeText(workout.startedAt))"
        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        snapshot.appendItems(workout.exercises.map { .exercise($0.id) } + [.addExercise], toSection: 0)
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)
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
                number: index + 1,
                weight: set.kilograms > 0 ? TrainText.weightValue(set.kilograms, in: unit) : "",
                reps: set.reps > 0 ? "\(set.reps)" : "",
                repsHint: set.target?.reps.text,
                unitSymbol: unit.symbol,
                isCompleted: set.isCompleted
            )
        }
        return ExerciseCardCell.Model(name: row.name, subtitle: subtitle, sets: sets, setIDs: row.sets.map(\.id))
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

    private func setToggled(_ id: LoggedSetRecord.ID, completed: Bool) {
        guard let set = loggedSet(id) else { return }
        do {
            try dependencies.store.updateLoggedSet(id, kilograms: set.kilograms, reps: set.reps, isCompleted: completed)
        } catch {
            Self.logger.error("Failed to complete Logged Set: \(error, privacy: .public)")
        }
        render()
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
}

extension WorkoutLoggerViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        false
    }
}

extension WorkoutRecord {
    /// "A1", "A2" for the first Superset's rows, "B1", "B2" for the next; nil for a row on
    /// its own (CONTEXT.md "Superset").
    func supersetLabel(for rowID: WorkoutExerciseRecord.ID) -> String? {
        guard let index = exercises.firstIndex(where: { $0.id == rowID }), let group = exercises[index].supersetGroup else { return nil }
        var seen: [Int] = []
        for row in exercises {
            if let other = row.supersetGroup, !seen.contains(other) { seen.append(other) }
        }
        let rank = seen.firstIndex(of: group) ?? 0
        let letter = String(UnicodeScalar(UInt8(ascii: "A") + UInt8(clamping: min(rank, 25))))
        let position = exercises[...index].filter { $0.supersetGroup == group }.count
        return "\(letter)\(position)"
    }
}

/// A full-width glass capsule action as a list item (the logger's Add exercise, matching
/// the root's New plan).
final class GlassActionCell: UICollectionViewCell {

    private let button: UIButton
    private var onTap: (() -> Void)?

    override init(frame: CGRect) {
        var configuration = UIButton.Configuration.glass()
        configuration.imagePadding = Metrics.spaceTight
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .headline)
        configuration.cornerStyle = .capsule
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.titleTextAttributesTransformer = .cardTitle
        button = UIButton(configuration: configuration)
        super.init(frame: frame)
        button.addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: contentView.topAnchor),
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            button.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(title: String, systemImage: String, onTap: @escaping () -> Void) {
        button.configuration?.title = title
        button.configuration?.image = UIImage(systemName: systemImage)
        self.onTap = onTap
    }
}
