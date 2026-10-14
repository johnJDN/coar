import UIKit
import os

/// The Food tab (DESIGN.md §11): the week date strip, the macro summary row against the
/// Target in force on the selected Day, then that Day's hourly timeline with a "+" per hour
/// and its Entries at their time. Reads through the façade on every appearance, after every
/// day change, and after every write from a sheet.
final class FoodViewController: UIViewController {

    private static let logger = Logger(category: "Food")

    private let dependencies: AppDependencies
    private var today = Day.today()
    private var selectedDay: Day
    private let strip: WeekStripView
    private let summary = MacroSummaryView()
    private var timeObserver: NSObjectProtocol?
    private var remoteObserver: NSObjectProtocol?
    private var timeline: UICollectionView!
    private let toast = ToastView()
    /// The row a swipe left showing Delete, so another swipe, a scroll, or a tap elsewhere
    /// can close it.
    private weak var revealedCell: EntryCell?
    /// Sections are the 24 hours of the Day; items are the Entries in each.
    private var dataSource: UICollectionViewDiffableDataSource<Int, EntryRecord.ID>!
    private var entries: [EntryRecord.ID: EntryRecord] = [:]

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        selectedDay = today
        strip = WeekStripView(today: today, selected: today)
        super.init(nibName: nil, bundle: nil)
        title = "Food"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        for observer in [timeObserver, remoteObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .always
        timeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshToday() }
        }
        remoteObserver = observeRemoteChanges { [weak self] in self?.render() }

        let add = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in self?.presentAdd(hour: nil) })
        add.accessibilityLabel = "Add entry"
        navigationItem.rightBarButtonItem = add

        strip.onSelect = { [weak self] day in self?.select(day) }

        // The strip and summary are the timeline's pinned header, not views above it: the
        // timeline runs under the navigation bar as UIKit expects of the scroll view a large
        // title tracks, so the title collapses, and stretches on a pull, with everything
        // below it moving together. As separate views pinned to the safe area they stayed
        // put while a pulled title slid over them.
        configureTimeline()
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: Metrics.spaceEdge),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -Metrics.spaceEdge),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Metrics.spaceTight),
        ])
        NSLayoutConstraint.activate([
            timeline.topAnchor.constraint(equalTo: view.topAnchor),
            timeline.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            timeline.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            timeline.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        // Both edges: the large title collapses and the tab bar minimises (DESIGN.md §2) as
        // the timeline scrolls. Left to itself UIKit tracks the week strip for the bottom
        // edge, which only scrolls sideways, so the tab bar never minimised here.
        setContentScrollView(timeline, for: [.top, .bottom])
        updateSubtitle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshToday()
        render()
    }

    /// Lands on today, wherever the strip was: what Home's macros card opens.
    func showToday() {
        refreshToday()
        guard selectedDay != today else { return }
        strip.select(today)
    }

    /// Midnight passes with the app resident: the strip's mark and the selection move to
    /// the new today, so "+" never logs onto yesterday.
    private func refreshToday() {
        let now = Day.today()
        guard now != today else { return }
        today = now
        strip.today = now
        select(now)
    }

    // MARK: - Timeline

    private func configureTimeline() {
        timeline = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        timeline.backgroundColor = .clear
        timeline.alwaysBounceVertical = true
        timeline.delegate = self
        timeline.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timeline)

        let entryCell = UICollectionView.CellRegistration<EntryCell, EntryRecord.ID> { [weak self] cell, _, id in
            guard let self, let entry = entries[id] else { return }
            cell.configure(with: entry)
            cell.onDelete = { [weak self] in self?.delete(id) }
            cell.onReveal = { [weak self] in
                if self?.revealedCell !== $0 { self?.revealedCell?.closeSwipe() }
                self?.revealedCell = $0
            }
            var actions = [UIAccessibilityCustomAction(name: "Delete") { [weak self] _ in self?.delete(id); return true }]
            if canSaveAsFood(entry) {
                actions.append(UIAccessibilityCustomAction(name: "Save as food") { [weak self] _ in self?.saveAsFood(id); return true })
            }
            cell.accessibilityCustomActions = actions
        }
        let hourHeader = UICollectionView.SupplementaryRegistration<TimelineHourView>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] view, _, indexPath in
            guard let self else { return }
            let hour = indexPath.section
            view.configure(hourStart: instant(hour: hour, minute: 0), hasEntries: dataSource.snapshot().numberOfItems(inSection: hour) > 0)
            view.onAdd = { [weak self] in self?.presentAdd(hour: hour) }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: timeline) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: entryCell, for: indexPath, item: id)
        }
        let dayHeader = UICollectionView.SupplementaryRegistration<FoodDayHeaderView>(elementKind: FoodDayHeaderView.elementKind) { [weak self] view, _, _ in
            guard let self else { return }
            view.hold(strip: strip, summary: summary)
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            kind == FoodDayHeaderView.elementKind
                ? collectionView.dequeueConfiguredReusableSupplementary(using: dayHeader, for: indexPath)
                : collectionView.dequeueConfiguredReusableSupplementary(using: hourHeader, for: indexPath)
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(64))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: Metrics.spaceEdge, bottom: 0, trailing: Metrics.spaceEdge)
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(TimelineHourView.height)),
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
            return section
        }
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.contentInsetsReference = .none
        let dayHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(160)),
            elementKind: FoodDayHeaderView.elementKind,
            alignment: .top
        )
        dayHeader.pinToVisibleBounds = true
        dayHeader.zIndex = 2
        configuration.boundarySupplementaryItems = [dayHeader]
        layout.configuration = configuration
        return layout
    }

    // MARK: - Rendering

    private func render() {
        let dayEntries: [EntryRecord]
        let target: Macros?
        do {
            dayEntries = try dependencies.store.entries(on: selectedDay)
            target = try dependencies.store.target(inForceOn: selectedDay)?.macros
        } catch {
            Self.logger.error("Failed to read the Day: \(error, privacy: .public)")
            return
        }
        summary.configure(with: MacroSummary(consumed: Macros.sum(dayEntries.map(\.macros)), target: target))
        entries = Dictionary(uniqueKeysWithValues: dayEntries.map { ($0.id, $0) })
        let byHour = Dictionary(grouping: dayEntries) { Calendar.current.component(.hour, from: $0.loggedAt) }

        var snapshot = NSDiffableDataSourceSnapshot<Int, EntryRecord.ID>()
        snapshot.appendSections(Array(0..<24))
        for hour in 0..<24 {
            snapshot.appendItems((byHour[hour] ?? []).map(\.id), toSection: hour)
        }
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)
        // Hour rows are supplementary views a snapshot does not reconfigure: redraw the ones
        // on screen so their dots follow the Entries (with the §9 fade, not a reload's pop).
        for indexPath in timeline.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader) {
            guard let view = timeline.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? TimelineHourView else { continue }
            view.configure(hourStart: instant(hour: indexPath.section, minute: 0), hasEntries: snapshot.numberOfItems(inSection: indexPath.section) > 0)
        }
    }

    private func updateSubtitle() {
        navigationItem.subtitle = selectedDay.title(relativeTo: today)
    }

    private func select(_ day: Day) {
        selectedDay = day
        updateSubtitle()
        render()
    }

    /// The instant on the selected Day at the given time, in the user's current calendar.
    private func instant(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: selectedDay.start()) ?? selectedDay.start()
    }

    // MARK: - Deleting and saving an Entry

    /// Deletes the Entry at once and offers Undo for a few seconds: no confirmation, since
    /// putting it back restores it as it was (`Store.restoreEntry`).
    private func delete(_ id: EntryRecord.ID) {
        guard let entry = entries[id] else { return }
        do {
            try dependencies.store.deleteEntry(id)
        } catch {
            Self.logger.error("Failed to delete Entry: \(error, privacy: .public)")
            return render()
        }
        revealedCell = nil
        render()
        toast.show("Deleted \(entry.name)", actionTitle: "Undo") { [weak self] in
            do {
                try self?.dependencies.store.restoreEntry(entry)
            } catch {
                Self.logger.error("Failed to restore Entry: \(error, privacy: .public)")
            }
            self?.render()
        }
    }

    /// An Entry that isn't from a Food Item or Meal, and whose name isn't in Foods yet.
    private func canSaveAsFood(_ entry: EntryRecord) -> Bool {
        entry.foodItemID == nil && entry.mealID == nil && (try? dependencies.store.foodItem(named: entry.name)) == nil
    }

    private func saveAsFood(_ id: EntryRecord.ID) {
        do {
            let saved = try dependencies.store.saveEntryAsFood(id) != nil
            render()
            toast.show(saved ? "Saved to Foods" : "Already in Foods", duration: 3)
        } catch {
            Self.logger.error("Failed to save Entry as food: \(error, privacy: .public)")
        }
    }

    private func closeRevealedCell() {
        revealedCell?.closeSwipe()
        revealedCell = nil
    }

    // MARK: - Actions

    /// An hour's "+" starts the Entry at that hour; the toolbar "+" at the current time of
    /// day on the selected Day.
    private func presentAdd(hour: Int?) {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let at = hour.map { instant(hour: $0, minute: 0) } ?? instant(hour: now.hour ?? 12, minute: now.minute ?? 0)
        present(AddEntryViewController.sheet(dependencies: dependencies, at: at) { [weak self] in self?.render() }, animated: true)
    }
}

