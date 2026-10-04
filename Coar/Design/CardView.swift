import UIKit

/// `Card` (DESIGN.md §7): a `surface` container with `radiusCard`, `spaceInner` padding, and
/// the §6 elevation. Optional header row: icon + title, an optional trailing detail (a
/// caption the owner keeps), then `→` (navigates) or chevron (expands). Put content in
/// `contentStack`. A Home tile is the compact form: `radiusInner` and tighter padding.
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
    private let cornerRadius: CGFloat

    init(title: String? = nil, systemImage: String? = nil, iconTint: UIColor = UIColor.textPrimary, detail: UIView? = nil, accessory: Accessory = .none, compact: Bool = false) {
        cornerRadius = compact ? Metrics.radiusInner : Metrics.radiusCard
        let padding = compact ? Metrics.spaceTight + 4 : Metrics.spaceInner
        super.init(frame: .zero)

        layer.masksToBounds = false

        surfaceView.backgroundColor = UIColor.surface
        surfaceView.layer.cornerRadius = cornerRadius
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
            contentStack.addArrangedSubview(Self.header(title: title, systemImage: systemImage, iconTint: iconTint, detail: detail, accessory: accessory))
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

            contentStack.topAnchor.constraint(equalTo: surfaceView.topAnchor, constant: padding),
            contentStack.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor, constant: padding),
            contentStack.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor, constant: -padding),
            contentStack.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor, constant: -padding),
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
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }

    private func applyElevation() {
        Elevation.cardShadow(for: traitCollection.userInterfaceStyle).apply(to: layer)
    }

    private static func header(title: String, systemImage: String?, iconTint: UIColor, detail: UIView?, accessory: Accessory) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metrics.spaceTight

        if let systemImage {
            let icon = UIImageView(image: UIImage(systemName: systemImage))
            icon.tintColor = iconTint
            icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .headline)
            icon.setContentHuggingPriority(.required, for: .horizontal)
            icon.setContentCompressionResistancePriority(.required, for: .horizontal)
            row.addArrangedSubview(icon)
        }

        let label = UILabel()
        label.text = title
        label.font = UIFont.cardTitle
        label.textColor = UIColor.textPrimary
        label.adjustsFontForContentSizeCategory = true
        // A half-width square's title ("Last Workout") shrinks a little rather than truncates.
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.65
        row.addArrangedSubview(label)
        if let detail {
            detail.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(detail)
        }

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
            accessoryView.setContentCompressionResistancePriority(.required, for: .horizontal)
            row.addArrangedSubview(accessoryView)
        }
        return row
    }
}
