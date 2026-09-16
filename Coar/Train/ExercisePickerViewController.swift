import UIKit
import os

/// Picks one active Exercise for a Plan row: a filter field over the catalogue, with a
/// "New exercise" row that opens the Exercise sheet pre-filled with what was typed. Archived
/// Exercises are not offered. Reports the pick through `onPick`.
final class ExercisePickerViewController: UIViewController {

    private static let logger = Logger(category: "Train")

    private enum Item: Hashable {
        case new
        case exercise(ExerciseRecord.ID)
    }

    private let dependencies: AppDependencies
    private let onPick: (ExerciseRecord) -> Void
    private let filterField = UISearchTextField()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Item>!
    private var exercises: [ExerciseRecord.ID: ExerciseRecord] = [:]

    init(dependencies: AppDependencies, onPick: @escaping (ExerciseRecord) -> Void) {
        self.dependencies = dependencies
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
        title = "Add Exercise"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .never

        filterField.placeholder = "Filter"
        filterField.backgroundColor = UIColor.fill
        filterField.returnKeyType = .done
        filterField.addAction(UIAction { [weak self] _ in self?.render() }, for: .editingChanged)
        filterField.addAction(UIAction { [weak self] _ in self?.filterField.resignFirstResponder() }, for: .editingDidEndOnExit)
        filterField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterField)

        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.showsSeparators = false
        configuration.backgroundColor = .clear
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout.list(using: configuration))
        collectionView.backgroundColor = .clear
        collectionView.keyboardDismissMode = .onDrag
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
        let newCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, _ in
            let typed = self?.filter ?? ""
            let content = UIListContentConfiguration.addRow(typed.isEmpty ? "New exercise" : "New exercise “\(typed)”")
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .new:
                return collectionView.dequeueConfiguredReusableCell(using: newCell, for: indexPath, item: item)
            case .exercise(let id):
                return collectionView.dequeueConfiguredReusableCell(using: exerciseCell, for: indexPath, item: id)
            }
        }
        render()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        filterField.becomeFirstResponder()
    }

    private var filter: String {
        (filterField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func render() {
        let filter = filter
        let active: [ExerciseRecord]
        do {
            active = try dependencies.store.exercises().filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
        } catch {
            Self.logger.error("Failed to read Exercises: \(error, privacy: .public)")
            return
        }
        exercises = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        snapshot.appendItems(active.map { .exercise($0.id) } + [.new], toSection: 0)
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)
    }

    private func presentNewExercise() {
        let sheet = ExerciseFormViewController.sheet(dependencies: dependencies, mode: .create(name: filter)) { [weak self] exercise in
            self?.onPick(exercise)
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
            guard let exercise = exercises[id] else { return }
            onPick(exercise)
        case nil:
            break
        }
    }
}
