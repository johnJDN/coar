import UIKit

/// The week date strip at the top of Food (DESIGN.md §11): a day number over its weekday,
/// today marked, one Monday-to-Sunday week per page, paging back through history. The
/// selected Day sits on a `fill` well; Days after today are muted and inert. A selection
/// reports through `onSelect`.
final class WeekStripView: UIView {

    static let height: CGFloat = 72
    /// How far back the strip pages.
    static let weeksOfHistory = 104

    var onSelect: ((Day) -> Void)?

    private(set) var selectedDay: Day
    /// The marked Day; moving it (midnight with the app resident) rebuilds the strip around
    /// the new current week.
    var today: Day {
        didSet { if today != oldValue { rebuild() } }
    }
    private var days: [Day] = []
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Day>!
    private var hasScrolledToSelection = false

    init(today: Day, selected: Day) {
        self.today = today
        selectedDay = selected
        super.init(frame: .zero)
        configureCollectionView()
        rebuild()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasScrolledToSelection, bounds.width > 0 else { return }
        hasScrolledToSelection = true
        collectionView.layoutIfNeeded()
        collectionView.scrollToItem(at: indexPath(of: selectedDay.startOfWeek), at: .left, animated: false)
    }

    // MARK: - Collection view

    private func configureCollectionView() {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1 / 7), heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(Self.height)),
            repeatingSubitem: item,
            count: 7
        )
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: Metrics.spaceEdge - 4, bottom: 0, trailing: Metrics.spaceEdge - 4)
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .horizontal
        let layout = UICollectionViewCompositionalLayout(section: NSCollectionLayoutSection(group: group), configuration: configuration)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let cell = UICollectionView.CellRegistration<DayCell, Day> { [weak self] cell, _, day in
            guard let self else { return }
            cell.configure(day: day, isSelected: day == selectedDay, isToday: day == today, isFuture: day > today)
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, day in
            collectionView.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: day)
        }
    }

    /// The Days from `weeksOfHistory` Mondays back through the Sunday of today's week, then
    /// the page holding the selection.
    private func rebuild() {
        let first = today.startOfWeek.advanced(by: -7 * Self.weeksOfHistory)
        days = (0..<(7 * (Self.weeksOfHistory + 1))).map { first.advanced(by: $0) }
        if selectedDay > today { selectedDay = today }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Day>()
        snapshot.appendSections([0])
        snapshot.appendItems(days)
        snapshot.reconfigureItems(days.filter(dataSource.snapshot().itemIdentifiers.contains))
        dataSource.apply(snapshot, animatingDifferences: false)
        hasScrolledToSelection = false
        setNeedsLayout()
    }

    private func indexPath(of day: Day) -> IndexPath {
        IndexPath(item: days.firstIndex(of: day) ?? 0, section: 0)
    }
}

extension WeekStripView: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        days[indexPath.item] <= today
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        select(days[indexPath.item])
    }
}

extension WeekStripView {
    /// Selects a Day as a tap would, reporting it through `onSelect`, and scrolls its week
    /// into view.
    func select(_ day: Day) {
        guard day != selectedDay, day <= today, days.contains(day) else { return }
        let previous = selectedDay
        selectedDay = day
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems([previous, day])
        dataSource.apply(snapshot, animatingDifferences: true)
        collectionView.scrollToItem(at: indexPath(of: day.startOfWeek), at: .left, animated: true)
        onSelect?(day)
    }
}

/// One Day on the strip: the number over the weekday, a dot for today, a `fill` well when
/// selected.
private final class DayCell: UICollectionViewCell {

    private let well = UIView()
    private let numberLabel = UILabel()
    private let weekdayLabel = UILabel()
    private let todayDot = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        well.backgroundColor = UIColor.fill
        well.layer.cornerRadius = Metrics.radiusInner
        well.layer.cornerCurve = .continuous
        well.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(well)

        numberLabel.font = UIFont.metricNumber
        numberLabel.textAlignment = .center
        numberLabel.adjustsFontForContentSizeCategory = true

        weekdayLabel.font = UIFont.label
        weekdayLabel.textAlignment = .center
        weekdayLabel.adjustsFontForContentSizeCategory = true

        todayDot.backgroundColor = UIColor.accentGreen
        todayDot.layer.cornerRadius = 2.5

        let stack = UIStackView(arrangedSubviews: [numberLabel, weekdayLabel, todayDot])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            todayDot.widthAnchor.constraint(equalToConstant: 5),
            todayDot.heightAnchor.constraint(equalToConstant: 5),
            well.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            well.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            well.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            well.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(day: Day, isSelected: Bool, isToday: Bool, isFuture: Bool) {
        let date = day.start()
        numberLabel.text = String(day.day)
        weekdayLabel.text = date.formatted(.dateTime.weekday(.abbreviated))
        well.isHidden = !isSelected
        todayDot.alpha = isToday ? 1 : 0
        numberLabel.textColor = isFuture ? UIColor.textTertiary : isToday ? UIColor.accentGreen : UIColor.textPrimary
        weekdayLabel.textColor = isFuture ? UIColor.textTertiary : UIColor.textSecondary
        accessibilityLabel = date.formatted(.dateTime.weekday(.wide).month(.wide).day()) + (isToday ? ", today" : "")
        accessibilityTraits = isFuture ? [.button, .notEnabled] : isSelected ? [.button, .selected] : .button
    }

    override var isHighlighted: Bool {
        didSet { contentView.alpha = isHighlighted ? 0.7 : 1 }
    }
}
