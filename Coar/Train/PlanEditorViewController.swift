import UIKit
import os

/// The Plan editor, pushed from the Train root: the name, then the rows as reorderable
/// lines (drag the handle; swipe to delete; tap for the Planned Sets; the link button joins
/// a row with the one below into a Superset) and an Add exercise row over the catalogue
/// picker. Save creates or updates the Plan through the façade; Workouts started before keep
/// their own copy of everything (ADR 0003). An existing Plan archives from the `…` menu.
final class PlanEditorViewController: UIViewController {

    enum Mode {
        case create
        case edit(PlanRecord)
    }

    private static let logger = Logger(category: "Train")

    private enum Section: Hashable {
        case name, exercises
    }

    private enum Item: Hashable {
        case name
        case exercise(PlanExerciseDraft.ID)
        case addExercise
    }

    private let dependencies: AppDependencies
    private let mode: Mode
    private var draft: PlanDraft
    /// The Exercises the rows point at, read as the editor renders (archived ones too, so a
    /// row whose Exercise has been archived still shows).
    private var exercises: [ExerciseRecord.ID: ExerciseRecord] = [:]
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private let saveItem = UIBarButtonItem(systemItem: .save)
    private var hasAppeared = false

    init(dependencies: AppDependencies, mode: Mode) {
        self.dependencies = dependencies
        self.mode = mode
        switch mode {
        case .create:
            draft = PlanDraft()
        case .edit(let plan):
            draft = PlanDraft(name: plan.name, exercises: plan.exercises.map(PlanExerciseDraft.init))
        }
        super.init(nibName: nil, bundle: nil)
        switch mode {
        case .create: title = "New Plan"
        case .edit: title = "Edit Plan"
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .never
        saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
        var items = [saveItem]
        if case .edit = mode {
            let archive = UIAction(title: "Archive", image: UIImage(systemName: "archivebox")) { [weak self] _ in self?.archive() }
            let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: [archive]))
            more.accessibilityLabel = "More"
            items.append(more)
        }
        navigationItem.rightBarButtonItems = items
        configureCollectionView()
        render()
    }

    /// A new Plan starts in the name field, once; popping back from a child leaves the
    /// keyboard down.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
            configuration.headerMode = self?.dataSource.sectionIdentifier(for: sectionIndex) == .exercises ? .supplementary : .none
            configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                guard case .exercise(let id) = self?.dataSource.itemIdentifier(for: indexPath) else { return nil }
                return UISwipeActionsConfiguration(actions: [
                    UIContextualAction(style: .destructive, title: "Remove") { _, _, done in
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
        collectionView.keyboardDismissMode = .onDrag
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
                self?.updateSaveState()
            }
        }
        let exerciseCell = UICollectionView.CellRegistration<PlanExerciseCell, PlanExerciseDraft.ID> { [weak self] cell, _, id in
            guard let self, let row = draft.exercises.first(where: { $0.id == id }) else { return }
            let exercise = exercises[row.exerciseID]
            let scheme = TrainText.scheme(of: row.sets, in: dependencies.preferences.massUnit)
            cell.configure(
                name: exercise?.name ?? "—",
                detail: [draft.supersetLabel(for: id), scheme].compactMap { $0 }.joined(separator: " · "),
                isExerciseArchived: exercise?.isArchived ?? false,
                link: draft.exercises.last?.id == id ? nil : draft.isLinkedToNext(id)
            )
            cell.onToggleLink = { [weak self] in
                self?.draft.toggleLink(below: id)
                self?.render()
            }
        }
        let addCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, _ in
            let content = UIListContentConfiguration.addRow("Add exercise")
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { view, _, _ in
            var content = UIListContentConfiguration.groupedHeader()
            content.text = "Exercises"
            view.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .name:
                return collectionView.dequeueConfiguredReusableCell(using: nameCell, for: indexPath, item: item)
            case .exercise(let id):
                return collectionView.dequeueConfiguredReusableCell(using: exerciseCell, for: indexPath, item: id)
            case .addExercise:
                return collectionView.dequeueConfiguredReusableCell(using: addCell, for: indexPath, item: item)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
        dataSource.reorderingHandlers.canReorderItem = { item in
            if case .exercise = item { return true }
            return false
        }
        dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
            let ids = transaction.finalSnapshot.itemIdentifiers(inSection: .exercises).compactMap { item -> PlanExerciseDraft.ID? in
                if case .exercise(let id) = item { return id }
                return nil
            }
            self?.draft.reorder(ids)
            // Superset labels and link buttons follow the new order.
            DispatchQueue.main.async { self?.render() }
        }
    }

    private func nameCell() -> TextFieldCell? {
        dataSource.indexPath(for: .name).flatMap { collectionView.cellForItem(at: $0) as? TextFieldCell }
    }

    // MARK: - Rendering

    private func render() {
        loadExercises()
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.name, .exercises])
        snapshot.appendItems([.name], toSection: .name)
        snapshot.appendItems(draft.exercises.map { .exercise($0.id) } + [.addExercise], toSection: .exercises)
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)
        updateSaveState()
    }

    private func loadExercises() {
        for id in Set(draft.exercises.map(\.exerciseID)) where exercises[id] == nil {
            do {
                exercises[id] = try dependencies.store.exercise(id)
            } catch {
                Self.logger.error("Failed to read Exercise: \(error, privacy: .public)")
            }
        }
    }

    private func updateSaveState() {
        saveItem.isEnabled = draft.isComplete
    }

    // MARK: - Actions

    private func pushSets(for row: PlanExerciseDraft) {
        let sets = PlannedSetsViewController(
            exerciseName: exercises[row.exerciseID]?.name ?? "Sets",
            row: row,
            unit: dependencies.preferences.massUnit
        ) { [weak self] saved in
            self?.draft.upsert(saved)
            self?.render()
        }
        navigationController?.pushViewController(sets, animated: true)
    }

    private func pushPicker() {
        let picker = ExercisePickerViewController(dependencies: dependencies) { [weak self] exercise in
            guard let self else { return }
            exercises[exercise.id] = exercise
            draft.append(exerciseID: exercise.id)
            render()
            navigationController?.popToViewController(self, animated: true)
        }
        navigationController?.pushViewController(picker, animated: true)
    }

    private func save() {
        guard draft.isComplete else { return }
        do {
            switch mode {
            case .create:
                try dependencies.store.createPlan(name: draft.trimmedName, exercises: draft.exercises)
            case .edit(let plan):
                try dependencies.store.updatePlan(plan.id, name: draft.trimmedName, exercises: draft.exercises)
            }
            navigationController?.popViewController(animated: true)
        } catch {
            Self.logger.error("Failed to save Plan: \(error, privacy: .public)")
        }
    }

    private func archive() {
        guard case .edit(let plan) = mode else { return }
        do {
            try dependencies.store.archivePlan(plan.id)
            navigationController?.popViewController(animated: true)
        } catch {
            Self.logger.error("Failed to archive Plan: \(error, privacy: .public)")
        }
    }
}

