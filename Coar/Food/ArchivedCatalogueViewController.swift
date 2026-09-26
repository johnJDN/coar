import UIKit
import os

/// The archived Food Items or Meals (CONTEXT.md "Archived"), pushed from the "+" sheet's
/// "Archived foods" / "Archived meals" row. By name; tapping one offers Restore, which
/// returns it to the sheet's list. Entries logged from them never changed (ADR 0003).
final class ArchivedCatalogueViewController: UIViewController {

    enum Kind {
        case foods, meals
    }

    private struct Row: Hashable {
        let id: UUID
        let name: String
        let detail: NSAttributedString?
    }

    private static let logger = Logger(category: "Food")

    private let dependencies: AppDependencies
    private let kind: Kind
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Row>!
    private let emptyLabel = UILabel()

    init(dependencies: AppDependencies, kind: Kind) {
        self.dependencies = dependencies
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
        title = kind == .foods ? "Archived Foods" : "Archived Meals"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background

        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.showsSeparators = false
        configuration.backgroundColor = .clear
        configuration.footerMode = .supplementary
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: UICollectionViewCompositionalLayout.list(using: configuration))
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        view.addSubview(collectionView)

        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, Row> { cell, _, row in
            var content = UIListContentConfiguration.listRow()
            content.text = row.name
            content.secondaryAttributedText = row.detail
            cell.contentConfiguration = content
            cell.accessories = [.label(text: "Restore", options: .init(tintColor: UIColor.accentGreen))]
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let footer = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionFooter) { [kind] view, _, _ in
            var content = UIListContentConfiguration.groupedFooter()
            content.text = kind == .foods
                ? "Archived foods are hidden from the list. Entries you logged from them are unchanged."
                : "Archived meals are hidden from the list. Entries you logged from them are unchanged."
            view.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, row in
            collectionView.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: row)
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: footer, for: indexPath)
        }

        emptyLabel.text = kind == .foods ? "No archived foods" : "No archived meals"
        emptyLabel.font = UIFont.bodyText
        emptyLabel.textColor = UIColor.textTertiary
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        render()
    }

    private func render() {
        let rows: [Row]
        do {
            switch kind {
            case .foods:
                rows = try dependencies.store.archivedFoodItems().map { Row(id: $0.id, name: $0.name, detail: $0.defaultServing.map { NSAttributedString(string: FoodText.summary(of: $0)) }) }
            case .meals:
                rows = try dependencies.store.archivedMeals().map { Row(id: $0.id, name: $0.name, detail: FoodText.styledMacroLineUIKit($0.macros)) }
            }
        } catch {
            Self.logger.error("Failed to read archived \(self.kind == .foods ? "Food Items" : "Meals", privacy: .public): \(error, privacy: .public)")
            return
        }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Row>()
        if !rows.isEmpty {
            snapshot.appendSections([0])
            snapshot.appendItems(rows)
        }
        emptyLabel.isHidden = !rows.isEmpty
        dataSource.apply(snapshot, animatingDifferences: view.window != nil)
    }

    private func restore(_ row: Row) {
        do {
            switch kind {
            case .foods: try dependencies.store.restoreFoodItem(row.id)
            case .meals: try dependencies.store.restoreMeal(row.id)
            }
        } catch {
            Self.logger.error("Failed to restore: \(error, privacy: .public)")
        }
        render()
    }
}

extension ArchivedCatalogueViewController: UICollectionViewDelegate {

    /// Restore is reversible (archive it again), so it does not confirm, like Habits.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let row = dataSource.itemIdentifier(for: indexPath) else { return }
        restore(row)
    }
}
