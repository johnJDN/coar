import UIKit
import os

/// Adds Exercises, with a filter field over the user's catalogue and the built-in library
/// (`ExerciseLibrary`, one section per muscle group; the filter matches a name or a group).
/// Archived Exercises are not offered, and nor is a library entry the user already has.
/// Two modes:
/// - **pick** (a Plan row, a Workout): your exercises, "New exercise" (the Exercise sheet
///   pre-filled with what was typed), then the library; tapping a library entry copies it into
///   the catalogue and picks it. Reports the pick through `onPick`.
/// - **catalogue** (Exercises → +): "New exercise", then the library; each tap copies an entry
///   and the sheet stays open, so a whole set-up is a run of taps. Done closes it.
final class ExercisePickerViewController: UIViewController {

    enum Mode {
        case pick((ExerciseRecord) -> Void)
        case catalogue(onAdded: () -> Void)
    }

    private static let logger = Logger(category: "Train")

    private enum Section: Hashable {
        case yours
        case library(MuscleGroup)
    }

    private enum Item: Hashable {
        case new
        case exercise(ExerciseRecord.ID)
        case library(String)
    }

    private let dependencies: AppDependencies
    private let mode: Mode
    private let filterField = UISearchTextField()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var exercises: [ExerciseRecord.ID: ExerciseRecord] = [:]
    private var libraryEntries: [String: ExerciseLibrary.Entry] = [:]

    init(dependencies: AppDependencies, mode: Mode) {
        self.dependencies = dependencies
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
        switch mode {
        case .pick: title = "Add Exercise"
        case .catalogue: title = "Add Exercises"
        }
    }