extension FoodViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        // A row left showing Delete closes first; the tap doesn't also open anything.
        if revealedCell != nil { return closeRevealedCell() }
        guard let id = dataSource.itemIdentifier(for: indexPath),
              let sheet = EntryDetailViewController.sheet(dependencies: dependencies, entryID: id, onChange: { [weak self] in self?.render() })
        else { return render() }
        present(sheet, animated: true)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        closeRevealedCell()
    }

    // MARK: Long press

    /// Press and hold an Entry for Save as food (when it isn't one of the user's foods yet)
    /// and Delete, which deletes at once like the swipe, with Undo.
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first, let id = dataSource.itemIdentifier(for: indexPath), let entry = entries[id] else { return nil }
        closeRevealedCell()
        return UIContextMenuConfiguration(identifier: id as NSUUID, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }
            var actions: [UIMenuElement] = []
            if canSaveAsFood(entry) {
                actions.append(UIAction(title: "Save as food", image: UIImage(systemName: "tray.and.arrow.down")) { [weak self] _ in self?.saveAsFood(id) })
            }
            actions.append(UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in self?.delete(id) })
            return UIMenu(children: actions)
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, highlightPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
        rowPreview(at: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, dismissalPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
        rowPreview(at: indexPath)
    }

    /// The row alone, rounded as it is, lifted by the menu: not the rail beside it.
    private func rowPreview(at indexPath: IndexPath) -> UITargetedPreview? {
        guard let cell = timeline.cellForItem(at: indexPath) as? EntryCell else { return nil }
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: cell.previewTarget.bounds, cornerRadius: Metrics.radiusInner)
        return UITargetedPreview(view: cell.previewTarget, parameters: parameters)
    }
}
