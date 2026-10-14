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

/// An Entry on the timeline, in three fixed rows (`.scratch/food-cards/`): the name (up to two
/// lines) with its calories level with the first line as the metric number; the portion as a
/// person says it ("3 slices"); and the gram macros in their accents, in whole grams (the
/// Entry's page keeps the decimals) (DESIGN.md §1.2, §3). A row on `surface` with
/// `radiusInner` (a list row, not a `Card`) and the §6 card shadow, indented past the rail.
/// Tapping opens the Entry's detail. Swiping the row left slides it off a coral Delete: a
/// short swipe leaves Delete showing, a long one (or a fast flick) deletes at once, and the
/// rail stays put. Only the row moves, so the Delete is exactly its height. A custom swipe
/// because an hour section is not a list section, which is all UIKit's swipe actions serve.
final class EntryCell: UICollectionViewCell {

    /// Runs once the row has slid away or Delete was tapped; the owner deletes the Entry.
    var onDelete: (() -> Void)?
    /// Runs when a swipe leaves Delete showing, so the owner can close any other.
    var onReveal: ((EntryCell) -> Void)?
    /// The row alone, for the context menu's lift: not the rail beside it.
    var previewTarget: UIView { cardView }
    private(set) var isRevealed = false

    private static let revealWidth: CGFloat = 88
    private let deleteView = UIView()
    private var deleteWidth: NSLayoutConstraint!
    private var crossedFullSwipe = false
    private lazy var pan: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.delegate = self
        return pan
    }()

    private let cardView = UIView()
    private let nameLabel = UILabel()
    private let portionLabel = UILabel()
    private let macrosLabel = UILabel()
    private let caloriesLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false

        let rail = makeRailSlice()
        contentView.addSubview(rail)

        deleteView.backgroundColor = UIColor.accentCoral
        deleteView.layer.cornerRadius = Metrics.radiusInner
        deleteView.layer.cornerCurve = .continuous
        deleteView.clipsToBounds = true
        deleteView.isHidden = true
        deleteView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deleteView)
        let trash = UIImageView(image: UIImage(systemName: "trash.fill"))
        trash.tintColor = .white
        trash.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        trash.translatesAutoresizingMaskIntoConstraints = false
        deleteView.addSubview(trash)
        deleteView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(deleteTapped)))

        cardView.backgroundColor = UIColor.surface
        cardView.layer.cornerRadius = Metrics.radiusInner
        cardView.layer.cornerCurve = .continuous
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        contentView.addGestureRecognizer(pan)
        deleteWidth = deleteView.widthAnchor.constraint(equalToConstant: 0)

        nameLabel.font = UIFont.cardTitle
        nameLabel.textColor = UIColor.textPrimary
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2

        for label in [portionLabel, macrosLabel] {
            label.font = UIFont.label
            label.textColor = UIColor.textSecondary
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
        }

        caloriesLabel.font = UIFont.metricNumber
        caloriesLabel.textColor = UIColor.textPrimary
        caloriesLabel.adjustsFontForContentSizeCategory = true
        caloriesLabel.setContentHuggingPriority(.required, for: .horizontal)
        caloriesLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Three rows whatever the food: the name (up to two lines) with the calories level
        // with its first line, the portion, then the gram macros. Nothing shares a line, so
        // nothing wraps into the next.
        let top = UIStackView(arrangedSubviews: [nameLabel, caloriesLabel])
        top.axis = .horizontal
        top.alignment = .firstBaseline
        top.spacing = Metrics.spaceTight

        let row = UIStackView(arrangedSubviews: [top, portionLabel, macrosLabel])
        row.axis = .vertical
        row.alignment = .fill
        row.spacing = 2
        row.setCustomSpacing(4, after: top)
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
            deleteView.topAnchor.constraint(equalTo: cardView.topAnchor),
            deleteView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            deleteView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            deleteWidth,
            trash.centerYAnchor.constraint(equalTo: deleteView.centerYAnchor),
            trash.trailingAnchor.constraint(equalTo: deleteView.trailingAnchor, constant: -(Self.revealWidth - 24) / 2),
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

    override func prepareForReuse() {
        super.prepareForReuse()
        setOffset(0)
        isRevealed = false
        onDelete = nil
        onReveal = nil
        accessibilityCustomActions = nil
    }

    // MARK: - Swipe to delete

    /// How far the row is slid left, 0 to the cell's width: the coral Delete fills what it
    /// uncovers.
    private func setOffset(_ x: CGFloat) {
        let offset = min(0, x)
        cardView.transform = CGAffineTransform(translationX: offset, y: 0)
        deleteWidth.constant = -offset
        deleteView.isHidden = offset == 0
    }

    @objc private func panned(_ pan: UIPanGestureRecognizer) {
        let start: CGFloat = isRevealed ? -Self.revealWidth : 0
        let offset = start + pan.translation(in: contentView).x
        let fullSwipe = -contentView.bounds.width * 0.5
        switch pan.state {
        case .began:
            crossedFullSwipe = false
        case .changed:
            setOffset(offset)
            if (offset <= fullSwipe) != crossedFullSwipe {
                crossedFullSwipe = offset <= fullSwipe
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        case .ended:
            let velocity = pan.velocity(in: contentView).x
            if offset <= fullSwipe || (velocity < -1500 && offset < -Self.revealWidth) {
                slideAwayAndDelete()
            } else {
                settle(open: velocity < -300 || (offset < -Self.revealWidth / 2 && velocity < 300))
            }
        case .cancelled, .failed:
            settle(open: isRevealed)
        default:
            break
        }
    }

    /// Slides the row to rest, Delete showing or not.
    private func settle(open: Bool) {
        let wasRevealed = isRevealed
        isRevealed = open
        UIView.animate(springDuration: 0.4, bounce: 0.15) {
            self.setOffset(open ? -Self.revealWidth : 0)
            self.layoutIfNeeded()
        }
        if open, !wasRevealed { onReveal?(self) }
    }

    /// Closes a revealed Delete; the owner calls it on a scroll or a tap elsewhere.
    func closeSwipe() {
        guard isRevealed || cardView.transform.tx != 0 else { return }
        settle(open: false)
    }

    private func slideAwayAndDelete() {
        isRevealed = false
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
            self.setOffset(-self.contentView.bounds.width)
            self.layoutIfNeeded()
        }, completion: { _ in self.onDelete?() })
    }

    @objc private func deleteTapped() {
        slideAwayAndDelete()
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan else { return true }
        let velocity = pan.velocity(in: contentView)
        return abs(velocity.x) > abs(velocity.y) * 1.5
    }

    private func applyElevation() {
        Elevation.cardShadow(for: traitCollection.userInterfaceStyle).apply(to: cardView.layer)
    }

    func configure(with entry: EntryRecord) {
        nameLabel.text = entry.name
        caloriesLabel.attributedText = Self.calories(entry.macros)
        portionLabel.text = FoodText.portion(entry.quantity, of: entry.servingName)
        macrosLabel.attributedText = FoodText.styledMacroLineUIKit(entry.macros, includesCalories: false, wholeGrams: true)
        let grams = [Macro.protein, .fat, .carbs].map { "\(Int(entry.macros[$0].rounded())) grams \($0.title.lowercased())" }
        accessibilityLabel = "\(entry.name), \(FoodText.portion(entry.quantity, of: entry.servingName)), \(FoodText.calories(entry.macros)), " + grams.joined(separator: ", ")
    }

    /// "105 cal": the number as the metric number, the unit small and grey beside it.
    private static func calories(_ macros: Macros) -> NSAttributedString {
        let text = NSMutableAttributedString(string: macros.calories.formatted(.number.precision(.fractionLength(0))), attributes: [.font: UIFont.metricNumber, .foregroundColor: UIColor.textPrimary])
        text.append(NSAttributedString(string: " cal", attributes: [.font: UIFont.label, .foregroundColor: UIColor.textSecondary]))
        return text
    }
}

extension EntryCell: UIGestureRecognizerDelegate {}
