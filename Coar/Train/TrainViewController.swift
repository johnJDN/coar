import UIKit
import os

/// The Train root (DESIGN.md §11): the month grid of Workout Days (tap one to open its
/// Workout, or the list when there were several), the row of three `PillChip`s, Start (a
/// Plan or an empty Workout; Resume while one is active), the Plans section (tap a card to
/// edit, New plan to add), Recent workouts, and an Archived section with Restore.
final class TrainViewController: ScreenViewController {

    private static let logger = Logger(category: "Train")
    private static let recentLimit = 5

    private let dependencies: AppDependencies
    private let calendar = MonthCalendarView()
    private let exercisesChip = PillChipView(title: "Exercises", systemImage: "figure.strengthtraining.traditional", tint: UIColor.accentLime)
    private let bodyWeightChip = PillChipView(title: "Body Weight", systemImage: "scalemass.fill", tint: UIColor.accentTeal)
    private let photosChip = PillChipView(title: "Progress Photos", systemImage: "camera.fill", tint: UIColor.accentLavender)
    private let startButton = UIButton(configuration: .prominentGlass())
    /// The Workout Resume opens; nil while Start offers the menu instead.
    private var activeWorkoutID: WorkoutRecord.ID?
    private let plansStack = UIStackView()
    private let recentStack = UIStackView()
    private let archivedHeader = TrainViewController.sectionHeader("Archived")
    private let archivedStack = UIStackView()

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(title: "Train")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        calendar.onTapDay = { [weak self] day in self?.openDay(day) }
        let grid = CardView()
        grid.contentStack.addArrangedSubview(calendar)
        contentStack.addArrangedSubview(grid)

        contentStack.addArrangedSubview(chipRow())

        configureStartButton()
        contentStack.addArrangedSubview(startButton)
        contentStack.setCustomSpacing(Metrics.spaceSection, after: startButton)

        let plansHeader = Self.sectionHeader("Plans")
        contentStack.addArrangedSubview(plansHeader)
        contentStack.setCustomSpacing(Metrics.spaceTight, after: plansHeader)
        plansStack.axis = .vertical
        plansStack.spacing = Metrics.spaceCard
        contentStack.addArrangedSubview(plansStack)

        let newPlan = newPlanRow()
        contentStack.addArrangedSubview(newPlan)
        contentStack.setCustomSpacing(Metrics.spaceSection, after: newPlan)

        let recentHeader = Self.sectionHeader("Recent workouts")
        contentStack.addArrangedSubview(recentHeader)
        contentStack.setCustomSpacing(Metrics.spaceTight, after: recentHeader)
        recentStack.axis = .vertical
        recentStack.spacing = Metrics.spaceCard
        contentStack.addArrangedSubview(recentStack)
        contentStack.setCustomSpacing(Metrics.spaceSection, after: recentStack)

