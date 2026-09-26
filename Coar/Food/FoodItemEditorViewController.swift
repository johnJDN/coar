import UIKit
import os

/// The Food Item editor, pushed inside the "+" sheet: the name, then the Servings as
/// reorderable rows (drag the handle; swipe to delete; tap to edit) and an Add serving row.
/// A new Food Item has Save; an existing one saves as it changes (`EditorSaving`) and has
/// Done, which hands it to `onSaved` so the caller decides where to land. Entries logged
/// before keep their own copy of everything (ADR 0003).
final class FoodItemEditorViewController: UIViewController {

    enum Mode {
        case create(name: String)
        case edit(FoodItemRecord)
    }

    private static let logger = Logger(category: "Food")

    private enum Section: Hashable {
        case name, servings
    }

    private enum Item: Hashable {
        case name
        case serving(ServingDraft.ID)
        case addServing
    }

    private let dependencies: AppDependencies
    private let mode: Mode
    private let onSaved: (FoodItemRecord) -> Void
    private var draft: FoodItemDraft
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private let saveItem = UIBarButtonItem(systemItem: .save)
    private var hasAppeared = false
    /// What the store holds, for an existing Food Item.
    private var saved: FoodItemDraft
    private lazy var autosaver = Autosaver { [weak self] in self?.autosave() }
    private var backGuard: BackGuard?

    init(dependencies: AppDependencies, mode: Mode, onSaved: @escaping (FoodItemRecord) -> Void) {
        self.dependencies = dependencies
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create(let name):
            draft = FoodItemDraft(name: name)
        case .edit(let foodItem):
            draft = FoodItemDraft(name: foodItem.name, servings: foodItem.servings.map(ServingDraft.init))
        }
        saved = draft
        super.init(nibName: nil, bundle: nil)
        switch mode {
        case .create: title = "New Food"
        case .edit: title = "Edit Food"
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

    /// A new Food Item starts in the name field, once; popping back from the Serving form
    /// leaves the keyboard down.
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
            configuration.headerMode = self?.dataSource.sectionIdentifier(for: sectionIndex) == .servings ? .supplementary : .none
            configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                guard case .serving(let id) = self?.dataSource.itemIdentifier(for: indexPath) else { return nil }
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
            // A re-render while the user is typing must not move the cursor.
            if !cell.field.isFirstResponder { cell.field.text = draft.name }
            cell.field.accessibilityLabel = "Name"
            cell.onChange = { [weak self] text in
                self?.draft.name = text
                self?.draftChanged()
            }
        }
        let servingCell = UICollectionView.CellRegistration<UICollectionViewListCell, ServingDraft.ID> { [weak self] cell, _, id in
            guard let serving = self?.draft.servings.first(where: { $0.id == id }) else { return }
            var content = UIListContentConfiguration.listRow()
            content.text = Self.title(for: serving)
            content.secondaryAttributedText = FoodText.styledMacroLineUIKit(serving.macros)
            cell.contentConfiguration = content
            var accessories: [UICellAccessory] = [.reorder(displayed: .always, options: .init(showsVerticalSeparator: false))]
            if serving.isDefault {
                accessories.insert(.checkmark(displayed: .always, options: .init(tintColor: UIColor.accentGreen)), at: 0)
            }
            cell.accessories = accessories
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
            cell.accessibilityLabel = [serving.name, FoodText.macroLine(serving.macros), serving.isDefault ? "default" : nil].compactMap { $0 }.joined(separator: ", ")
        }
        let addCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, _ in
            let content = UIListContentConfiguration.addRow("Add serving")
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { view, _, _ in
            var content = UIListContentConfiguration.groupedHeader()
            content.text = "Servings"
            view.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .name:
                return collectionView.dequeueConfiguredReusableCell(using: nameCell, for: indexPath, item: item)
            case .serving(let id):
                return collectionView.dequeueConfiguredReusableCell(using: servingCell, for: indexPath, item: id)
            case .addServing:
                return collectionView.dequeueConfiguredReusableCell(using: addCell, for: indexPath, item: item)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
        dataSource.reorderingHandlers.canReorderItem = { item in
            if case .serving = item { return true }
            return false
        }
        dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
            let ids = transaction.finalSnapshot.itemIdentifiers(inSection: .servings).compactMap { item -> ServingDraft.ID? in
                if case .serving(let id) = item { return id }
                return nil
            }
            self?.draft.reorder(ids)
        }
    }

    /// "1 egg · 50 g"; a Serving named by its weight ("100 g") is not told it twice.
    private static func title(for serving: ServingDraft) -> String {
        guard let grams = serving.grams else { return serving.name }
        let weight = "\(FoodText.amount(grams)) g"
        return serving.name.localizedCaseInsensitiveContains(weight) ? serving.name : "\(serving.name) · \(weight)"
    }

    private func nameCell() -> TextFieldCell? {
        dataSource.indexPath(for: .name).flatMap { collectionView.cellForItem(at: $0) as? TextFieldCell }
    }

    // MARK: - Rendering

    private func render() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.name, .servings])
        snapshot.appendItems([.name], toSection: .name)
        snapshot.appendItems(draft.servings.map { .serving($0.id) } + [.addServing], toSection: .servings)
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)
        draftChanged()
    }

    /// After every change: a new Food Item's Save follows completeness; an existing one saves.
    private func draftChanged() {
        switch mode {
        case .create: saveItem.isEnabled = draft.isComplete
        case .edit: if draft.isComplete, draft != saved { autosaver.schedule() }
        }
        backGuard?.refresh()
    }

    private func autosave() {
        guard case .edit(let foodItem) = mode, draft.isComplete, draft != saved else { return }
        do {
            try dependencies.store.updateFoodItem(foodItem.id, name: draft.trimmedName, servings: draft.servings)
            saved = draft
        } catch {
            Self.logger.error("Failed to save Food Item: \(error, privacy: .public)")
        }
    }

    /// An existing Food Item's Done: saved already, so it hands over the stored one.
    private func done() {
        guard case .edit(let foodItem) = mode else { return }
        guard draft.isComplete else {
            if case .ask(let title, let message, _) = backVerdict() {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                present(alert, animated: true)
            }
            return
        }
        autosaver.flush()
        if let stored = try? dependencies.store.foodItem(foodItem.id) { onSaved(stored) }
    }

    private func backVerdict() -> BackGuard.Verdict {
        switch mode {
        case .create(let name):
            return draft == FoodItemDraft(name: name) ? .leave : .ask(title: "Discard this food?", message: nil, discard: "Discard")
        case .edit:
            return draft.isComplete ? .leave : .ask(
                title: "A food needs a name and a serving",
                message: "Go back without these changes? The food stays as it was last saved.",
                discard: "Discard Changes"
            )
        }
    }

    // MARK: - Actions

    private func pushServingForm(_ serving: ServingDraft?) {
        let form = ServingFormViewController(serving: serving, isFirst: draft.servings.isEmpty) { [weak self] changed in
            self?.draft.upsert(changed)
            self?.render()
        }
        navigationController?.pushViewController(form, animated: true)
    }

    /// A new Food Item's Save.
    private func save() {
        guard case .create(let name) = mode, draft.isComplete else { return }
        do {
            let created = try dependencies.store.createFoodItem(name: draft.trimmedName, servings: draft.servings)
            draft = FoodItemDraft(name: name)
            onSaved(created)
        } catch {
            Self.logger.error("Failed to save Food Item: \(error, privacy: .public)")
        }
    }
}

