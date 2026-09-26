import SwiftUI
import UIKit
import os

/// The Meal editor, pushed inside the "+" sheet: the name, then the lines as reorderable
/// rows (drag the handle; swipe to delete; tap to change the Serving or quantity) and an
/// Add food row that picks a Food Item from the catalogue. A new Meal has Save; an existing
/// one saves as it changes (`EditorSaving`) and has Done, which hands it to `onSaved` so the
/// caller decides where to land. Entries logged before keep their own copy (ADR 0003).
final class MealEditorViewController: UIViewController {

    enum Mode {
        case create(name: String)
        case edit(MealRecord)
    }

    private static let logger = Logger(category: "Food")

    private enum Section: Hashable {
        case name, total, components
    }

    private enum Item: Hashable {
        case name
        /// The Meal's macros so far as a `MacroStrip`, updated as lines change.
        case total
        case component(MealComponentDraft.ID)
        case addFood
    }

    private let dependencies: AppDependencies
    private let mode: Mode
    private let onSaved: (MealRecord) -> Void
    private var draft: MealDraft
    /// The Food Items the lines point at, read as the editor renders (archived ones too, so a
    /// line whose Food Item has been archived still shows).
    private var foodItems: [FoodItemRecord.ID: FoodItemRecord] = [:]
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private let saveItem = UIBarButtonItem(systemItem: .save)
    private var hasAppeared = false
    /// What the store holds, for an existing Meal.
    private var saved: MealDraft
    private lazy var autosaver = Autosaver { [weak self] in self?.autosave() }
    private var backGuard: BackGuard?