        contentStack.addArrangedSubview(archivedHeader)
        contentStack.setCustomSpacing(Metrics.spaceTight, after: archivedHeader)
        archivedStack.axis = .vertical
        archivedStack.spacing = Metrics.spaceCard
        contentStack.addArrangedSubview(archivedStack)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshChips()
        renderGrid()
        renderPlans()
        renderStart()
        renderRecent()
    }

    // MARK: - Chips

    private func chipRow() -> UIView {
        exercisesChip.addAction(UIAction { [weak self] _ in self?.showExercises() }, for: .touchUpInside)
        bodyWeightChip.addAction(UIAction { [weak self] _ in self?.showBodyWeight() }, for: .touchUpInside)
        photosChip.addAction(UIAction { [weak self] _ in self?.showProgressPhotos() }, for: .touchUpInside)

        let chips = UIStackView(arrangedSubviews: [exercisesChip, bodyWeightChip, photosChip])
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
        } catch {
            Self.logger.error("Failed to read Body Weight: \(error, privacy: .public)")
            bodyWeightChip.subtitle = nil
        }
        do {
            let count = try dependencies.store.exercises().count
            exercisesChip.subtitle = count == 0 ? nil : TrainText.count(count, "exercise")
        } catch {
            Self.logger.error("Failed to read Exercises: \(error, privacy: .public)")
            exercisesChip.subtitle = nil
        }
        do {
            let count = try dependencies.store.progressPhotos().count
            photosChip.subtitle = count == 0 ? nil : TrainText.count(count, "photo")
        } catch {
            Self.logger.error("Failed to read Progress Photos: \(error, privacy: .public)")
            photosChip.subtitle = nil
        }
    }

    // MARK: - Month grid

    /// Days with a Workout light up `accentGreen` and open it; every other Day is inert.
    private func renderGrid() {
        let today = Day.today()
        let days: Set<Day>
        do {
            days = try dependencies.store.workoutDays(from: .distantPast, to: today)
        } catch {
            Self.logger.error("Failed to read Workout Days: \(error, privacy: .public)")
            days = []
        }
        calendar.model = .init(
            today: today,
            levels: Dictionary(uniqueKeysWithValues: days.map { ($0, Heatmap.Level.done) }),
            editableFrom: .distantPast,
            tappableDays: days
        )
    }

    private func openDay(_ day: Day) {
        let workouts: [WorkoutRecord]
        do {
            workouts = try dependencies.store.workouts(on: day)
        } catch {
            Self.logger.error("Failed to read Workouts: \(error, privacy: .public)")
            return
        }
        guard let only = workouts.first else { return }
        let screen = workouts.count == 1
            ? WorkoutScreens.screen(for: only, dependencies: dependencies)
            : WorkoutsOnDayViewController(dependencies: dependencies, day: day)
        navigationController?.pushViewController(screen, animated: true)
    }

    // MARK: - Start

    private func configureStartButton() {
        startButton.configuration?.imagePadding = Metrics.spaceTight
        startButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .headline)
        startButton.configuration?.cornerStyle = .capsule
        startButton.configuration?.baseBackgroundColor = UIColor.accentGreen
        startButton.configuration?.baseForegroundColor = .white
        startButton.configuration?.titleTextAttributesTransformer = .cardTitle
        startButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        startButton.addAction(UIAction { [weak self] _ in
            guard let self, let activeWorkoutID else { return }
            showLogger(for: activeWorkoutID)
        }, for: .touchUpInside)
    }

    /// Start offers each active Plan and "Empty workout" as a menu; while a Workout is active
    /// the button reads Resume and goes straight to the logger (CONTEXT.md "Active Workout").
    private func renderStart() {
        let active: WorkoutRecord?
        let plans: [PlanRecord]
        do {
            active = try dependencies.store.activeWorkout()
            plans = try dependencies.store.plans()
        } catch {
            Self.logger.error("Failed to read for Start: \(error, privacy: .public)")
            return
        }
        activeWorkoutID = active?.id
        startButton.configuration?.image = UIImage(systemName: "play.fill")
        if let active {
            startButton.configuration?.title = "Resume workout"
            startButton.configuration?.subtitle = "\(active.title) · since \(TrainText.timeText(active.startedAt))"
            startButton.menu = nil
            startButton.showsMenuAsPrimaryAction = false
        } else {
            startButton.configuration?.title = "Start workout"
            startButton.configuration?.subtitle = nil
            let fromPlans = plans.map { plan in
                UIAction(title: plan.name, subtitle: TrainText.count(plan.exercises.count, "exercise")) { [weak self] _ in self?.start(from: plan.id) }
            }
            let empty = UIAction(title: "Empty workout", image: UIImage(systemName: "square.dashed")) { [weak self] _ in self?.start(from: nil) }
            startButton.menu = UIMenu(children: fromPlans + [UIMenu(options: .displayInline, children: [empty])])
            startButton.showsMenuAsPrimaryAction = true
        }
        startButton.accessibilityLabel = startButton.configuration?.title
    }

    private func start(from planID: PlanRecord.ID?) {
        do {
            let workout = try dependencies.store.startWorkout(from: planID)
            showLogger(for: workout.id)
        } catch {
            Self.logger.error("Failed to start Workout: \(error, privacy: .public)")
        }
    }

    private func showLogger(for workoutID: WorkoutRecord.ID) {
        navigationController?.pushViewController(WorkoutLoggerViewController(dependencies: dependencies, workoutID: workoutID), animated: true)
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
        let button = UIButton.glassAction(title: "New plan", systemImage: "plus") { [weak self] in self?.showPlanEditor(.create) }
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
            plansStack.addArrangedSubview(CardView.emptyState(caption: "Tap New plan to build your first plan.", accessibilityLabel: "No plans yet. Tap New plan to build your first plan."))
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

    // MARK: - Recent workouts

    private func renderRecent() {
        let recent: [WorkoutRecord]
        do {
            recent = try dependencies.store.recentWorkouts(limit: Self.recentLimit)
        } catch {
            Self.logger.error("Failed to read recent Workouts: \(error, privacy: .public)")
            return
        }
        recentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if recent.isEmpty {
            recentStack.addArrangedSubview(CardView.emptyState(caption: "Finished workouts land here.", accessibilityLabel: "No workouts yet. Finished workouts land here."))
        }
        for workout in recent {
            let card = WorkoutCardControl(workout: workout)
            card.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                navigationController?.pushViewController(WorkoutScreens.screen(for: workout, dependencies: dependencies), animated: true)
            }, for: .touchUpInside)
            recentStack.addArrangedSubview(card)
        }
    }

    private func restore(_ plan: PlanRecord) {
        do {
            try dependencies.store.restorePlan(plan.id)
        } catch {
            Self.logger.error("Failed to restore Plan: \(error, privacy: .public)")
        }
        renderPlans()
        renderStart()
    }

    // MARK: - Navigation

    private func showExercises() {
        navigationController?.pushViewController(ExercisesViewController(dependencies: dependencies), animated: true)
    }

    private func showBodyWeight() {
        navigationController?.pushViewController(BodyWeightViewController(dependencies: dependencies), animated: true)
    }

    private func showProgressPhotos() {
        navigationController?.pushViewController(ProgressPhotosViewController(dependencies: dependencies), animated: true)
    }

    private func showPlanEditor(_ mode: PlanEditorViewController.Mode) {
        navigationController?.pushViewController(PlanEditorViewController(dependencies: dependencies, mode: mode), animated: true)
    }
}