    convenience init(dependencies: AppDependencies, onPick: @escaping (ExerciseRecord) -> Void) {
        self.init(dependencies: dependencies, mode: .pick(onPick))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Exercises → +: the catalogue mode in a sheet with Done.
    static func catalogueSheet(dependencies: AppDependencies, onAdded: @escaping () -> Void) -> UIViewController {
        let picker = ExercisePickerViewController(dependencies: dependencies, mode: .catalogue(onAdded: onAdded))
        picker.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak picker] _ in
            picker?.dismiss(animated: true)
        })
        return picker.inSheet(detents: [.large()])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .never

        filterField.placeholder = "Filter by name or muscle"
        filterField.backgroundColor = UIColor.fill
        filterField.returnKeyType = .done
        filterField.addAction(UIAction { [weak self] _ in self?.render() }, for: .editingChanged)
        filterField.addAction(UIAction { [weak self] _ in self?.filterField.resignFirstResponder() }, for: .editingDidEndOnExit)
        filterField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterField)

        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            configuration.showsSeparators = false
            configuration.backgroundColor = .clear
            if case .library = self?.dataSource.sectionIdentifier(for: sectionIndex) {
                configuration.headerMode = .supplementary
            }
            return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dismissesKeyboardOnDrag()
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            filterField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Metrics.spaceTight),
            filterField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.spaceEdge),
            filterField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.spaceEdge),
            collectionView.topAnchor.constraint(equalTo: filterField.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let exerciseCell = UICollectionView.CellRegistration<UICollectionViewListCell, ExerciseRecord.ID> { [weak self] cell, _, id in
            guard let exercise = self?.exercises[id] else { return }
            var content = UIListContentConfiguration.listRow()
            content.text = exercise.name
            content.secondaryText = TrainText.details(of: exercise)
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let libraryCell = UICollectionView.CellRegistration<QuickAddListCell, String> { [weak self] cell, _, name in
            guard let entry = self?.libraryEntries[name] else { return }
            var content = UIListContentConfiguration.listRow()
            content.text = entry.name
            content.secondaryText = ExerciseLibrary.details(of: entry)
            cell.contentConfiguration = content
            cell.configureQuickAdd(name: entry.name, isEnabled: true) { [weak self] in self?.add(entry) }
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let newCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, _ in
            let typed = self?.filter ?? ""
            let content = UIListContentConfiguration.addRow(typed.isEmpty ? "New exercise" : "New exercise “\(typed)”")
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] view, _, indexPath in
            var content = UIListContentConfiguration.groupedHeader()
            if case .library(let group) = self?.dataSource.sectionIdentifier(for: indexPath.section) {
                content.text = indexPath.section == self?.firstLibrarySection ? "Library · \(group.title)" : group.title
            }
            view.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .new:
                return collectionView.dequeueConfiguredReusableCell(using: newCell, for: indexPath, item: item)
            case .exercise(let id):
                return collectionView.dequeueConfiguredReusableCell(using: exerciseCell, for: indexPath, item: id)
            case .library(let name):
                return collectionView.dequeueConfiguredReusableCell(using: libraryCell, for: indexPath, item: name)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
        render()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if case .pick = mode {
            filterField.becomeFirstResponder()
        }
    }

    private var filter: String {
        (filterField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The index of the first library section, whose header also says "Library".
    private var firstLibrarySection: Int? {
        dataSource.snapshot().sectionIdentifiers.firstIndex { if case .library = $0 { return true } else { return false } }
    }

    private func render() {
        let filter = filter
        let active: [ExerciseRecord]
        let archived: [ExerciseRecord]
        do {
            active = try dependencies.store.exercises()
            archived = try dependencies.store.archivedExercises()
        } catch {
            Self.logger.error("Failed to read Exercises: \(error, privacy: .public)")
            return
        }
        let matching = active.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) || $0.muscleGroup.title.localizedCaseInsensitiveContains(filter) }
        exercises = Dictionary(uniqueKeysWithValues: matching.map { ($0.id, $0) })
        let offered = ExerciseLibrary.offered(excluding: (active + archived).map(\.name), filter: filter)
        libraryEntries = Dictionary(uniqueKeysWithValues: offered.flatMap(\.entries).map { ($0.name, $0) })

        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.yours])
        switch mode {
        case .pick:
            snapshot.appendItems(matching.map { .exercise($0.id) } + [.new], toSection: .yours)
        case .catalogue:
            snapshot.appendItems([.new], toSection: .yours)
        }
        for (group, entries) in offered {
            snapshot.appendSections([.library(group)])
            snapshot.appendItems(entries.map { .library($0.name) }, toSection: .library(group))
        }
        // Headers name the first library section "Library · …", which moves as sections come and go.
        snapshot.reloadSections(snapshot.sectionIdentifiers.filter { $0 != .yours })
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)
    }

    /// Copies a library entry into the catalogue; picks it, or (catalogue) stays for the next.
    private func add(_ entry: ExerciseLibrary.Entry) {
        let exercise: ExerciseRecord
        do {
            exercise = try ExerciseLibrary.add(entry, to: dependencies.store)
        } catch {
            Self.logger.error("Failed to add a library Exercise: \(error, privacy: .public)")
            return
        }
        switch mode {
        case .pick(let onPick):
            onPick(exercise)
        case .catalogue(let onAdded):
            onAdded()
            render()
        }
    }

    private func presentNewExercise() {
        let sheet = ExerciseFormViewController.sheet(dependencies: dependencies, mode: .create(name: filter)) { [weak self] exercise in
            guard let self else { return }
            switch mode {
            case .pick(let onPick):
                onPick(exercise)
            case .catalogue(let onAdded):
                onAdded()
                filterField.text = ""
                render()
            }
        }
        present(sheet, animated: true)
    }
}

extension ExercisePickerViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .new:
            presentNewExercise()
        case .exercise(let id):
            guard let exercise = exercises[id], case .pick(let onPick) = mode else { return }
            onPick(exercise)
        case .library(let name):
            guard let entry = libraryEntries[name] else { return }
            add(entry)
        case nil:
            break
        }
    }
}
