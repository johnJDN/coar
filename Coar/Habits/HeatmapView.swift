import UIKit

/// The habit heatmap (DESIGN.md §8, §11): a non-interactive `UICollectionView` of 7 rows
/// with Monday on top and `Heatmap.columns` weeks, `surfaceSunken` empty cells, the accent
/// at rising intensity through the quantitative buckets, `accentGreen` done cells with
/// bloom, nothing drawn after today. Weekly Habits get a `DotMatrix`-style row above the
/// grid, one dot per column, filled when that week met its target. Height follows width so
/// the cells are square.
final class HeatmapView: UIView {

    private static let gap: CGFloat = 1.5
    private static let dotRowHeight: CGFloat = 10

    var cells: [Heatmap.Cell] = [] {
        didSet { render(animated: window != nil) }
    }

    /// One per column for a weekly Habit; nil hides the row.
    var weekDots: [Bool]? {
        didSet { renderDots(animated: window != nil) }
    }

    private let collectionView: UICollectionView
    private let dotRow = UIStackView()
    private var dataSource: UICollectionViewDiffableDataSource<Int, Day>!
    private var levels: [Day: Heatmap.Level] = [:]

    init() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: Self.layout())
        super.init(frame: .zero)

        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.isUserInteractionEnabled = false
        collectionView.clipsToBounds = false

        dotRow.axis = .horizontal
        dotRow.distribution = .fillEqually
        dotRow.isHidden = true
        for _ in 0..<Heatmap.columns {
            dotRow.addArrangedSubview(WeekDotView())
        }

        let stack = UIStackView(arrangedSubviews: [dotRow, collectionView])
        stack.axis = .vertical
        stack.spacing = Metrics.spaceTight / 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let registration = UICollectionView.CellRegistration<HeatmapCell, Day> { [weak self] cell, _, day in
            cell.level = self?.levels[day] ?? .future
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, day in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: day)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            dotRow.heightAnchor.constraint(equalToConstant: Self.dotRowHeight),
            collectionView.heightAnchor.constraint(equalTo: collectionView.widthAnchor, multiplier: CGFloat(Heatmap.rows) / CGFloat(Heatmap.columns)),
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
            + (weekDots.map { ", \($0.filter { $0 }.count) weeks met" } ?? "")
    }

    private func renderDots(animated: Bool) {
        dotRow.isHidden = weekDots == nil
        for (dot, filled) in zip(dotRow.arrangedSubviews.compactMap { $0 as? WeekDotView }, weekDots ?? []) {
            dot.setFilled(filled, animated: animated)
        }
    }
}

/// One week-met dot (DESIGN.md §7 `DotMatrix`): `accentGreen` with bloom when the week met
/// its target, `surfaceSunken` when not.
private final class WeekDotView: UIView {

    private static let diameter: CGFloat = 6

    private let bloomView = BloomView(accent: UIColor.accentGreen, shadowRadius: 4)
    private let dot = UIView()

    init() {
        super.init(frame: .zero)
        dot.layer.cornerRadius = Self.diameter / 2
        dot.backgroundColor = UIColor.surfaceSunken
        for view in [bloomView, dot] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: centerXAnchor),
                view.centerYAnchor.constraint(equalTo: centerYAnchor),
                view.widthAnchor.constraint(equalToConstant: Self.diameter),
                view.heightAnchor.constraint(equalToConstant: Self.diameter),
            ])
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setFilled(_ filled: Bool, animated: Bool) {
        dot.backgroundColor = filled ? UIColor.accentGreen : UIColor.surfaceSunken
        bloomView.setVisible(filled, animated: animated)
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
        fillView.backgroundColor = level.fillColor
        bloomView.setVisible(level == .done, animated: animated)
    }
}

extension Heatmap.Level {
    /// The cell's fill (DESIGN.md §8): `surfaceSunken` when empty, the accent at rising
    /// intensity through the quantitative buckets, full accent when done; nothing after today.
    var fillColor: UIColor {
        switch self {
        case .future: return .clear
        case .empty: return UIColor.surfaceSunken
        case .quarter: return UIColor.accentGreen.withAlphaComponent(0.3)
        case .half: return UIColor.accentGreen.withAlphaComponent(0.5)
        case .threeQuarters: return UIColor.accentGreen.withAlphaComponent(0.7)
        case .done: return UIColor.accentGreen
        }
    }

    var accessibilityValue: String {
        switch self {
        case .future: return ""
        case .empty: return "Not done"
        case .quarter: return "Up to a quarter"
        case .half: return "Up to half"
        case .threeQuarters: return "More than half"
        case .done: return "Done"
        }
    }
}
