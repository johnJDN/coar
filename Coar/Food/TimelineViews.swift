import UIKit

/// Geometry shared by the timeline's hour rows and Entry cards so the rail runs unbroken
/// down the screen: each view draws its own slice of it.
enum TimelineMetrics {
    static let hourLabelWidth: CGFloat = 52
    static let railWidth: CGFloat = 2
    /// The rail's centre, measured from the row's leading edge.
    static let railCenter: CGFloat = hourLabelWidth + 6
    /// Where an Entry card starts.
    static let contentLeading: CGFloat = railCenter + 14
}

/// A slice of the timeline rail: a soft `fill` bar, not a divider (DESIGN.md §1.1), that
/// the hour rows and Entry cards each draw across their own height.
private func makeRailSlice() -> UIView {
    let rail = UIView()
    rail.backgroundColor = UIColor.fill
    rail.translatesAutoresizingMaskIntoConstraints = false
    rail.widthAnchor.constraint(equalToConstant: TimelineMetrics.railWidth).isActive = true
    return rail
}

/// One hour on the Food timeline: the hour in `textTertiary`, a dot on the rail that is
/// muted until the hour has Entries (DESIGN.md §1.3), and a "+" that starts an Entry at that
/// hour, reported through `onAdd`.
final class TimelineHourView: UICollectionReusableView {

    static let height: CGFloat = 36

    var onAdd: (() -> Void)?

    private let hourLabel = UILabel()
    private let dot = UIView()
    private let bloom = BloomView(accent: UIColor.accentGreen, shadowRadius: 4, cornerRadius: 4)
    private let addButton: UIButton

    override init(frame: CGRect) {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(textStyle: .caption1).applying(UIImage.SymbolConfiguration(weight: .bold)))
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.textSecondary
        configuration.contentInsets = .zero
        addButton = UIButton(configuration: configuration)
        super.init(frame: frame)

        hourLabel.font = UIFont.label
        hourLabel.textColor = UIColor.textTertiary
        hourLabel.adjustsFontForContentSizeCategory = true
        hourLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hourLabel)

        let rail = makeRailSlice()
        addSubview(rail)

        bloom.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bloom)
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)

        addButton.addAction(UIAction { [weak self] _ in self?.onAdd?() }, for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Self.height),
            hourLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            hourLabel.widthAnchor.constraint(equalToConstant: TimelineMetrics.hourLabelWidth),
            hourLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            rail.topAnchor.constraint(equalTo: topAnchor),
            rail.bottomAnchor.constraint(equalTo: bottomAnchor),
            rail.centerXAnchor.constraint(equalTo: leadingAnchor, constant: TimelineMetrics.railCenter),
            dot.centerXAnchor.constraint(equalTo: rail.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            bloom.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
            bloom.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
            bloom.widthAnchor.constraint(equalTo: dot.widthAnchor),
            bloom.heightAnchor.constraint(equalTo: dot.heightAnchor),
            addButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 28),
            addButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var hasEntries = false

    override func prepareForReuse() {
        super.prepareForReuse()
        hasEntries = false
        bloom.setVisible(false, animated: false)
    }

    /// Draws the hour; the dot's bloom fades in when the hour gains its first Entry on
    /// screen (DESIGN.md §9), and is set plainly on first display.
    func configure(hourStart: Date, hasEntries: Bool) {
        let text = hourStart.formatted(.dateTime.hour())
        hourLabel.text = text
        let changed = hasEntries != self.hasEntries
        self.hasEntries = hasEntries
        dot.backgroundColor = hasEntries ? UIColor.accentGreen : UIColor.fill
        bloom.setVisible(hasEntries, animated: changed && window != nil)
        addButton.accessibilityLabel = "Add entry at \(text)"
    }
}

/// An Entry on the timeline: name, "2 × 1 egg" with the three gram macros in their accents,
/// and the calories as the metric number (DESIGN.md §1.2, §3). A row on `surface` with
/// `radiusInner` (a list row, not a `Card`) and the §6 card shadow, indented past the rail.
/// Tapping opens the Entry's detail.
final class EntryCell: UICollectionViewCell {

    private let cardView = UIView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let caloriesLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false

        let rail = makeRailSlice()
        contentView.addSubview(rail)

        cardView.backgroundColor = UIColor.surface
        cardView.layer.cornerRadius = Metrics.radiusInner
        cardView.layer.cornerCurve = .continuous
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        nameLabel.font = UIFont.cardTitle
        nameLabel.textColor = UIColor.textPrimary
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2

        detailLabel.font = UIFont.label
        detailLabel.textColor = UIColor.textSecondary
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.numberOfLines = 2

        caloriesLabel.font = UIFont.metricNumber
        caloriesLabel.textColor = UIColor.textPrimary
        caloriesLabel.adjustsFontForContentSizeCategory = true
        caloriesLabel.setContentHuggingPriority(.required, for: .horizontal)
        caloriesLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let text = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 2

        let row = UIStackView(arrangedSubviews: [text, caloriesLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metrics.spaceTight
        row.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(row)

        NSLayoutConstraint.activate([
            rail.topAnchor.constraint(equalTo: contentView.topAnchor),
            rail.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            rail.centerXAnchor.constraint(equalTo: contentView.leadingAnchor, constant: TimelineMetrics.railCenter),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: TimelineMetrics.contentLeading),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Metrics.spaceTight),
            row.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: Metrics.spaceInner),
            row.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -Metrics.spaceInner),
            row.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
        ])

        applyElevation()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in self.applyElevation() }
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        cardView.layer.shadowPath = UIBezierPath(roundedRect: cardView.bounds, cornerRadius: Metrics.radiusInner).cgPath
    }

    override var isHighlighted: Bool {
        didSet { cardView.alpha = isHighlighted ? 0.85 : 1 }
    }

    private func applyElevation() {
        Elevation.cardShadow(for: traitCollection.userInterfaceStyle).apply(to: cardView.layer)
    }

    func configure(with entry: EntryRecord) {
        nameLabel.text = entry.name
        caloriesLabel.text = FoodText.calories(entry.macros)
        detailLabel.attributedText = Self.detail(for: entry)
        let grams = [Macro.protein, .fat, .carbs].map { "\(FoodText.amount(entry.macros[$0])) grams \($0.title.lowercased())" }
        accessibilityLabel = "\(entry.name), \(FoodText.quantity(entry.quantity, of: entry.servingName)), \(FoodText.calories(entry.macros)), " + grams.joined(separator: ", ")
    }

    /// "2 × 1 egg · P 12 · F 10 · C 0", each gram macro's letter in its accent.
    private static func detail(for entry: EntryRecord) -> NSAttributedString {
        FoodText.styledMacroLineUIKit(entry.macros, leading: FoodText.quantity(entry.quantity, of: entry.servingName), includesCalories: false)
    }
}
