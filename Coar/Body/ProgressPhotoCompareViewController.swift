import UIKit
import os

/// Two Progress Photos side by side, the earlier on the left, each captioned with its Day and
/// the Body Weight logged on the nearest Day (`—` when none). Also shows one photo on its own
/// (View from the grid). Reads through the façade on every appearance and whenever the unit
/// changes.
final class ProgressPhotoCompareViewController: ScreenViewController {

    private static let logger = Logger(category: "ProgressPhotos")

    private let dependencies: AppDependencies
    private let photoIDs: [ProgressPhotoRecord.ID]
    private let panes = UIStackView()
    private var unitObserver: NSObjectProtocol?

    init(dependencies: AppDependencies, photoIDs: [ProgressPhotoRecord.ID]) {
        self.dependencies = dependencies
        self.photoIDs = photoIDs
        super.init(title: photoIDs.count > 1 ? "Compare" : "Progress Photo")
    }

    deinit {
        if let unitObserver { NotificationCenter.default.removeObserver(unitObserver) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never

        panes.axis = .horizontal
        panes.distribution = .fillEqually
        panes.alignment = .top
        panes.spacing = Metrics.spaceTight
        let card = CardView()
        card.contentStack.addArrangedSubview(panes)
        contentStack.addArrangedSubview(card)

        unitObserver = NotificationCenter.default.addObserver(
            forName: Preferences.massUnitDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.render() }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    // MARK: - Rendering

    private func render() {
        let unit = dependencies.preferences.massUnit
        let photos: [ProgressPhotoRecord]
        do {
            photos = try photoIDs.compactMap { try dependencies.store.progressPhoto($0) }.sorted { $0.day < $1.day }
        } catch {
            Self.logger.error("Failed to read Progress Photos: \(error, privacy: .public)")
            return
        }
        panes.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for photo in photos {
            var image: UIImage?
            var weight: BodyWeightRecord?
            do {
                image = try dependencies.store.progressPhotoImage(photo.id).flatMap(UIImage.init)
                weight = try dependencies.store.bodyWeight(nearest: photo.day)
            } catch {
                Self.logger.error("Failed to read a Progress Photo's image or Body Weight: \(error, privacy: .public)")
            }
            panes.addArrangedSubview(ProgressPhotoPaneView(
                image: image,
                dayText: photo.day.shortTitle(),
                weightText: Self.weightText(weight, for: photo.day, in: unit)
            ))
        }
    }

    /// "185.3 lbs" when the Body Weight is from the photo's own Day, "185.3 lbs on Sep 11"
    /// when it is the nearest other Day, nil when none is logged.
    private static func weightText(_ weight: BodyWeightRecord?, for day: Day, in unit: MassUnit) -> String? {
        guard let weight else { return nil }
        let value = unit.displayText(fromKilograms: weight.kilograms)
        return weight.day == day ? value : "\(value) on \(weight.day.shortText)"
    }
}

/// One side of the compare: the photo fitted in a portrait `radiusInner` well, its Day in the
/// card-title style, and the Body Weight line beneath (`—` in `textTertiary` when none).
private final class ProgressPhotoPaneView: UIStackView {

    /// Portrait, as body photos are; a landscape photo letterboxes inside the well.
    private static let aspectRatio: CGFloat = 4 / 3

    init(image: UIImage?, dayText: String, weightText: String?) {
        super.init(frame: .zero)
        axis = .vertical
        spacing = Metrics.spaceTight

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.surfaceSunken
        imageView.layer.cornerRadius = Metrics.radiusInner
        imageView.layer.cornerCurve = .continuous
        imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: Self.aspectRatio).isActive = true
        addArrangedSubview(imageView)

        let dayLabel = UILabel()
        dayLabel.text = dayText
        dayLabel.font = UIFont.cardTitle
        dayLabel.textColor = UIColor.textPrimary
        dayLabel.adjustsFontForContentSizeCategory = true
        dayLabel.numberOfLines = 0
        addArrangedSubview(dayLabel)

        let weightLabel = UILabel()
        weightLabel.text = weightText ?? "—"
        weightLabel.font = UIFont.label
        weightLabel.textColor = weightText == nil ? UIColor.textTertiary : UIColor.textSecondary
        weightLabel.adjustsFontForContentSizeCategory = true
        weightLabel.numberOfLines = 0
        addArrangedSubview(weightLabel)

        isAccessibilityElement = true
        accessibilityTraits = .image
        accessibilityLabel = "Progress Photo, \(dayText), Body Weight \(weightText ?? "none")"
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
