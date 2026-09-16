import UIKit
import os

/// Picks one active Food Item for a Meal line: a filter field over the catalogue as
/// `ListRow`s, each with its default Serving's line. Reports the pick through `onPick`.
final class FoodItemPickerViewController: UIViewController {

    private static let logger = Logger(category: "Food")

    private let dependencies: AppDependencies
    private let onPick: (FoodItemRecord) -> Void
    private let filterField = UISearchTextField()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, FoodItemRecord.ID>!
    private var foodItems: [FoodItemRecord.ID: FoodItemRecord] = [:]

    init(dependencies: AppDependencies, onPick: @escaping (FoodItemRecord) -> Void) {
        self.dependencies = dependencies
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
        title = "Add Food"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background

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

        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, FoodItemRecord.ID> { [weak self] cell, _, id in
            guard let foodItem = self?.foodItems[id] else { return }
            var content = UIListContentConfiguration.listRow()
            content.text = foodItem.name
            content.secondaryText = foodItem.defaultServing.map(FoodText.summary(of:))
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: id)
        }
        render()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        filterField.becomeFirstResponder()
    }

    private func render() {
        let filter = (filterField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let active: [FoodItemRecord]
        do {
            active = try dependencies.store.foodItems().filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
        } catch {
            Self.logger.error("Failed to read Food Items: \(error, privacy: .public)")
            return
        }
        foodItems = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
        var snapshot = NSDiffableDataSourceSnapshot<Int, FoodItemRecord.ID>()
        snapshot.appendSections([0])
        snapshot.appendItems(active.map(\.id), toSection: 0)
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)
    }
}

extension FoodItemPickerViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath), let foodItem = foodItems[id] else { return }
        onPick(foodItem)
    }
}
