import UIKit
import os

/// The "+" sheet (DESIGN.md §11): `SegmentedTabs` Describe / Foods / Meals. Describe, first
/// and the default, is `DescribeViewController`: type what was eaten and Add logs it. Foods
/// and Meals have a filter field and the user's catalogue as `ListRow`s. Tapping a Food Item goes on to pick a Serving and
/// quantity, tapping a Meal to set its multiplier; a row's trailing "+" logs the default
/// Serving, or the Meal, once at the sheet's time. Both lists run most recently used first.
/// "New food" / "New meal" open the editors; "Archived foods" / "Archived meals" open a page
/// to restore them from.
final class AddEntryViewController: UIViewController {

    private static let logger = Logger(category: "Food")

    private enum Segment: Int {
        case describe, foods, meals
    }

    private enum Section: Hashable {
        case catalogue, actions
    }

    private enum Item: Hashable {
        case foodItem(FoodItemRecord.ID)
        case newFood
        case archivedFoods
        case meal(MealRecord.ID)
        case newMeal
        case archivedMeals
    }

    private let dependencies: AppDependencies
    private let instant: Date
    private let onLogged: () -> Void
    private let tabs = SegmentedTabsView(titles: ["Describe", "Foods", "Meals"])
    private let describe: DescribeViewController
    private let addItem = UIBarButtonItem()
    private let moreItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"))
    private let cameraItem = UIBarButtonItem(image: UIImage(systemName: "camera"))
    private let filterField = UISearchTextField()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var segment = Segment.describe
    private var hasFocusedDescribe = false
    private var foodItems: [FoodItemRecord.ID: FoodItemRecord] = [:]
    private var meals: [MealRecord.ID: MealRecord] = [:]
    private var archivedCount = 0

