import UIKit
import os

/// The "+" sheet (DESIGN.md §11): `SegmentedTabs` Foods / Meals, a filter field, and the
/// user's catalogue as `ListRow`s. Tapping a Food Item goes on to pick a Serving and
/// quantity; its trailing "+" logs the default Serving once at the sheet's time. "New food"
/// opens the Food Item editor. Archived Food Items surface only under a matching filter, to
/// be restored. Meals arrive with a later ticket; the segment is present but empty.
final class AddEntryViewController: UIViewController {

    private static let logger = Logger(category: "Food")

    private enum Segment: Int {
        case foods, meals
    }

    private enum Section: Hashable {
        case foods, archived, actions, meals
    }

    private enum Item: Hashable {
        case food(FoodItemRecord.ID)
        case archived(FoodItemRecord.ID)
        case newFood
        case noMeals
    }

    private let dependencies: AppDependencies
    private let instant: Date
    private let onLogged: () -> Void
    private let tabs = SegmentedTabsView(titles: ["Foods", "Meals"])
    private let filterField = UISearchTextField()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var segment = Segment.foods
    private var foods: [FoodItemRecord.ID: FoodItemRecord] = [:]

    init(dependencies: AppDependencies, at instant: Date, onLogged: @escaping () -> Void) {
        self.dependencies = dependencies
        self.instant = instant
        self.onLogged = onLogged
        super.init(nibName: nil, bundle: nil)
        title = "Add Entry"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The sheet the Food tab presents; `at` is the instant the Entry will carry.
    static func sheet(dependencies: AppDependencies, at instant: Date, onLogged: @escaping () -> Void) -> UIViewController {
        AddEntryViewController(dependencies: dependencies, at: instant, onLogged: onLogged).inSheet(detents: [.large()])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.subtitle = Self.subtitle(for: instant)
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })

        tabs.onSelect = { [weak self] index in
            self?.segment = Segment(rawValue: index) ?? .foods
            self?.render()
        }
        filterField.placeholder = "Filter"
        filterField.backgroundColor = UIColor.fill
        filterField.returnKeyType = .done
        filterField.addAction(UIAction { [weak self] _ in self?.render() }, for: .editingChanged)
        filterField.addAction(UIAction { [weak self] _ in self?.filterField.resignFirstResponder() }, for: .editingDidEndOnExit)

        let top = UIStackView(arrangedSubviews: [tabs, filterField])
        top.axis = .vertical
        top.spacing = Metrics.spaceTight
        top.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(top)

