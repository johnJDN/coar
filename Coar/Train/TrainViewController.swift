import UIKit
import os

/// The Train root (DESIGN.md §11): the month grid, Start, Plans, and recent Workouts arrive
/// with the training tickets; for now a placeholder grid card above the row of three
/// `PillChip`s. Only Body Weight is live.
final class TrainViewController: ScreenViewController {

    private static let logger = Logger(category: "Train")

    private let dependencies: AppDependencies
    private let bodyWeightChip = PillChipView(title: "Body Weight", systemImage: "scalemass.fill", tint: UIColor.accentTeal)

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(title: "Train")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let grid = CardView(title: "This month", systemImage: "calendar")
        let placeholder = UILabel()
        placeholder.text = "—"
        placeholder.font = UIFont.heroNumber
        placeholder.textColor = UIColor.textTertiary
        placeholder.adjustsFontForContentSizeCategory = true
        grid.contentStack.addArrangedSubview(placeholder)
        contentStack.addArrangedSubview(grid)

        contentStack.addArrangedSubview(chipRow())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshBodyWeightChip()
    }

    // MARK: - Chips

    private func chipRow() -> UIView {
        let exercises = PillChipView(title: "Exercises", systemImage: "figure.strengthtraining.traditional", tint: UIColor.accentLime)
        let photos = PillChipView(title: "Progress Photos", systemImage: "camera.fill", tint: UIColor.accentLavender)
        exercises.isEnabled = false
        photos.isEnabled = false
        bodyWeightChip.addAction(UIAction { [weak self] _ in self?.showBodyWeight() }, for: .touchUpInside)

        let chips = UIStackView(arrangedSubviews: [exercises, bodyWeightChip, photos])
        chips.axis = .horizontal
        chips.spacing = Metrics.spaceTight
        chips.translatesAutoresizingMaskIntoConstraints = false

        let group = UIVisualEffectView(effect: UIGlassContainerEffect())
        group.translatesAutoresizingMaskIntoConstraints = false
        group.contentView.addSubview(chips)

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.clipsToBounds = false
        scroll.addSubview(group)

        let content = scroll.contentLayoutGuide
        NSLayoutConstraint.activate([
            chips.topAnchor.constraint(equalTo: group.contentView.topAnchor),
            chips.leadingAnchor.constraint(equalTo: group.contentView.leadingAnchor),
            chips.trailingAnchor.constraint(equalTo: group.contentView.trailingAnchor),
            chips.bottomAnchor.constraint(equalTo: group.contentView.bottomAnchor),

            group.topAnchor.constraint(equalTo: content.topAnchor),
            group.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            group.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            group.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.heightAnchor.constraint(equalTo: group.heightAnchor),
        ])
        return scroll
    }

    private func refreshBodyWeightChip() {
        do {
            let hero = TrendWeight.hero(of: try dependencies.store.bodyWeights().map(\.kilograms))
            bodyWeightChip.subtitle = hero.map { dependencies.preferences.massUnit.displayText(fromKilograms: $0) }
        } catch {
            Self.logger.error("Failed to read Body Weight: \(error, privacy: .public)")
            bodyWeightChip.subtitle = nil
        }
    }

    private func showBodyWeight() {
        navigationController?.pushViewController(BodyWeightViewController(dependencies: dependencies), animated: true)
    }
}
