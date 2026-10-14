import UIKit
import os

/// The sheet that links a finished Workout to a Health Workout (`.scratch/watch-link/`): the
/// ones Apple Health holds for the Workout's Day, best match first, each with its time and
/// effort; tapping one links it. The first time, the system asks for the workouts, active
/// energy, and heart rate it reads. HealthKit never says a read was refused, so an empty list
/// says what to check instead of blaming anything.
final class HealthWorkoutPickerViewController: UIViewController {

    private static let logger = Logger(category: "Train")

    private let dependencies: AppDependencies
    private let workout: WorkoutRecord
    private let onLinked: () -> Void
    private var rows: [HealthWorkout] = []
    private let messageLabel = UILabel()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, HealthWorkout.ID>!
    private var loadTask: Task<Void, Never>?

    init(dependencies: AppDependencies, workout: WorkoutRecord, onLinked: @escaping () -> Void) {
        self.dependencies = dependencies
        self.workout = workout
        self.onLinked = onLinked
        super.init(nibName: nil, bundle: nil)
        title = "Link Watch workout"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The sheet the detail presents.
    static func sheet(dependencies: AppDependencies, workout: WorkoutRecord, onLinked: @escaping () -> Void) -> UIViewController {
        HealthWorkoutPickerViewController(dependencies: dependencies, workout: workout, onLinked: onLinked).inSheet(detents: [.medium(), .large()])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        navigationItem.subtitle = workout.day.shortText

        var layout = UICollectionLayoutListConfiguration(appearance: .plain)
        layout.showsSeparators = false
        layout.backgroundColor = .clear
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout.list(using: layout))
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        messageLabel.font = UIFont.bodyText
        messageLabel.textColor = UIColor.textSecondary
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.spaceEdge + Metrics.spaceInner),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -(Metrics.spaceEdge + Metrics.spaceInner)),
        ])

        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, HealthWorkout.ID> { [weak self] cell, _, id in
            guard let self, let item = rows.first(where: { $0.id == id }) else { return }
            var content = UIListContentConfiguration.listRow()
            content.text = item.name
            let when = "\(TrainText.timeText(item.start)) · \(TrainText.duration(from: item.start, to: item.end))"
            content.secondaryText = [when, item.effortText].compactMap { $0 }.joined(separator: "\n")
            content.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = content
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
            cell.accessories = item.id == workout.healthWorkoutID
                ? [.customView(configuration: .init(customView: Self.linkedMark(), placement: .trailing()))]
                : []
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { view, indexPath, id in
            view.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }
        message("Checking Apple Health…")
        load()
    }

    private static func linkedMark() -> UIView {
        let mark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        mark.tintColor = UIColor.accentGreen
        mark.accessibilityLabel = "Linked"
        return mark
    }

    private func message(_ text: String?) {
        messageLabel.text = text
        messageLabel.isHidden = text == nil
    }

    /// Asks for access once, then lists the Day's Health Workouts the Workout could take.
    private func load() {
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await dependencies.healthWorkouts.requestWorkoutAccess()
                let all = try await dependencies.healthWorkouts.healthWorkouts(on: workout.day)
                let taken = try dependencies.store.linkedHealthWorkoutIDs(excluding: workout.id)
                let span = (start: workout.startedAt, end: workout.finishedAt ?? workout.startedAt)
                rows = HealthWorkout.candidates(for: span, among: all, alreadyLinked: taken)
            } catch {
                Self.logger.error("Failed to read Health Workouts: \(error, privacy: .public)")
                rows = []
                message("Couldn't read Apple Health.")
                apply()
                return
            }
            message(rows.isEmpty ? Self.emptyMessage : nil)
            apply()
        }
    }

    /// HealthKit does not tell a refused read from nothing recorded, so this names both.
    private static let emptyMessage = "No Watch workouts found on this day.\n\nThe Watch can take a few minutes to hand a workout to the iPhone. If it should be here, check Coar's access in Settings › Health › Data Access & Devices."

    private func apply() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, HealthWorkout.ID>()
        snapshot.appendSections([0])
        snapshot.appendItems(rows.map(\.id))
        snapshot.reconfigureItems(rows.map(\.id))
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension HealthWorkoutPickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return }
        do {
            try dependencies.store.linkHealthWorkout(id, to: workout.id)
        } catch {
            Self.logger.error("Failed to link Health Workout: \(error, privacy: .public)")
            return
        }
        onLinked()
        dismiss(animated: true)
    }
}
