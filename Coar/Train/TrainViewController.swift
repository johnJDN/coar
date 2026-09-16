import UIKit
import os

/// The Train root (DESIGN.md §11): the month grid, Start, and recent Workouts arrive with
/// ticket 09; for now a placeholder grid card, the row of three `PillChip`s, the Plans
/// section (tap a card to edit, New plan to add), and an Archived section with Restore.
/// Exercises and Body Weight are live; Progress Photos is ticket 12.
final class TrainViewController: ScreenViewController {

    private static let logger = Logger(category: "Train")

    private let dependencies: AppDependencies
    private let exercisesChip = PillChipView(title: "Exercises", systemImage: "figure.strengthtraining.traditional", tint: UIColor.accentLime)
    private let bodyWeightChip = PillChipView(title: "Body Weight", systemImage: "scalemass.fill", tint: UIColor.accentTeal)
    private let plansStack = UIStackView()
    private let archivedHeader = TrainViewController.sectionHeader("Archived")
    private let archivedStack = UIStackView()

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

        let chips = chipRow()
        contentStack.addArrangedSubview(chips)
        contentStack.setCustomSpacing(Metrics.spaceSection, after: chips)

        let plansHeader = Self.sectionHeader("Plans")
        contentStack.addArrangedSubview(plansHeader)
        contentStack.setCustomSpacing(Metrics.spaceTight, after: plansHeader)
        plansStack.axis = .vertical
        plansStack.spacing = Metrics.spaceCard
        contentStack.addArrangedSubview(plansStack)

        let newPlan = newPlanRow()
        contentStack.addArrangedSubview(newPlan)
        contentStack.setCustomSpacing(Metrics.spaceSection, after: newPlan)

        contentStack.addArrangedSubview(archivedHeader)
        contentStack.setCustomSpacing(Metrics.spaceTight, after: archivedHeader)
        archivedStack.axis = .vertical
        archivedStack.spacing = Metrics.spaceCard
        contentStack.addArrangedSubview(archivedStack)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshChips()
        renderPlans()
    }

    // MARK: - Chips

    private func chipRow() -> UIView {
        let photos = PillChipView(title: "Progress Photos", systemImage: "camera.fill", tint: UIColor.accentLavender)
        photos.isEnabled = false
        exercisesChip.addAction(UIAction { [weak self] _ in self?.showExercises() }, for: .touchUpInside)
        bodyWeightChip.addAction(UIAction { [weak self] _ in self?.showBodyWeight() }, for: .touchUpInside)

        let chips = UIStackView(arrangedSubviews: [exercisesChip, bodyWeightChip, photos])
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

    private func refreshChips() {
        do {
            let hero = TrendWeight.hero(of: try dependencies.store.bodyWeights().map(\.kilograms))
            bodyWeightChip.subtitle = hero.map { dependencies.preferences.massUnit.displayText(fromKilograms: $0) }
            let count = try dependencies.store.exercises().count
            exercisesChip.subtitle = count == 0 ? nil : TrainText.count(count, "exercise")
        } catch {
            Self.logger.error("Failed to read the chips: \(error, privacy: .public)")
            bodyWeightChip.subtitle = nil
            exercisesChip.subtitle = nil
        }
    }

    // MARK: - Plans

    private static func sectionHeader(_ title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = UIFont.sectionHeader
        label.textColor = UIColor.textPrimary
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func newPlanRow() -> UIView {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "New plan"
        configuration.image = UIImage(systemName: "plus")
        configuration.imagePadding = Metrics.spaceTight
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .headline)
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.titleTextAttributesTransformer = .cardTitle
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in self?.showPlanEditor(.create) })
        let row = UIStackView(arrangedSubviews: [button])
        row.alignment = .leading
        return row
    }

    private func renderPlans() {
        let plans: [PlanRecord]
        let archived: [PlanRecord]
        do {
            plans = try dependencies.store.plans()
            archived = try dependencies.store.archivedPlans()
        } catch {
            Self.logger.error("Failed to read Plans: \(error, privacy: .public)")
            return
        }

        plansStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if plans.isEmpty {
            plansStack.addArrangedSubview(Self.emptyPlansCard())
        }
        for plan in plans {
            let card = PlanCardControl(plan: plan)
            card.addAction(UIAction { [weak self] _ in self?.showPlanEditor(.edit(plan)) }, for: .touchUpInside)
            plansStack.addArrangedSubview(card)
        }

        archivedStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        archivedHeader.isHidden = archived.isEmpty
        archivedStack.isHidden = archived.isEmpty
        for plan in archived {
            archivedStack.addArrangedSubview(ArchivedPlanView(plan: plan) { [weak self] in self?.restore(plan) })
        }
    }

    /// The empty state (DESIGN.md §1.5): the card the first Plan will occupy.
    private static func emptyPlansCard() -> UIView {
        let card = CardView()
        let hero = UILabel()
        hero.text = "—"
        hero.font = UIFont.heroNumber
        hero.textColor = UIColor.textTertiary
        hero.adjustsFontForContentSizeCategory = true
        let caption = UILabel()
        caption.text = "Tap New plan to build your first plan."
        caption.font = UIFont.label
        caption.textColor = UIColor.textSecondary
        caption.adjustsFontForContentSizeCategory = true
        caption.numberOfLines = 0
        card.contentStack.addArrangedSubview(hero)
        card.contentStack.addArrangedSubview(caption)
        card.isAccessibilityElement = true
        card.accessibilityLabel = "No plans yet. Tap New plan to build your first plan."
        return card
    }

    private func restore(_ plan: PlanRecord) {
        do {
            try dependencies.store.restorePlan(plan.id)
        } catch {
            Self.logger.error("Failed to restore Plan: \(error, privacy: .public)")
        }
        renderPlans()
    }

    // MARK: - Navigation

    private func showExercises() {
        navigationController?.pushViewController(ExercisesViewController(dependencies: dependencies), animated: true)
    }

    private func showBodyWeight() {
        navigationController?.pushViewController(BodyWeightViewController(dependencies: dependencies), animated: true)
    }

    private func showPlanEditor(_ mode: PlanEditorViewController.Mode) {
        navigationController?.pushViewController(PlanEditorViewController(dependencies: dependencies, mode: mode), animated: true)
    }
}
