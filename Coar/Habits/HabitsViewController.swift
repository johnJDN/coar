import UIKit
import os

/// The Habits tab (DESIGN.md §11): `SegmentedTabs` Check in / Tracked (CONTEXT.md "Tracked
/// habit"), then one card per active Habit of that kind and an Archived section for it.
/// Long-press to reorder; tap a card for its detail; the toggle checks today in and the
/// amount control opens today's number sheet. Reads through the façade on every appearance
/// and after every write.
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

    private enum Tab: Int {
        /// Yes/no, number, and checklist Habits: the ones checked in by hand.
        case checkIn
        case tracked

        func shows(_ habit: HabitRecord) -> Bool {
            (habit.tracking != nil) == (self == .tracked)
        }

        var emptyCaption: String {
            switch self {
            case .checkIn: return "Tap + to add your first habit."
            case .tracked: return "Tap + to add a habit that fills itself in from your sleep, steps, workouts, food, or weigh-ins."
            }
        }
    }

    private let dependencies: AppDependencies
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private let tabs = SegmentedTabsView(titles: ["Check in", "Tracked"])
    private var shownTab = Tab.checkIn
    /// Every active Habit in the user's order, both tabs, for saving a reorder.
    private var activeHabits: [HabitRecord] = []
    private var cards: [HabitRecord.ID: HabitCardModel] = [:]
    private var archived: [HabitRecord.ID: HabitRecord] = [:]
    private var remoteObserver: NSObjectProtocol?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
        title = "Habits"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        if let remoteObserver { NotificationCenter.default.removeObserver(remoteObserver) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .always

        let add = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in self?.presentNewHabit() })
        add.accessibilityLabel = "New habit"
        navigationItem.rightBarButtonItem = add

        tabs.onSelect = { [weak self] index in
            guard let self, let tab = Tab(rawValue: index), tab != self.shownTab else { return }
            self.shownTab = tab
            render(switchingTab: true)
            collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: false)
        }
        tabs.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabs)

        configureCollectionView()
        setContentScrollView(collectionView, for: .top)
        remoteObserver = observeRemoteChanges { [weak self] in self?.render() }
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
            tabs.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tabs.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.spaceEdge),
            tabs.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.spaceEdge),
            collectionView.topAnchor.constraint(equalTo: tabs.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let habitCell = UICollectionView.CellRegistration<HabitCardCell, HabitRecord.ID> { [weak self] cell, _, id in
            guard let self, let model = cards[id] else { return }
            cell.configure(with: model)
            cell.onToggle = { [weak self] on in self?.setToday(id, done: on) }
            cell.onAmountTap = { [weak self] in self?.presentAmount(id) }
        }
        let archivedCell = UICollectionView.CellRegistration<ArchivedHabitCell, HabitRecord.ID> { [weak self] cell, _, id in
            guard let self, let habit = archived[id] else { return }
            cell.configure(with: habit)
            cell.onRestore = { [weak self] in self?.restore(id) }
            cell.onDelete = { [weak self] in self?.confirmDelete(habit) }
        }
        let emptyCell = UICollectionView.CellRegistration<EmptyStateCell, Item> { [weak self] cell, _, _ in
            cell.caption = self?.shownTab.emptyCaption
        }
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
            self?.persistOrder(showing: ids)
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

    /// Tracked Habits' values from the last read (Apple Health reads are async); a render
    /// draws with these at once and then refreshes them.
    private var trackedValues: [HabitRecord.ID: [Day: Double]] = [:]
    private var trackedLoad: Task<Void, Never>?

    /// `switchingTab` reloads outright: the other tab's cards are other Habits, so there is
    /// nothing to animate between, and reused cells are measured afresh.
    private func render(refreshingTracked: Bool = true, switchingTab: Bool = false) {
        let today = Day.today()
        let active: [HabitRecord]
        let archivedHabits: [HabitRecord]
        do {
            activeHabits = try dependencies.store.habits()
            active = activeHabits.filter(shownTab.shows)
            archivedHabits = try dependencies.store.archivedHabits().filter(shownTab.shows)
            cards = Dictionary(uniqueKeysWithValues: try active.map { habit in
                (habit.id, HabitCardModel(
                    habit: habit, checkIns: try dependencies.store.checkIns(for: habit.id),
                    trackedValues: trackedValues[habit.id] ?? [:], today: today
                ))
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
        if switchingTab {
            dataSource.applySnapshotUsingReloadData(snapshot)
        } else {
            dataSource.apply(reconfiguringExisting: snapshot)
        }
        if refreshingTracked {
            refreshTracked(activeHabits, today: today)
        }
    }

    /// Reads every tracked Habit's values, then draws again if anything changed.
    private func refreshTracked(_ habits: [HabitRecord], today: Day) {
        let tracked = habits.compactMap { habit in habit.tracking.map { (habit.id, $0) } }
        guard !tracked.isEmpty else { return }
        trackedLoad?.cancel()
        trackedLoad = Task { [weak self] in
            guard let self else { return }
            var values: [HabitRecord.ID: [Day: Double]] = [:]
            for (id, tracking) in tracked {
                values[id] = await TrackedValues.load(tracking, store: dependencies.store, health: dependencies.healthReader, today: today)
            }
            guard !Task.isCancelled, values != trackedValues else { return }
            trackedValues = values
            render(refreshingTracked: false)
        }
    }

    // MARK: - Actions

    private func setToday(_ id: HabitRecord.ID, done: Bool) {
        do {
            try dependencies.store.setCheckedIn(id, on: .today(), done: done)
        } catch {
            Self.logger.error("Failed to write Check-in: \(error, privacy: .public)")
        }
        render()
    }

    /// Saves the shown tab's new order; the other tab's Habits keep theirs, check-in ones
    /// first so Home lists them in the same order.
    private func persistOrder(showing ids: [HabitRecord.ID]) {
        let others = activeHabits.filter { !shownTab.shows($0) }.map(\.id)
        do {
            try dependencies.store.reorderHabits(shownTab == .checkIn ? ids + others : others + ids)
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
        let alert = DeletePermanently.confirmation(name: habit.name, consequences: ["Every check-in for this habit is deleted too."]) { [weak self] in
            guard let self else { return }
            do {
                try dependencies.store.deleteHabitPermanently(habit.id)
            } catch {
                Self.logger.error("Failed to delete Habit: \(error, privacy: .public)")
            }
            render()
        }
        present(alert, animated: true)
    }

    private func presentAmount(_ id: HabitRecord.ID) {
        guard let sheet = HabitCheckInSheet.sheet(habitID: id, dependencies: dependencies, day: .today(), onChange: { [weak self] in self?.render() }) else { return }
        present(sheet, animated: true)
    }

    private func presentNewHabit() {
        let kind: HabitKind = shownTab == .tracked ? .tracked : .yesNo
        present(HabitFormViewController.sheet(dependencies: dependencies, kind: kind) { [weak self] in self?.render() }, animated: true)
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

/// The empty state (DESIGN.md §1.5): the card the tab's first Habit will occupy, with `—`
/// in its hero slot, so the tab never reads as broken.
private final class EmptyStateCell: CardCell {

    private let captionLabel = UILabel()

    var caption: String? {
        get { captionLabel.text }
        set {
            captionLabel.text = newValue
            accessibilityLabel = "No habits yet. \(newValue ?? "")"
        }
    }

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
        let caption = captionLabel
        caption.font = UIFont.label
        caption.textColor = UIColor.textSecondary
        caption.adjustsFontForContentSizeCategory = true
        caption.numberOfLines = 0
        card.contentStack.addArrangedSubview(hero)
        card.contentStack.addArrangedSubview(caption)
        isAccessibilityElement = true
    }
}
