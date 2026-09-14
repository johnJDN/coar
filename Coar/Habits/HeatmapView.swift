import UIKit

/// The habit heatmap (DESIGN.md §8, §11): a non-interactive `UICollectionView` of 7 rows
/// with Monday on top and `Heatmap.columns` weeks, `surfaceSunken` empty cells, `accentGreen`
/// done cells with bloom, nothing drawn after today. Height follows width so the cells are
/// square.
final class HeatmapView: UIView {

    private static let gap: CGFloat = 1.5

    var cells: [Heatmap.Cell] = [] {
        didSet { render(animated: window != nil) }
    }

    private let collectionView: UICollectionView
    private var dataSource: UICollectionViewDiffableDataSource<Int, Day>!
    private var levels: [Day: Heatmap.Level] = [:]

    init() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: Self.layout())
        super.init(frame: .zero)

        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.isUserInteractionEnabled = false
        collectionView.clipsToBounds = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)

        let registration = UICollectionView.CellRegistration<HeatmapCell, Day> { [weak self] cell, _, day in
            cell.level = self?.levels[day] ?? .future
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, day in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: day)
        }

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: CGFloat(Heatmap.rows) / CGFloat(Heatmap.columns)),
        ])
        isAccessibilityElement = true
        accessibilityLabel = "Heatmap"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static func layout() -> UICollectionViewLayout {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1 / CGFloat(Heatmap.rows))
        ))
        item.contentInsets = NSDirectionalEdgeInsets(top: gap, leading: gap, bottom: gap, trailing: gap)
        let column = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1 / CGFloat(Heatmap.columns)), heightDimension: .fractionalHeight(1)),
            repeatingSubitem: item, count: Heatmap.rows
        )
        let grid = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)),
            repeatingSubitem: column, count: Heatmap.columns
        )
        let section = NSCollectionLayoutSection(group: grid)
        section.contentInsets = NSDirectionalEdgeInsets(top: -gap, leading: -gap, bottom: -gap, trailing: -gap)
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func render(animated: Bool) {
        levels = Dictionary(uniqueKeysWithValues: cells.map { ($0.day, $0.level) })
        var snapshot = NSDiffableDataSourceSnapshot<Int, Day>()
        snapshot.appendSections([0])
        snapshot.appendItems(cells.map(\.day))
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: animated)
        let done = cells.filter { $0.level == .done }.count
        accessibilityValue = "\(done) of \(cells.filter { $0.level != .future }.count) days done"
    }
}

/// One heatmap cell. Bloom lives on a sibling view under the fill so it can fade in over
/// `bloomFade` rather than pop (DESIGN.md §9).
private final class HeatmapCell: UICollectionViewCell {

    var level: Heatmap.Level = .future {
        didSet { render(animated: window != nil && oldValue != level) }
    }

    private let bloomView = BloomView(accent: UIColor.accentGreen, shadowRadius: 4, cornerRadius: 2)
    private let fillView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false

        fillView.layer.cornerRadius = 2
        fillView.layer.cornerCurve = .continuous
        for view in [bloomView, fillView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: contentView.topAnchor),
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        }
        render(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func render(animated: Bool) {
        switch level {
        case .future:
            fillView.backgroundColor = .clear
        case .empty:
            fillView.backgroundColor = UIColor.surfaceSunken
        case .done:
            fillView.backgroundColor = UIColor.accentGreen
        }
        bloomView.setVisible(level == .done, animated: animated)
    }
}