    init(dependencies: AppDependencies, mode: Mode, onSaved: @escaping (MealRecord) -> Void) {
        self.dependencies = dependencies
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create(let name):
            draft = MealDraft(name: name)
        case .edit(let meal):
            draft = MealDraft(name: meal.name, components: meal.components.map(MealComponentDraft.init))
        }
        saved = draft
        super.init(nibName: nil, bundle: nil)
        switch mode {
        case .create: title = "New Meal"
        case .edit: title = "Edit Meal"
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        switch mode {
        case .create:
            saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
            navigationItem.rightBarButtonItem = saveItem
        case .edit:
            navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.done() })
        }
        backGuard = BackGuard(controller: self) { [weak self] in self?.backVerdict() ?? .leave }
        configureCollectionView()
        render()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        autosaver.flush()
        backGuard?.release()
    }

    /// A new Meal starts in the name field, once; popping back from the picker leaves the
    /// keyboard down.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        backGuard?.refresh()
        defer { hasAppeared = true }
        if !hasAppeared, case .create = mode, let cell = nameCell() {
            cell.field.becomeFirstResponder()
        }
    }

    // MARK: - Collection view

    private func configureCollectionView() {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            configuration.showsSeparators = false
            configuration.backgroundColor = .clear
            configuration.headerMode = self?.dataSource.sectionIdentifier(for: sectionIndex) == .name ? .none : .supplementary
            configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                guard case .component(let id) = self?.dataSource.itemIdentifier(for: indexPath) else { return nil }
                return UISwipeActionsConfiguration(actions: [
                    UIContextualAction(style: .destructive, title: "Delete") { _, _, done in
                        self?.draft.remove(id)
                        self?.render()
                        done(true)
                    },
                ])
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
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let nameCell = UICollectionView.CellRegistration<TextFieldCell, Item> { [weak self] cell, _, _ in
            guard let self else { return }
            cell.field.placeholder = "Name"
            if !cell.field.isFirstResponder { cell.field.text = draft.name }
            cell.field.accessibilityLabel = "Name"
            cell.onChange = { [weak self] text in
                self?.draft.name = text
                self?.draftChanged()
            }
        }
        let componentCell = UICollectionView.CellRegistration<UICollectionViewListCell, MealComponentDraft.ID> { [weak self] cell, _, id in
            guard let self, let component = draft.components.first(where: { $0.id == id }) else { return }
            let foodItem = foodItems[component.foodItemID]
            let serving = foodItem?.serving(component.servingID)
            var content = UIListContentConfiguration.listRow()
            content.text = foodItem?.name ?? "—"
            if let serving {
                content.secondaryText = "\(FoodText.quantity(component.quantity, of: serving.name)) · \(FoodText.calories(serving.macros.scaled(by: component.quantity)))"
            } else {
                content.secondaryText = "Serving removed · tap to pick another"
                content.secondaryTextProperties.color = UIColor.accentCoral
                content.image = UIImage(systemName: "exclamationmark.triangle.fill")
                content.imageProperties.tintColor = UIColor.accentCoral
            }
            cell.contentConfiguration = content
            cell.accessories = [.reorder(displayed: .always, options: .init(showsVerticalSeparator: false))]
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
            cell.accessibilityLabel = [content.text, content.secondaryText].compactMap { $0 }.joined(separator: ", ")
        }
        let totalCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, _ in
            guard let self else { return }
            let macros = draft.components.isEmpty ? nil : draft.macros(in: foodItems)
            cell.contentConfiguration = UIHostingConfiguration { MacroStrip(macros: macros) }
                .margins(.all, Metrics.spaceInner)
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let addCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, _ in
            let content = UIListContentConfiguration.addRow("Add food")
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] view, _, indexPath in
            var content = UIListContentConfiguration.groupedHeader()
            content.text = self?.dataSource.sectionIdentifier(for: indexPath.section) == .total ? "Total" : "Foods"
            view.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .name:
                return collectionView.dequeueConfiguredReusableCell(using: nameCell, for: indexPath, item: item)
            case .total:
                return collectionView.dequeueConfiguredReusableCell(using: totalCell, for: indexPath, item: item)
            case .component(let id):
                return collectionView.dequeueConfiguredReusableCell(using: componentCell, for: indexPath, item: id)
            case .addFood:
                return collectionView.dequeueConfiguredReusableCell(using: addCell, for: indexPath, item: item)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
        dataSource.reorderingHandlers.canReorderItem = { item in
            if case .component = item { return true }
            return false
        }
        dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
            let ids = transaction.finalSnapshot.itemIdentifiers(inSection: .components).compactMap { item -> MealComponentDraft.ID? in
                if case .component(let id) = item { return id }
                return nil
            }
            self?.draft.reorder(ids)
        }
    }

    private func nameCell() -> TextFieldCell? {
        dataSource.indexPath(for: .name).flatMap { collectionView.cellForItem(at: $0) as? TextFieldCell }
    }

    // MARK: - Rendering

    private func render() {
        loadFoodItems()
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.name, .total, .components])
        snapshot.appendItems([.name], toSection: .name)
        snapshot.appendItems([.total], toSection: .total)
        snapshot.appendItems(draft.components.map { .component($0.id) } + [.addFood], toSection: .components)
        snapshot.reloadSections([.total, .components])
        dataSource.apply(snapshot, animatingDifferences: viewIfLoaded?.window != nil)
        draftChanged()
    }

    private func loadFoodItems() {
        for id in Set(draft.components.map(\.foodItemID)) {
            do {
                foodItems[id] = try dependencies.store.foodItem(id)
            } catch {
                Self.logger.error("Failed to read Food Item: \(error, privacy: .public)")
            }
        }
    }

    /// Saveable: a name, a line, and every line's Food Item still there.
    private var canSave: Bool {
        draft.isComplete && draft.components.allSatisfy { foodItems[$0.foodItemID] != nil }
    }

    /// After every change: a new Meal's Save follows `canSave`; an existing one saves.
    private func draftChanged() {
        switch mode {
        case .create: saveItem.isEnabled = canSave
        case .edit: if canSave, draft != saved { autosaver.schedule() }
        }
        backGuard?.refresh()
    }

    private func autosave() {
        guard case .edit(let meal) = mode, canSave, draft != saved else { return }
        do {
            try dependencies.store.updateMeal(meal.id, name: draft.trimmedName, components: draft.components)
            saved = draft
        } catch {
            Self.logger.error("Failed to save Meal: \(error, privacy: .public)")
        }
    }

    /// An existing Meal's Done: saved already, so it hands over the stored one.
    private func done() {
        guard case .edit(let meal) = mode else { return }
        guard canSave else {
            if case .ask(let title, let message, _) = backVerdict() {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                present(alert, animated: true)
            }
            return
        }
        autosaver.flush()
        if let stored = try? dependencies.store.meal(meal.id) { onSaved(stored) }
    }

    private func backVerdict() -> BackGuard.Verdict {
        switch mode {
        case .create(let name):
            return draft == MealDraft(name: name) ? .leave : .ask(title: "Discard this meal?", message: nil, discard: "Discard")
        case .edit:
            return canSave ? .leave : .ask(
                title: "A meal needs a name and a food with a serving",
                message: "Go back without these changes? The meal stays as it was last saved.",
                discard: "Discard Changes"
            )
        }
    }

    // MARK: - Actions

    private func pushComponentForm(foodItem: FoodItemRecord, component: MealComponentDraft?) {
        navigationController?.pushViewController(makeComponentForm(foodItem: foodItem, component: component), animated: true)
    }

    private func makeComponentForm(foodItem: FoodItemRecord, component: MealComponentDraft?) -> UIViewController {
        MealComponentFormViewController(foodItem: foodItem, component: component) { [weak self] changed in
            guard let self else { return }
            foodItems[foodItem.id] = foodItem
            draft.upsert(changed)
            render()
        }
    }

    /// Picking a Food Item opens its new line in the picker's place, so back from the line
    /// returns here with it added.
    private func pushPicker() {
        let picker = FoodItemPickerViewController(dependencies: dependencies) { [weak self] foodItem in
            guard let self, let navigation = navigationController else { return }
            let form = makeComponentForm(foodItem: foodItem, component: nil)
            navigation.setViewControllers(Array(navigation.viewControllers.dropLast()) + [form], animated: true)
        }
        navigationController?.pushViewController(picker, animated: true)
    }

    /// A new Meal's Save.
    private func save() {
        guard case .create(let name) = mode, canSave else { return }
        do {
            let created = try dependencies.store.createMeal(name: draft.trimmedName, components: draft.components)
            draft = MealDraft(name: name)
            onSaved(created)
        } catch {
            Self.logger.error("Failed to save Meal: \(error, privacy: .public)")
        }
    }
}

extension MealEditorViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .component(let id):
            guard let component = draft.components.first(where: { $0.id == id }), let foodItem = foodItems[component.foodItemID] else { return }
            pushComponentForm(foodItem: foodItem, component: component)
        case .addFood:
            pushPicker()
        case .name, .total, nil:
            break
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        dataSource.itemIdentifier(for: indexPath) != .name
    }

    /// Reordering stays among the lines, above Add food.
    func collectionView(
        _ collectionView: UICollectionView,
        targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath,
        atCurrentIndexPath currentIndexPath: IndexPath,
        toProposedIndexPath proposedIndexPath: IndexPath
    ) -> IndexPath {
        IndexPath.reorderTarget(original: originalIndexPath, proposed: proposedIndexPath, lastReorderable: draft.components.count - 1)
    }
}
