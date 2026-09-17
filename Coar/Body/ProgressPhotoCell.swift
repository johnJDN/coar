import UIKit

/// One Progress Photo in the grid: the thumbnail as a `radiusInner` square filling a
/// `surfaceSunken` well, its Day beneath in `label`, and a lavender ring with a check while
/// it is picked for a compare (the collection view's selection).
final class ProgressPhotoCell: UICollectionViewCell {

    private static let ringWidth: CGFloat = 3
    private static let checkInset: CGFloat = 6

    private let imageView = UIImageView()
    private let captionLabel = UILabel()
    private let checkView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.surfaceSunken
        imageView.layer.cornerRadius = Metrics.radiusInner
        imageView.layer.cornerCurve = .continuous
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        captionLabel.font = UIFont.label
        captionLabel.textColor = UIColor.textSecondary
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.textAlignment = .center
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(captionLabel)

        let palette = UIImage.SymbolConfiguration(paletteColors: [.white, UIColor.accentLavender])
            .applying(UIImage.SymbolConfiguration(textStyle: .title2))
        checkView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: palette)
        checkView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(checkView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),

            captionLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: Metrics.spaceTight),
            captionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            captionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            captionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            checkView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -Self.checkInset),
            checkView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -Self.checkInset),
        ])

        isAccessibilityElement = true
        accessibilityTraits = [.image, .button]
        updateSelection()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.updateSelection()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(thumbnail: UIImage?, caption: String) {
        imageView.image = thumbnail
        captionLabel.text = caption
        accessibilityLabel = "Progress Photo, \(caption)"
    }

    override var isSelected: Bool {
        didSet { updateSelection() }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }

    private func updateSelection() {
        imageView.layer.borderWidth = isSelected ? Self.ringWidth : 0
        imageView.layer.borderColor = UIColor.accentLavender.resolvedColor(with: traitCollection).cgColor
        checkView.isHidden = !isSelected
        if isSelected {
            accessibilityTraits.insert(.selected)
        } else {
            accessibilityTraits.remove(.selected)
        }
    }
}
