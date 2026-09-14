import UIKit
import os

/// The Habits tab (DESIGN.md §11): one card per active Habit, then an Archived section.
/// Long-press to reorder; tap a card for its detail; the toggle checks today in. Reads
/// through the façade on every appearance and after every write.
final class HabitsViewController: UIViewController {

    private static let logger = Logger(category: "Habits")

    private enum Section: Hashable {
        case active
        case archived
        /// Shown alone when there is no Habit at all.
        case empty
    }

    private enum Item: Hashable {
        case habit(HabitRecord.ID)
        case archived(HabitRecord.ID)
        case empty
    }

    private let dependencies: AppDependencies
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var cards: [HabitRecord.ID: HabitCardModel] = [:]
    private var archived: [HabitRecord.ID: HabitRecord] = [:]

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
        title = "Habits"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .always

        let add = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in self?.presentNewHabit() })
        add.accessibilityLabel = "New habit"
        navigationItem.rightBarButtonItem = add

        configureCollectionView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    // MARK: - Collection view

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let habitCell = UICollectionView.CellRegistration<HabitCardCell, HabitRecord.ID> { [weak self] cell, _, id in
            guard let self, let model = cards[id] else { return }
            cell.configure(with: model)
            cell.onToggle = { [weak self] on in self?.setToday(id, done: on) }
        }
        let archivedCell = UICollectionView.CellRegistration<ArchivedHabitCell, HabitRecord.ID> { [weak self] cell, _, id in
            guard let self, let habit = archived[id] else { return }
            cell.configure(with: habit)
            cell.onRestore = { [weak self] in self?.restore(id) }
            cell.onDelete = { [weak self] in self?.confirmDelete(habit) }
        }
        let emptyCell = UICollectionView.CellRegistration<EmptyStateCell, Item> { _, _, _ in }
        let header = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { view, _, _ in
            view.title = "Archived"
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .habit(let id):
                return collectionView.dequeueConfiguredReusableCell(using: habitCell, for: indexPath, item: id)
            case .archived(let id):
                return collectionView.dequeueConfiguredReusableCell(using: archivedCell, for: indexPath, item: id)
            case .empty:
                return collectionView.dequeueConfiguredReusableCell(using: emptyCell, for: indexPath, item: item)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
        dataSource.reorderingHandlers.canReorderItem = { item in
            if case .habit = item { return true }
            return false
        }
        dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
            let ids = transaction.finalSnapshot.itemIdentifiers(inSection: .active).compactMap { item -> HabitRecord.ID? in
                if case .habit(let id) = item { return id }
                return nil
            }
            self?.persistOrder(ids)
        }

        collectionView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress)))
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(220))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = Metrics.spaceCard
            section.contentInsets = NSDirectionalEdgeInsets(
                top: Metrics.spaceCard, leading: Metrics.spaceEdge, bottom: Metrics.spaceCard, trailing: Metrics.spaceEdge
            )
            if self?.dataSource.sectionIdentifier(for: sectionIndex) == .archived {
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
            }
            return section
        }
    }

    // MARK: - Rendering

    private func render() {
        let today = Day.today()
        let active: [HabitRecord]
        let archivedHabits: [HabitRecord]
        do {
            active = try dependencies.store.habits()
            archivedHabits = try dependencies.store.archivedHabits()
            cards = Dictionary(uniqueKeysWithValues: try active.map { habit in
                (habit.id, HabitCardModel(habit: habit, checkIns: try dependencies.store.checkIns(for: habit.id), today: today))
            })
        } catch {
            Self.logger.error("Failed to read Habits: \(error, privacy: .public)")
            return
        }
        archived = Dictionary(uniqueKeysWithValues: archivedHabits.map { ($0.id, $0) })

        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        if active.isEmpty && archivedHabits.isEmpty {
            snapshot.appendSections([.empty])
            snapshot.appendItems([.empty], toSection: .empty)
        } else {
            snapshot.appendSections([.active])
            snapshot.appendItems(active.map { .habit($0.id) }, toSection: .active)
            if !archivedHabits.isEmpty {
                snapshot.appendSections([.archived])
                snapshot.appendItems(archivedHabits.map { .archived($0.id) }, toSection: .archived)
            }
        }
        dataSource.apply(reconfiguringExisting: snapshot)
    }

    // MARK: - Actions

    private func setToday(_ id: HabitRecord.ID, done: Bool) {
        do {
            if done {
                try dependencies.store.checkIn(id, on: .today(), amount: 1)
            } else {
                try dependencies.store.removeCheckIn(id, on: .today())
            }
        } catch {
            Self.logger.error("Failed to write Check-in: \(error, privacy: .public)")
        }
        render()
    }

    private func persistOrder(_ ids: [HabitRecord.ID]) {
        do {
            try dependencies.store.reorderHabits(ids)
        } catch {
            Self.logger.error("Failed to reorder Habits: \(error, privacy: .public)")
            render()
        }
    }

    private func restore(_ id: HabitRecord.ID) {
        do {
            try dependencies.store.restoreHabit(id)
        } catch {
            Self.logger.error("Failed to restore Habit: \(error, privacy: .public)")
        }
        render()
    }

    private func confirmDelete(_ habit: HabitRecord) {
        let alert = UIAlertController(
            title: "Delete \(habit.name)?",
            message: "Every check-in for this habit is deleted too. This cannot be undone.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Delete permanently", style: .destructive) { [weak self] _ in
            guard let self else { return }
            do {
                try dependencies.store.deleteHabitPermanently(habit.id)
            } catch {
                Self.logger.error("Failed to delete Habit: \(error, privacy: .public)")
            }
            render()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func presentNewHabit() {
        present(HabitFormViewController.sheet(dependencies: dependencies) { [weak self] in self?.render() }, animated: true)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: collectionView)
        switch gesture.state {
        case .began:
            guard let indexPath = collectionView.indexPathForItem(at: location),
                  case .habit = dataSource.itemIdentifier(for: indexPath)
            else {
                // Disabling cancels the recognition; re-enabling arms it for the next press.
                gesture.isEnabled = false
                gesture.isEnabled = true
                return
            }
            collectionView.beginInteractiveMovementForItem(at: indexPath)
        case .changed:
            collectionView.updateInteractiveMovementTargetPosition(location)
        case .ended:
            collectionView.endInteractiveMovement()
        default:
            collectionView.cancelInteractiveMovement()
        }
    }
}

