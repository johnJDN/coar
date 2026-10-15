import UIKit
import os

/// Every weigh-in, newest first, grouped by month (`.scratch/health-pages/`). A row is the
/// Day, the weight, and the change from the weigh-in before; tapping one opens the log sheet
/// for it, and swiping it left deletes it at once with Undo (DESIGN.md §7b, as Entries do).
final class BodyWeightHistoryViewController: UIViewController {

    private static let logger = Logger(category: "BodyWeight")

    private struct Month: Hashable {
        let year: Int
        let month: Int
    }

    private let dependencies: AppDependencies
    private let onChange: () -> Void
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Month, Day>!
    private var records: [Day: BodyWeightRecord] = [:]
    private var previous: [Day: BodyWeightRecord] = [:]
    private let toast = ToastView()
    private var unitObservation: MassUnitObservation?

    init(dependencies: AppDependencies, onChange: @escaping () -> Void) {
        self.dependencies = dependencies
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
        title = "Weigh-ins"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .never

        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.showsSeparators = false
        configuration.backgroundColor = .clear
        configuration.headerMode = .supplementary
        configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, let day = dataSource.itemIdentifier(for: indexPath) else { return nil }
            let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
                self?.delete(day)
                done(true)
            }
            delete.backgroundColor = UIColor.accentCoral
            return UISwipeActionsConfiguration(actions: [delete])
        }
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: UICollectionViewCompositionalLayout.list(using: configuration))
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)

        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, Day> { [weak self] cell, _, day in
            guard let self, let record = records[day] else { return }
            let unit = dependencies.preferences.massUnit
            var content = UIListContentConfiguration.valueCell()
            content.text = day.start().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            content.textProperties.font = UIFont.bodyText
            content.textProperties.color = UIColor.textPrimary
            var value = unit.displayText(fromKilograms: record.kilograms)
            if let before = previous[day] {
                let change = unit.displayValue(fromKilograms: record.kilograms) - unit.displayValue(fromKilograms: before.kilograms)
                value += abs(change) < 0.05 ? "   ±0" : "   \(change < 0 ? "−" : "+")\(abs(change).formatted(.number.precision(.fractionLength(1))))"
            }
            content.secondaryText = value
            content.secondaryTextProperties.font = UIFont.bodyText
            content.secondaryTextProperties.color = UIColor.textSecondary
            cell.contentConfiguration = content
            cell.backgroundConfiguration = .listRow()
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] view, _, indexPath in
            guard let month = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            var content = UIListContentConfiguration.groupedHeader()
            content.text = Calendar.current.date(from: DateComponents(year: month.year, month: month.month))!.formatted(.dateTime.month(.wide).year())
            view.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, day in
            collectionView.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: day)
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }

        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: Metrics.spaceEdge),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -Metrics.spaceEdge),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Metrics.spaceTight),
        ])
        unitObservation = dependencies.preferences.observeMassUnit { [weak self] in self?.reload(animated: false) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload(animated: false)
    }

    private func reload(animated: Bool) {
        let all: [BodyWeightRecord]
        do {
            all = try dependencies.store.bodyWeights()
        } catch {
            Self.logger.error("Failed to read Body Weights: \(error, privacy: .public)")
            all = []
        }
        records = Dictionary(all.map { ($0.day, $0) }, uniquingKeysWith: { _, last in last })
        previous = [:]
        for (index, record) in all.enumerated() where index > 0 {
            previous[record.day] = all[index - 1]
        }
        var snapshot = NSDiffableDataSourceSnapshot<Month, Day>()
        let calendar = Calendar.current
        for record in all.reversed() {
            let parts = calendar.dateComponents([.year, .month], from: record.day.start())
            let month = Month(year: parts.year!, month: parts.month!)
            if !snapshot.sectionIdentifiers.contains(month) { snapshot.appendSections([month]) }
            snapshot.appendItems([record.day], toSection: month)
        }
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: animated)
    }

    private func delete(_ day: Day) {
        guard let record = records[day] else { return }
        let logger = BodyWeightLogger(store: dependencies.store, healthWriter: dependencies.bodyWeightWriter)
        Task {
            do {
                try await logger.delete(on: day)
            } catch {
                Self.logger.error("Failed to delete Body Weight: \(error, privacy: .public)")
            }
            reload(animated: true)
            onChange()
            toast.show("Deleted \(day.shortText)", actionTitle: "Undo") { [weak self] in
                guard let self else { return }
                Task {
                    try? await logger.log(record.kilograms, in: .kilograms, on: record.day, stored: {
                        self.reload(animated: true)
                        self.onChange()
                    })
                }
            }
        }
    }
}

extension BodyWeightHistoryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let day = dataSource.itemIdentifier(for: indexPath) else { return }
        let sheet = BodyWeightLogViewController.sheet(dependencies: dependencies, day: day, onLogged: { [weak self] in
            self?.reload(animated: true)
            self?.onChange()
        }, onDeleted: { [weak self] record in
            guard let self else { return }
            reload(animated: true)
            onChange()
            toast.show("Deleted \(record.day.shortText)", actionTitle: "Undo") { [weak self] in
                guard let self else { return }
                let logger = BodyWeightLogger(store: dependencies.store, healthWriter: dependencies.bodyWeightWriter)
                Task {
                    try? await logger.log(record.kilograms, in: .kilograms, on: record.day, stored: {
                        self.reload(animated: true)
                        self.onChange()
                    })
                }
            }
        })
        present(sheet, animated: true)
    }
}