extension FoodItemEditorViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .serving(let id):
            pushServingForm(draft.servings.first { $0.id == id })
        case .addServing:
            pushServingForm(nil)
        case .name, nil:
            break
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        dataSource.itemIdentifier(for: indexPath) != .name
    }

    /// Reordering stays among the Serving rows, above Add serving.
    func collectionView(
        _ collectionView: UICollectionView,
        targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath,
        atCurrentIndexPath currentIndexPath: IndexPath,
        toProposedIndexPath proposedIndexPath: IndexPath
    ) -> IndexPath {
        IndexPath.reorderTarget(original: originalIndexPath, proposed: proposedIndexPath, lastReorderable: draft.servings.count - 1)
    }
}

/// A list row holding one text field in the card-title style; reports edits through
/// `onChange`.
final class TextFieldCell: UICollectionViewListCell {

    let field = UITextField()
    var onChange: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        field.font = UIFont.cardTitle
        field.textColor = UIColor.textPrimary
        field.adjustsFontForContentSizeCategory = true
        field.clearButtonMode = .whileEditing
        field.autocapitalizationType = .sentences
        field.returnKeyType = .done
        field.addAction(UIAction { [weak self] _ in self?.onChange?(self?.field.text ?? "") }, for: .editingChanged)
        field.addAction(UIAction { [weak self] _ in self?.field.resignFirstResponder() }, for: .editingDidEndOnExit)
        field.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(field)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            field.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Metrics.spaceInner),
            field.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Metrics.spaceInner),
            field.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
        ])
        backgroundConfiguration = UIBackgroundConfiguration.listRow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
