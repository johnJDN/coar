import SwiftUI
import UIKit

/// `PillChip` (DESIGN.md §7): a capsule with a leading icon tile, title, optional subtitle,
/// and trailing chevron; Liquid Glass because it floats on the screen ground (§2). Group a
/// row of chips inside a `UIGlassContainerEffect` so adjacent glass merges.
final class PillChipView: UIControl {

    /// The subtitle slot; `—` when there is nothing to say, so the chip never reflows.
    var subtitle: String? {
        didSet { subtitleLabel.text = subtitle ?? "—" }
    }

    private let subtitleLabel = UILabel()
    private let effectView: UIVisualEffectView

    init(title: String, subtitle: String? = nil, systemImage: String, tint: UIColor) {
        let glass = UIGlassEffect()
        glass.isInteractive = true
        effectView = UIVisualEffectView(effect: glass)
        super.init(frame: .zero)

        effectView.cornerConfiguration = .capsule()
        effectView.isUserInteractionEnabled = false
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)

        let tile = UIHostingConfiguration {
            IconTile(systemImage: systemImage, tint: Color(uiColor: tint))
        }
        .margins(.all, 0)
        .makeContentView()
        tile.backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.cardTitle
        titleLabel.textColor = UIColor.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.font = UIFont.label
        subtitleLabel.textColor = UIColor.textSecondary
        subtitleLabel.adjustsFontForContentSizeCategory = true
        self.subtitle = subtitle
        subtitleLabel.text = subtitle ?? "—"

        let text = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        text.axis = .vertical
        text.spacing = 1

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor.textTertiary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [tile, text, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metrics.spaceTight
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        effectView.contentView.addSubview(row)

        let content = effectView.contentView
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            tile.widthAnchor.constraint(equalToConstant: 34),
            tile.heightAnchor.constraint(equalToConstant: 34),

            row.topAnchor.constraint(equalTo: content.topAnchor, constant: 6),
            row.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 6),
            row.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    /// Muted by default, alive when tappable (DESIGN.md §1.3).
    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.5 }
    }
}
