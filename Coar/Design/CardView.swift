import UIKit

/// `Card` (DESIGN.md §7): a `surface` container with `radiusCard`, `spaceInner` padding, and
/// the §6 elevation. Optional header row: icon + title + trailing `→` (navigates) or
/// chevron (expands). Put content in `contentStack`.
final class CardView: UIView {

    enum Accessory {
        case none
        /// Tapping the card navigates somewhere: trailing `→`.
        case navigates
        /// The card expands in place: trailing chevron.
        case expands
    }

    let contentStack = UIStackView()

    private let surfaceView = UIView()
    private let highlightView = UIView()

    init(title: String? = nil, systemImage: String? = nil, accessory: Accessory = .none) {
        super.init(frame: .zero)

        layer.masksToBounds = false

        surfaceView.backgroundColor = UIColor.surface
        surfaceView.layer.cornerRadius = Metrics.radiusCard
        surfaceView.layer.cornerCurve = .continuous
        surfaceView.clipsToBounds = true
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surfaceView)

        highlightView.backgroundColor = Elevation.cardHighlight
        highlightView.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.addSubview(highlightView)

        contentStack.axis = .vertical
        contentStack.spacing = Metrics.spaceTight
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.addSubview(contentStack)

        if let title {
            contentStack.addArrangedSubview(Self.header(title: title, systemImage: systemImage, accessory: accessory))
        }

        NSLayoutConstraint.activate([
            surfaceView.topAnchor.constraint(equalTo: topAnchor),
            surfaceView.leadingAnchor.constraint(equalTo: leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: trailingAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: bottomAnchor),

            highlightView.topAnchor.constraint(equalTo: surfaceView.topAnchor),
            highlightView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
            highlightView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
            highlightView.heightAnchor.constraint(equalToConstant: 1),

            contentStack.topAnchor.constraint(equalTo: surfaceView.topAnchor, constant: Metrics.spaceInner),
            contentStack.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor, constant: Metrics.spaceInner),
            contentStack.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor, constant: -Metrics.spaceInner),
            contentStack.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor, constant: -Metrics.spaceInner),
        ])

        applyElevation()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.applyElevation()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Metrics.radiusCard).cgPath
    }

    private func applyElevation() {
        let shadow = Elevation.cardShadow(for: traitCollection.userInterfaceStyle)
        layer.shadowColor = shadow.color.cgColor
        layer.shadowOpacity = shadow.opacity
        layer.shadowOffset = shadow.offset
        layer.shadowRadius = shadow.blur / 2
    }

    private static func header(title: String, systemImage: String?, accessory: Accessory) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metrics.spaceTight

        if let systemImage {
            let icon = UIImageView(image: UIImage(systemName: systemImage))
            icon.tintColor = UIColor.textPrimary
            icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .headline)
            icon.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(icon)
        }

        let label = UILabel()
        label.text = title
        label.font = UIFont.cardTitle
        label.textColor = UIColor.textPrimary
        label.adjustsFontForContentSizeCategory = true
        row.addArrangedSubview(label)

        let accessoryName: String? = switch accessory {
        case .none: nil
        case .navigates: "arrow.right"
        case .expands: "chevron.down"
        }
        if let accessoryName {
            let accessoryView = UIImageView(image: UIImage(systemName: accessoryName))
            accessoryView.tintColor = UIColor.textSecondary
            accessoryView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
            accessoryView.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(accessoryView)
        }
        return row
    }
}