extension PlanEditorViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .exercise(let id):
            guard let row = draft.exercises.first(where: { $0.id == id }) else { return }
            pushSets(for: row)
        case .addExercise:
            pushPicker()
        case .name, nil:
            break
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        dataSource.itemIdentifier(for: indexPath) != .name
    }

    /// Reordering stays among the rows, above Add exercise.
    func collectionView(
        _ collectionView: UICollectionView,
        targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath,
        atCurrentIndexPath currentIndexPath: IndexPath,
        toProposedIndexPath proposedIndexPath: IndexPath
    ) -> IndexPath {
        IndexPath.reorderTarget(original: originalIndexPath, proposed: proposedIndexPath, lastReorderable: draft.exercises.count - 1)
    }
}

/// A Plan row in the editor: the Exercise's name over its set scheme (prefixed "A1", "A2"
/// inside a Superset), a link button that joins it with the row below (`accentLavender`
/// once linked, muted otherwise; absent on the last row), and the reorder handle.
final class PlanExerciseCell: UICollectionViewListCell {

    var onToggleLink: (() -> Void)?

    private let linkButton = UIButton(configuration: .plain())

    override init(frame: CGRect) {
        super.init(frame: frame)
        linkButton.addAction(UIAction { [weak self] _ in self?.onToggleLink?() }, for: .touchUpInside)
        linkButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// `link`: nil for the last row (nothing below to link with), else whether the row and
    /// the one below are one Superset.
    func configure(name: String, detail: String, isExerciseArchived: Bool, link: Bool?) {
        var content = UIListContentConfiguration.listRow()
        content.text = name
        content.secondaryText = isExerciseArchived ? "\(detail) · archived" : detail
        contentConfiguration = content
        backgroundConfiguration = UIBackgroundConfiguration.listRow()

        var accessories: [UICellAccessory] = []
        if let link {
            var configuration = linkButton.configuration ?? .plain()
            configuration.image = UIImage(systemName: link ? "link" : "link.badge.plus")
            configuration.baseForegroundColor = link ? UIColor.accentLavender : UIColor.textTertiary
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .body)
            linkButton.configuration = configuration
            linkButton.accessibilityLabel = link ? "Break superset with next" : "Superset with next"
            accessories.append(.customView(configuration: .init(customView: linkButton, placement: .trailing())))
        }
        accessories.append(.reorder(displayed: .always, options: .init(showsVerticalSeparator: false)))
        self.accessories = accessories
        accessibilityLabel = [name, content.secondaryText].compactMap { $0 }.joined(separator: ", ")
    }
}
