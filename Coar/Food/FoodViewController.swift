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
        strip.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(strip)
        summary.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(summary)

        configureTimeline()
        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            summary.topAnchor.constraint(equalTo: strip.bottomAnchor),
            summary.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            summary.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            timeline.topAnchor.constraint(equalTo: summary.bottomAnchor),
            timeline.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            timeline.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            timeline.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        setContentScrollView(timeline, for: .top)
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
            guard let entry = self?.entries[id] else { return }
            cell.configure(with: entry)
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
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: hourHeader, for: indexPath)
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
        guard let id = dataSource.itemIdentifier(for: indexPath),
              let sheet = EntryDetailViewController.sheet(dependencies: dependencies, entryID: id, onChange: { [weak self] in self?.render() })
        else { return render() }
        present(sheet, animated: true)
    }
}