        configureCollectionView()
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Metrics.spaceTight),
            top.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.spaceEdge),
            top.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.spaceEdge),
            collectionView.topAnchor.constraint(equalTo: top.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    /// "Today at 8:00 AM" / "Monday, September 7 at 12:00 PM".
    static func subtitle(for instant: Date) -> String {
        let day = Day(instant)
        let dayText = day == .today() ? "Today" : instant.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return "\(dayText) at \(instant.formatted(.dateTime.hour().minute()))"
    }

    // MARK: - Collection view

    private func configureCollectionView() {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.showsSeparators = false
        configuration.backgroundColor = .clear
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout.list(using: configuration))
        collectionView.backgroundColor = .clear
        collectionView.keyboardDismissMode = .onDrag
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        let foodCell = UICollectionView.CellRegistration<UICollectionViewListCell, FoodItemRecord.ID> { [weak self] cell, _, id in
            guard let self, let food = foods[id] else { return }
            var content = Self.rowContent()
            content.text = food.name
            content.secondaryText = food.defaultServing.map(FoodText.summary(of:))
            cell.contentConfiguration = content
            cell.accessories = [.customView(configuration: .init(customView: makeQuickAddButton(id), placement: .trailing()))]
            cell.backgroundConfiguration = Self.rowBackground()
        }
        let archivedCell = UICollectionView.CellRegistration<UICollectionViewListCell, FoodItemRecord.ID> { [weak self] cell, _, id in
            guard let self, let food = foods[id] else { return }
            var content = Self.rowContent()
            content.text = food.name
            content.textProperties.color = UIColor.textSecondary
            content.secondaryText = "Archived • Tap to restore"
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = Self.rowBackground()
        }
        let actionCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, item in
            var content = Self.rowContent()
            switch item {
            case .newFood:
                let typed = self?.filterText ?? ""
                content.text = typed.isEmpty ? "New food" : "New food “\(typed)”"
                content.image = UIImage(systemName: "plus.circle.fill")
                content.imageProperties.tintColor = UIColor.accentGreen
                content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .headline)
            case .noMeals:
                content.text = "No meals yet"
                content.textProperties.color = UIColor.textTertiary
            case .food, .archived:
                break
            }
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = Self.rowBackground()
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .food(let id):
                return collectionView.dequeueConfiguredReusableCell(using: foodCell, for: indexPath, item: id)
            case .archived(let id):
                return collectionView.dequeueConfiguredReusableCell(using: archivedCell, for: indexPath, item: id)
            case .newFood, .noMeals:
                return collectionView.dequeueConfiguredReusableCell(using: actionCell, for: indexPath, item: item)
            }
        }
    }

    /// A `ListRow` (DESIGN.md §7): title in the card-title style over a `label` subtitle.
    private static func rowContent() -> UIListContentConfiguration {
        var content = UIListContentConfiguration.subtitleCell()
        content.textProperties.font = UIFont.cardTitle
        content.textProperties.color = UIColor.textPrimary
        content.secondaryTextProperties.font = UIFont.label
        content.secondaryTextProperties.color = UIColor.textSecondary
        content.textToSecondaryTextVerticalPadding = 2
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: Metrics.spaceInner, bottom: 12, trailing: Metrics.spaceInner)
        return content
    }

    private static func rowBackground() -> UIBackgroundConfiguration {
        var background = UIBackgroundConfiguration.listCell()
        background.backgroundColor = UIColor.surface
        return background
    }

    /// The row's trailing square "+" (DESIGN.md §7 `ListRow`): logs the default Serving once.
    private func makeQuickAddButton(_ id: FoodItemRecord.ID) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold))
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = Metrics.radiusTile
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.contentInsets = .zero
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in self?.quickAdd(id) })
        button.accessibilityLabel = "Add \(foods[id]?.name ?? "") now"
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32),
        ])
        return button
    }

    // MARK: - Rendering

    private var filterText: String {
        (filterField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func render() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        switch segment {
        case .foods:
            let active: [FoodItemRecord]
            let archived: [FoodItemRecord]
            do {
                active = try dependencies.store.foodItems().filter(matchesFilter)
                archived = filterText.isEmpty ? [] : try dependencies.store.archivedFoodItems().filter(matchesFilter)
            } catch {
                Self.logger.error("Failed to read Food Items: \(error, privacy: .public)")
                return
            }
            foods = Dictionary(uniqueKeysWithValues: (active + archived).map { ($0.id, $0) })
            if !active.isEmpty {
                snapshot.appendSections([.foods])
                snapshot.appendItems(active.map { .food($0.id) }, toSection: .foods)
            }
            if !archived.isEmpty {
                snapshot.appendSections([.archived])
                snapshot.appendItems(archived.map { .archived($0.id) }, toSection: .archived)
            }
            snapshot.appendSections([.actions])
            snapshot.appendItems([.newFood], toSection: .actions)
        case .meals:
            snapshot.appendSections([.meals])
            snapshot.appendItems([.noMeals], toSection: .meals)
        }
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)
    }

    private func matchesFilter(_ food: FoodItemRecord) -> Bool {
        filterText.isEmpty || food.name.localizedCaseInsensitiveContains(filterText)
    }

    // MARK: - Actions

    private func quickAdd(_ id: FoodItemRecord.ID) {
        guard let food = foods[id], let serving = food.defaultServing else { return }
        do {
            try dependencies.store.logEntry(foodItem: id, serving: serving.id, quantity: 1, at: instant)
            onLogged()
            dismiss(animated: true)
        } catch {
            Self.logger.error("Failed to log Entry: \(error, privacy: .public)")
        }
    }

    private func pushLog(_ id: FoodItemRecord.ID) {
        navigationController?.pushViewController(makeLog(id), animated: true)
    }

    private func makeLog(_ id: FoodItemRecord.ID) -> UIViewController {
        LogFoodViewController(dependencies: dependencies, foodItemID: id, at: instant) { [weak self] in
            self?.onLogged()
            self?.dismiss(animated: true)
        }
    }

    private func pushEditor(_ food: FoodItemRecord?) {
        let mode: FoodItemEditorViewController.Mode = food.map { .edit($0) } ?? .create(name: filterText)
        let editor = FoodItemEditorViewController(dependencies: dependencies, mode: mode) { [weak self] saved in
            guard let self, let navigation = navigationController else { return }
            // A new Food Item goes straight on to being logged; an edit returns to the list.
            if food == nil {
                navigation.setViewControllers([self, makeLog(saved.id)], animated: true)
            } else {
                navigation.popViewController(animated: true)
            }
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    private func archive(_ id: FoodItemRecord.ID) {
        do {
            try dependencies.store.archiveFoodItem(id)
        } catch {
            Self.logger.error("Failed to archive Food Item: \(error, privacy: .public)")
        }
        render()
    }

    private func confirmRestore(_ food: FoodItemRecord) {
        let alert = UIAlertController(title: "Restore \(food.name)?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Restore", style: .default) { [weak self] _ in
            guard let self else { return }
            do {
                try dependencies.store.restoreFoodItem(food.id)
            } catch {
                Self.logger.error("Failed to restore Food Item: \(error, privacy: .public)")
            }
            render()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

extension AddEntryViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .food(let id):
            pushLog(id)
        case .archived(let id):
            if let food = foods[id] { confirmRestore(food) }
        case .newFood:
            pushEditor(nil)
        case .noMeals, nil:
            break
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        dataSource.itemIdentifier(for: indexPath) != .noMeals
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard case .food(let id) = dataSource.itemIdentifier(for: indexPath), let food = foods[id] else { return nil }
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
            UIMenu(children: [
                UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in self?.pushEditor(food) },
                UIAction(title: "Archive", image: UIImage(systemName: "archivebox")) { _ in self?.archive(id) },
            ])
        })
    }
}
