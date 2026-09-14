import UIKit

/// A month calendar for retroactive Check-ins (DESIGN.md §11): Monday-first grid, done Days
/// in `accentGreen` with bloom, empty Days on `surfaceSunken`, future Days muted and inert.
/// Owns which month is shown; the owner supplies today and the met Days and handles taps.
final class MonthCalendarView: UIView {

    struct Model: Equatable {
        var today: Day
        var met: Set<Day>
    }

    var model: Model? {
        didSet { render() }
    }
    var onTapDay: ((Day) -> Void)?

    private enum Item: Hashable {
        case blank(Int)
        case day(Day)
    }

    private var visibleMonth: (year: Int, month: Int)
    private let monthLabel = UILabel()
    private let previousButton = UIButton(configuration: .plain())
    private let nextButton = UIButton(configuration: .plain())
    private let collectionView: UICollectionView
    private var dataSource: UICollectionViewDiffableDataSource<Int, Item>!
    private var heightConstraint: NSLayoutConstraint!

    init(today: Day = .today()) {
        visibleMonth = (today.year, today.month)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: Self.layout())
        super.init(frame: .zero)

        monthLabel.font = UIFont.cardTitle
        monthLabel.textColor = UIColor.textPrimary
        monthLabel.adjustsFontForContentSizeCategory = true

        for (button, name, delta) in [(previousButton, "chevron.left", -1), (nextButton, "chevron.right", 1)] {
            button.configuration?.image = UIImage(systemName: name)
            button.configuration?.baseForegroundColor = UIColor.textSecondary
            button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            button.addAction(UIAction { [weak self] _ in self?.shiftMonth(by: delta) }, for: .touchUpInside)
            button.setContentHuggingPriority(.required, for: .horizontal)
        }
        previousButton.accessibilityLabel = "Previous month"
        nextButton.accessibilityLabel = "Next month"

        let header = UIStackView(arrangedSubviews: [monthLabel, UIView(), previousButton, nextButton])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = Metrics.spaceTight

        let weekdays = UIStackView(arrangedSubviews: ["M", "T", "W", "T", "F", "S", "S"].map { letter in
            let label = UILabel()
            label.text = letter
            label.font = UIFont.label
            label.textColor = UIColor.textTertiary
            label.textAlignment = .center
            label.adjustsFontForContentSizeCategory = true
            return label
        })
        weekdays.axis = .horizontal
        weekdays.distribution = .fillEqually

        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.clipsToBounds = false
        collectionView.delegate = self
        heightConstraint = collectionView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.isActive = true

        let registration = UICollectionView.CellRegistration<CalendarDayCell, Item> { [weak self] cell, _, item in
            switch item {
            case .blank:
                cell.configure(nil)
            case .day(let day):
                guard let model = self?.model else { return cell.configure(nil) }
                cell.configure(.init(day: day, isDone: model.met.contains(day), isToday: day == model.today, isFuture: day > model.today))
            }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }

        let stack = UIStackView(arrangedSubviews: [header, weekdays, collectionView])
        stack.axis = .vertical
        stack.spacing = Metrics.spaceTight
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeight()
    }

    private static func layout() -> UICollectionViewLayout {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1 / 7), heightDimension: .fractionalHeight(1)
        ))
        let row = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(1 / 7)),
            repeatingSubitem: item, count: 7
        )
        return UICollectionViewCompositionalLayout(section: NSCollectionLayoutSection(group: row))
    }

    // MARK: - Month

    private var firstOfMonth: Day { Day(year: visibleMonth.year, month: visibleMonth.month, day: 1) }

    private var rowCount: Int {
        let leading = firstOfMonth.weekday - 1
        return Int((Double(leading + firstOfMonth.daysInMonth) / 7).rounded(.up))
    }

    private func shiftMonth(by delta: Int) {
        var month = visibleMonth.month + delta
        var year = visibleMonth.year
        if month < 1 { month = 12; year -= 1 }
        if month > 12 { month = 1; year += 1 }
        visibleMonth = (year, month)
        render()
    }

    private func updateHeight() {
        heightConstraint.constant = (bounds.width / 7 * CGFloat(rowCount)).rounded()
    }

    private func render() {
        guard let model else { return }
        let first = firstOfMonth
        monthLabel.text = first.start().formatted(.dateTime.month(.wide).year())
        nextButton.isEnabled = (visibleMonth.year, visibleMonth.month) < (model.today.year, model.today.month)

        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        snapshot.appendItems((0..<(first.weekday - 1)).map(Item.blank))
        snapshot.appendItems((0..<first.daysInMonth).map { .day(first.advanced(by: $0)) })
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: window != nil)
        updateHeight()
        accessibilityLabel = monthLabel.text
    }
}

extension MonthCalendarView: UICollectionViewDelegate {

    /// Only Days up to today respond; the future is inert (DESIGN.md §1.3).
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        guard case .day(let day) = dataSource.itemIdentifier(for: indexPath), let model else { return false }
        return day <= model.today
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        self.collectionView(collectionView, shouldHighlightItemAt: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard case .day(let day) = dataSource.itemIdentifier(for: indexPath) else { return }
        onTapDay?(day)
    }
}

/// One Day of the month calendar: a circle that is `accentGreen` with bloom when done,
/// `surfaceSunken` when not, and absent for Days still to come.
private final class CalendarDayCell: UICollectionViewCell {

    struct State {
        let day: Day
        let isDone: Bool
        let isToday: Bool
        let isFuture: Bool
    }

    private let bloomView = BloomView(accent: UIColor.accentGreen, shadowRadius: 6)
    private let circle = UIView()
    private let label = UILabel()

    /// Both scale with Dynamic Type (DESIGN.md §5); today is bold.
    private static let dayFont = UIFont.preferredFont(forTextStyle: .subheadline)
    private static let todayFont: UIFont = {
        let base = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        return UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: base.pointSize, weight: .bold))
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false

        for view in [bloomView, circle] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                view.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                view.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -Metrics.spaceTight),
                view.heightAnchor.constraint(equalTo: view.widthAnchor),
            ])
        }
        label.font = Self.dayFont
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The circle's own frame is not settled until after this pass, but its size is known.
        circle.layer.cornerRadius = (contentView.bounds.width - Metrics.spaceTight) / 2
    }

    override var isHighlighted: Bool {
        didSet { circle.alpha = isHighlighted ? 0.7 : 1 }
    }

    func configure(_ state: State?) {
        guard let state else {
            label.text = nil
            circle.isHidden = true
            bloomView.setVisible(false, animated: false)
            isAccessibilityElement = false
            return
        }
        label.text = String(state.day.day)
        circle.isHidden = state.isFuture
        circle.backgroundColor = state.isDone ? UIColor.accentGreen : UIColor.surfaceSunken
        label.textColor = state.isFuture ? UIColor.textTertiary
            : state.isDone ? .white
            : state.isToday ? UIColor.accentGreen
            : UIColor.textPrimary
        label.font = state.isToday ? Self.todayFont : Self.dayFont
        bloomView.setVisible(state.isDone, animated: true)
        isAccessibilityElement = true
        accessibilityTraits = state.isFuture ? .staticText : .button
        accessibilityLabel = state.day.start().formatted(.dateTime.month(.wide).day())
        accessibilityValue = state.isFuture ? "" : state.isDone ? "Done" : "Not done"
    }
}