extension HabitsViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard case .habit(let id) = dataSource.itemIdentifier(for: indexPath) else { return }
        navigationController?.pushViewController(HabitDetailViewController(dependencies: dependencies, habitID: id), animated: true)
    }

    /// Reordering stays inside the active section.
    func collectionView(
        _ collectionView: UICollectionView,
        targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath,
        atCurrentIndexPath currentIndexPath: IndexPath,
        toProposedIndexPath proposedIndexPath: IndexPath
    ) -> IndexPath {
        guard proposedIndexPath.section != originalIndexPath.section else { return proposedIndexPath }
        return IndexPath(item: collectionView.numberOfItems(inSection: originalIndexPath.section) - 1, section: originalIndexPath.section)
    }
}

/// The empty state (DESIGN.md §1.5): the card the first Habit will occupy, with `—` in its
/// hero slot, so the tab never reads as broken.
private final class EmptyStateCell: CardCell {

    override class var header: (title: String, systemImage: String, iconTint: UIColor)? {
        ("Habits", "checkmark.circle.fill", UIColor.textPrimary)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let hero = UILabel()
        hero.text = "—"
        hero.font = UIFont.heroNumber
        hero.textColor = UIColor.textTertiary
        hero.adjustsFontForContentSizeCategory = true
        let caption = UILabel()
        caption.text = "Tap + to add your first habit."
        caption.font = UIFont.label
        caption.textColor = UIColor.textSecondary
        caption.adjustsFontForContentSizeCategory = true
        caption.numberOfLines = 0
        card.contentStack.addArrangedSubview(hero)
        card.contentStack.addArrangedSubview(caption)
        isAccessibilityElement = true
        accessibilityLabel = "No habits yet. Tap + to add your first habit."
    }
}
