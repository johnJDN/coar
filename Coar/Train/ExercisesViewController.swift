import UIKit
import os

/// The Exercise catalogue, pushed from the Train root's Exercises chip: active Exercises by
/// name (tap to open the Exercise's detail page, where Edit lives), then an Archived section
/// (Restore, or the trash button to delete permanently). `+` opens the Exercise sheet. Reads through the façade on every
/// appearance and after every write.
final class ExercisesViewController: UIViewController {

    private static let logger = Logger(category: "Train")

    private enum Section: Hashable {
        case active, archived, empty
    }

    private enum Item: Hashable {
        case exercise(ExerciseRecord.ID)
        case archived(ExerciseRecord.ID)
        case empty
    }

    private let dependencies: AppDependencies
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var exercises: [ExerciseRecord.ID: ExerciseRecord] = [:]

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
        title = "Exercises"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .never

        let add = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in self?.presentForm(.create(name: "")) })
        add.accessibilityLabel = "New exercise"
        navigationItem.rightBarButtonItem = add

        configureCollectionView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    // MARK: - Collection view

    private func configureCollectionView() {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            configuration.showsSeparators = false
            configuration.backgroundColor = .clear
            configuration.headerMode = self?.dataSource.sectionIdentifier(for: sectionIndex) == .archived ? .supplementary : .none
            return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let exerciseCell = UICollectionView.CellRegistration<UICollectionViewListCell, ExerciseRecord.ID> { [weak self] cell, _, id in
            guard let exercise = self?.exercises[id] else { return }
            var content = UIListContentConfiguration.listRow()
            content.text = exercise.name
            content.secondaryText = TrainText.details(of: exercise)
            if exercise.isArchived {
                content.textProperties.color = UIColor.textSecondary
                content.secondaryText = TrainText.details(of: exercise)
            }
            cell.contentConfiguration = content
            if exercise.isArchived {
                let buttons = UIStackView(arrangedSubviews: [
                    DeletePermanently.restoreButton(for: exercise.name) { [weak self] in self?.restore(exercise) },
                    DeletePermanently.button(for: exercise.name) { [weak self] in self?.confirmDelete(exercise) },
                ])
                buttons.spacing = Metrics.spaceTight
                cell.accessories = [.customView(configuration: .init(customView: buttons, placement: .trailing(), reservedLayoutWidth: .actual))]
            } else {
                cell.accessories = [.disclosureIndicator()]
            }
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
            cell.accessibilityLabel = [content.text, content.secondaryText].compactMap { $0 }.joined(separator: ", ")
        }
        let emptyCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, _ in
            var content = UIListContentConfiguration.listRow()
            content.text = "—"
            content.textProperties.color = UIColor.textTertiary
            content.secondaryText = "Tap + to add your first exercise."
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
            cell.accessibilityLabel = "No exercises yet. Tap + to add your first exercise."
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { view, _, _ in
            var content = UIListContentConfiguration.groupedHeader()
            content.text = "Archived"
            view.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .exercise(let id), .archived(let id):
                return collectionView.dequeueConfiguredReusableCell(using: exerciseCell, for: indexPath, item: id)
            case .empty:
                return collectionView.dequeueConfiguredReusableCell(using: emptyCell, for: indexPath, item: item)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
    }

    // MARK: - Rendering

    private func render() {
        let active: [ExerciseRecord]
        let archived: [ExerciseRecord]
        do {
            active = try dependencies.store.exercises()
            archived = try dependencies.store.archivedExercises()
        } catch {
            Self.logger.error("Failed to read Exercises: \(error, privacy: .public)")
            return
        }
        exercises = Dictionary(uniqueKeysWithValues: (active + archived).map { ($0.id, $0) })

        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        if active.isEmpty && archived.isEmpty {
            snapshot.appendSections([.empty])
            snapshot.appendItems([.empty], toSection: .empty)
        } else {
            snapshot.appendSections([.active])
            snapshot.appendItems(active.map { .exercise($0.id) }, toSection: .active)
            if !archived.isEmpty {
                snapshot.appendSections([.archived])
                snapshot.appendItems(archived.map { .archived($0.id) }, toSection: .archived)
            }
        }
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)
    }

    // MARK: - Actions

    private func presentForm(_ mode: ExerciseFormViewController.Mode) {
        present(ExerciseFormViewController.sheet(dependencies: dependencies, mode: mode) { [weak self] _ in self?.render() }, animated: true)
    }

    /// The Plans that lose a row are named; Workouts keep their sets, the chart does not.
    private func confirmDelete(_ exercise: ExerciseRecord) {
        var consequences = ["Past workouts keep its sets, but its progression chart is deleted."]
        do {
            let plans = try dependencies.store.planNames(using: exercise.id)
            if !plans.isEmpty {
                consequences.append("It's also removed from \(DeletePermanently.list(plans)).")
            }
        } catch {
            Self.logger.error("Failed to read Plans using an Exercise: \(error, privacy: .public)")
        }
        let alert = DeletePermanently.confirmation(name: exercise.name, consequences: consequences) { [weak self] in
            guard let self else { return }
            do {
                try dependencies.store.deleteExercisePermanently(exercise.id)
            } catch {
                Self.logger.error("Failed to delete Exercise: \(error, privacy: .public)")
            }
            render()
        }
        present(alert, animated: true)
    }

    /// Restore is reversible (archive it again), so it does not confirm, like Habits.
    private func restore(_ exercise: ExerciseRecord) {
        do {
            try dependencies.store.restoreExercise(exercise.id)
        } catch {
            Self.logger.error("Failed to restore Exercise: \(error, privacy: .public)")
        }
        render()
    }
}

extension ExercisesViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .exercise(let id):
            navigationController?.pushViewController(ExerciseDetailViewController(dependencies: dependencies, exerciseID: id), animated: true)
        case .archived(let id):
            guard let exercise = exercises[id] else { return }
            restore(exercise)
        case .empty, nil:
            break
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        dataSource.itemIdentifier(for: indexPath) != .empty
    }
}