    init(dependencies: AppDependencies, at instant: Date, onLogged: @escaping () -> Void) {
        self.dependencies = dependencies
        self.instant = instant
        self.onLogged = onLogged
        describe = DescribeViewController(dependencies: dependencies, at: instant, onLogged: onLogged)
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
        navigationItem.subtitle = FoodText.when(instant)
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })

        addItem.primaryAction = UIAction(title: "Add") { [weak self] _ in self?.addDescribed() }
        addItem.style = .prominent
        moreItem.accessibilityLabel = "More"
        cameraItem.accessibilityLabel = "Photo of food or a label"
        let take = UIAction(title: "Take Photo", image: UIImage(systemName: "camera"), attributes: DescribeViewController.canTakePhoto ? [] : [.disabled]) { [weak self] _ in
            self?.describe.takePhoto()
        }
        let choose = UIAction(title: "Choose Photo", image: UIImage(systemName: "photo.on.rectangle")) { [weak self] _ in
            self?.describe.choosePhoto()
        }
        cameraItem.menu = UIMenu(title: "Photo of food or a nutrition label", children: [take, choose])
        describe.onChange = { [weak self] in self?.updateAddItem() }

        tabs.onSelect = { [weak self] index in
            self?.show(Segment(rawValue: index) ?? .describe)
        }
        filterField.placeholder = "Filter"
        filterField.backgroundColor = UIColor.fill
        filterField.returnKeyType = .done
        filterField.addAction(UIAction { [weak self] _ in self?.render(reconfigure: false) }, for: .editingChanged)
        filterField.addAction(UIAction { [weak self] _ in self?.filterField.resignFirstResponder() }, for: .editingDidEndOnExit)

        let top = UIStackView(arrangedSubviews: [tabs, filterField])
        top.axis = .vertical
        top.spacing = Metrics.spaceTight
        top.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(top)

        configureCollectionView()
        addChild(describe)
        describe.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(describe.view)
        describe.didMove(toParent: self)
        NSLayoutConstraint.activate([
            describe.view.topAnchor.constraint(equalTo: top.bottomAnchor),
            describe.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            describe.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            describe.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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
        show(segment)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Describe opens ready to type, once; coming back from a pushed page leaves focus be.
        guard segment == .describe, !hasFocusedDescribe else { return }
        hasFocusedDescribe = true
        describe.focusFirstEmptyLine()
    }

    // MARK: - Describe

    private func show(_ segment: Segment) {
        if segment != self.segment { view.endEditing(true) }
        self.segment = segment
        let describing = segment == .describe
        describe.view.isHidden = !describing
        collectionView.isHidden = describing
        filterField.isHidden = describing
        navigationItem.rightBarButtonItems = describing ? [addItem, moreItem, cameraItem] : []
        updateAddItem()
        if !describing { render() }
    }

    private func updateAddItem() {
        addItem.isEnabled = describe.filledCount > 0
        let clear = UIAction(title: "Clear", image: UIImage(systemName: "trash"), attributes: describe.isEmpty ? [.disabled] : [.destructive]) { [weak self] _ in
            self?.describe.clear()
        }
        moreItem.menu = UIMenu(children: [clear])
    }

    /// Logs the filled lines; the sheet closes unless typed lines are left behind (still
    /// checking, waiting, or failed), which stay to be dealt with.
    private func addDescribed() {
        if !describe.addFilled() {
            dismiss(animated: true)
        }
    }

    // MARK: - Collection view

    private func configureCollectionView() {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.showsSeparators = false
        configuration.backgroundColor = .clear
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout.list(using: configuration))
        collectionView.backgroundColor = .clear
        collectionView.dismissesKeyboardOnDrag()
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        let foodItemCell = UICollectionView.CellRegistration<QuickAddListCell, FoodItemRecord.ID> { [weak self] cell, _, id in
            guard let self, let foodItem = foodItems[id] else { return }
            var content = UIListContentConfiguration.listRow()
            content.text = foodItem.name
            content.secondaryText = foodItem.defaultServing.map(FoodText.summary(of:))
            cell.contentConfiguration = content
            cell.configureQuickAdd(name: foodItem.name, isEnabled: true) { [weak self] in self?.quickAdd(id) }
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let mealCell = UICollectionView.CellRegistration<QuickAddListCell, MealRecord.ID> { [weak self] cell, _, id in
            guard let self, let meal = meals[id] else { return }
            var content = UIListContentConfiguration.listRow()
            content.text = meal.name
            if meal.isLoggable {
                content.secondaryAttributedText = FoodText.styledMacroLineUIKit(meal.macros)
            } else {
                // A line's Serving is gone, so the Meal would undercount: flagged here, and
                // its log page says what to do.
                content.image = UIImage(systemName: "exclamationmark.triangle.fill")
                content.imageProperties.tintColor = UIColor.accentCoral
                content.secondaryText = "Needs fixing · a serving was removed"
                content.secondaryTextProperties.color = UIColor.accentCoral
            }
            cell.contentConfiguration = content
            cell.configureQuickAdd(name: meal.name, isEnabled: meal.isLoggable) { [weak self] in self?.quickAddMeal(id) }
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let actionCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, item in
            var content = UIListContentConfiguration.addRow("")
            let typed = self?.filterText ?? ""
            switch item {
            case .newFood:
                content.text = typed.isEmpty ? "New food" : "New food “\(typed)”"
            case .newMeal:
                content.text = typed.isEmpty ? "New meal" : "New meal “\(typed)”"
            case .foodItem, .meal, .archivedFoods, .archivedMeals:
                break
            }
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let archivedLinkCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, item in
            var content = UIListContentConfiguration.listRow()
            content.text = item == .archivedMeals ? "Archived meals" : "Archived foods"
            content.textProperties.color = UIColor.textSecondary
            content.image = UIImage(systemName: "archivebox")
            content.imageProperties.tintColor = UIColor.textSecondary
            cell.contentConfiguration = content
            cell.accessories = [
                .label(text: "\(self?.archivedCount ?? 0)", options: .init(tintColor: UIColor.textSecondary)),
                .disclosureIndicator(options: .init(tintColor: UIColor.textTertiary)),
            ]
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .foodItem(let id):
                return collectionView.dequeueConfiguredReusableCell(using: foodItemCell, for: indexPath, item: id)
            case .meal(let id):
                return collectionView.dequeueConfiguredReusableCell(using: mealCell, for: indexPath, item: id)
            case .archivedFoods, .archivedMeals:
                return collectionView.dequeueConfiguredReusableCell(using: archivedLinkCell, for: indexPath, item: item)
            case .newFood, .newMeal:
                return collectionView.dequeueConfiguredReusableCell(using: actionCell, for: indexPath, item: item)
            }
        }
    }

    // MARK: - Rendering

    private var filterText: String {
        (filterField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Rebuilds the list. `reconfigure` refreshes rows that stay on screen (after an edit or
    /// a restore); a filter keystroke only adds and removes rows, so it skips that and the
    /// rows that stay are left untouched.
    private func render(reconfigure: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        switch segment {
        case .describe:
            return
        case .foods:
            let active: [FoodItemRecord]
            do {
                active = try dependencies.store.foodItems().filter { matchesFilter($0.name) }
                archivedCount = try dependencies.store.archivedFoodItems().count
            } catch {
                Self.logger.error("Failed to read Food Items: \(error, privacy: .public)")
                return
            }
            foodItems = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
            if !active.isEmpty {
                snapshot.appendSections([.catalogue])
                snapshot.appendItems(active.map { .foodItem($0.id) }, toSection: .catalogue)
            }
            snapshot.appendSections([.actions])
            snapshot.appendItems([.newFood] + (archivedCount > 0 && filterText.isEmpty ? [.archivedFoods] : []), toSection: .actions)
        case .meals:
            let active: [MealRecord]
            do {
                active = try dependencies.store.meals().filter { matchesFilter($0.name) }
                archivedCount = try dependencies.store.archivedMeals().count
            } catch {
                Self.logger.error("Failed to read Meals: \(error, privacy: .public)")
                return
            }
            meals = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
            if !active.isEmpty {
                snapshot.appendSections([.catalogue])
                snapshot.appendItems(active.map { .meal($0.id) }, toSection: .catalogue)
            }
            snapshot.appendSections([.actions])
            snapshot.appendItems([.newMeal] + (archivedCount > 0 && filterText.isEmpty ? [.archivedMeals] : []), toSection: .actions)
        }
        let animated = viewIfLoaded?.window != nil
        if reconfigure {
            dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: animated)
        } else {
            // "New food “…”" echoes the filter, so it is the one row a keystroke changes.
            snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { $0 == .newFood || $0 == .newMeal })
            dataSource.apply(snapshot, animatingDifferences: animated)
        }
    }

    private func matchesFilter(_ name: String) -> Bool {
        filterText.isEmpty || name.localizedCaseInsensitiveContains(filterText)
    }

    // MARK: - Actions

    private func quickAdd(_ id: FoodItemRecord.ID) {
        guard let serving = foodItems[id]?.defaultServing else { return }
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
        LogFoodItemViewController(dependencies: dependencies, foodItemID: id, at: instant) { [weak self] in
            self?.onLogged()
            self?.dismiss(animated: true)
        }
    }

    private func pushEditor(_ foodItem: FoodItemRecord?) {
        let mode: FoodItemEditorViewController.Mode = foodItem.map { .edit($0) } ?? .create(name: filterText)
        let editor = FoodItemEditorViewController(dependencies: dependencies, mode: mode) { [weak self] _ in self?.editorSaved(isNew: foodItem == nil) }
        navigationController?.pushViewController(editor, animated: true)
    }

    /// Where a Save in the food or meal editor lands when it was opened from this list.
    /// Creating is not logging, so a new one returns here, at the top of the list, ready to
    /// log. Editing from the list is the whole errand, so the sheet closes, back to the Food
    /// tab. (Editing from a log page's menu returns to that page; that page handles it.)
    private func editorSaved(isNew: Bool) {
        if isNew {
            navigationController?.popToViewController(self, animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func archive(_ id: FoodItemRecord.ID) {
        do {
            try dependencies.store.archiveFoodItem(id)
        } catch {
            Self.logger.error("Failed to archive Food Item: \(error, privacy: .public)")
        }
        render()
    }

    // MARK: - Meals

    private func quickAddMeal(_ id: MealRecord.ID) {
        guard meals[id]?.isLoggable == true else { return }
        do {
            try dependencies.store.logEntry(meal: id, quantity: 1, at: instant)
            onLogged()
            dismiss(animated: true)
        } catch {
            Self.logger.error("Failed to log Entry: \(error, privacy: .public)")
        }
    }

    private func makeLogMeal(_ id: MealRecord.ID) -> UIViewController {
        LogMealViewController(dependencies: dependencies, mealID: id, at: instant) { [weak self] in
            self?.onLogged()
            self?.dismiss(animated: true)
        }
    }

    private func pushMealEditor(_ meal: MealRecord?) {
        let mode: MealEditorViewController.Mode = meal.map { .edit($0) } ?? .create(name: filterText)
        let editor = MealEditorViewController(dependencies: dependencies, mode: mode) { [weak self] _ in self?.editorSaved(isNew: meal == nil) }
        navigationController?.pushViewController(editor, animated: true)
    }

    private func archiveMeal(_ id: MealRecord.ID) {
        do {
            try dependencies.store.archiveMeal(id)
        } catch {
            Self.logger.error("Failed to archive Meal: \(error, privacy: .public)")
        }
        render()
    }
}

extension AddEntryViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .foodItem(let id):
            pushLog(id)
        case .archivedFoods:
            filterField.resignFirstResponder()
            navigationController?.pushViewController(ArchivedCatalogueViewController(dependencies: dependencies, kind: .foods), animated: true)
        case .newFood:
            pushEditor(nil)
        case .meal(let id):
            navigationController?.pushViewController(makeLogMeal(id), animated: true)
        case .archivedMeals:
            filterField.resignFirstResponder()
            navigationController?.pushViewController(ArchivedCatalogueViewController(dependencies: dependencies, kind: .meals), animated: true)
        case .newMeal:
            pushMealEditor(nil)
        case nil:
            break
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        switch dataSource.itemIdentifier(for: indexPath) {
        case .foodItem(let id):
            guard let foodItem = foodItems[id] else { return nil }
            return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
                UIMenu(children: [
                    UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in self?.pushEditor(foodItem) },
                    UIAction(title: "Archive", image: UIImage(systemName: "archivebox")) { _ in self?.archive(id) },
                ])
            })
        case .meal(let id):
            guard let meal = meals[id] else { return nil }
            return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
                UIMenu(children: [
                    UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in self?.pushMealEditor(meal) },
                    UIAction(title: "Archive", image: UIImage(systemName: "archivebox")) { _ in self?.archiveMeal(id) },
                ])
            })
        default:
            return nil
        }
    }
}
