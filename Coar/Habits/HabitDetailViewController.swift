import UIKit
import os

/// A Habit's detail, pushed from its card: the streak as the hero, the target in force with
/// a way to change it (a new dated record effective today, ADR 0003), and a month calendar
/// for fixing past Days (tapping a Day toggles a yes/no Check-in or opens the number sheet
/// for a quantitative one). Archive lives in the toolbar menu; an archived Habit is restored
/// or deleted from the tab's Archived section.
final class HabitDetailViewController: ScreenViewController {

    private static let logger = Logger(category: "Habits")

    private let dependencies: AppDependencies
    private let habitID: HabitRecord.ID
    private let streak = StreakHeroView()
    private let targetValueLabel = UILabel()
    private let targetUnitLabel = UILabel()
    private let calendar = MonthCalendarView()
    private let itemsLabel = UILabel()
    private lazy var itemsCard = makeItemsCard()
    private var habit: HabitRecord?
    /// False once a render finds the Habit gone (deleted elsewhere); the screen pops itself
    /// once it is fully on screen, never mid-transition.
    private var habitExists = true

    init(dependencies: AppDependencies, habitID: HabitRecord.ID) {
        self.dependencies = dependencies
        self.habitID = habitID
        super.init(title: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never

        let archive = UIAction(title: "Archive", image: UIImage(systemName: "archivebox")) { [weak self] _ in self?.archive() }
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: [archive]))
        more.accessibilityLabel = "More"
        navigationItem.rightBarButtonItem = more

        let streakCard = CardView(title: "Streak", systemImage: "flame.fill", iconTint: UIColor.accentAmber)
        streakCard.contentStack.addArrangedSubview(streak)
        contentStack.addArrangedSubview(streakCard)

        contentStack.addArrangedSubview(makeTargetCard())
        contentStack.addArrangedSubview(itemsCard)
        itemsCard.isHidden = true

        calendar.onTapDay = { [weak self] day in self?.edit(day) }
        let calendarCard = CardView()
        calendarCard.contentStack.addArrangedSubview(calendar)
        contentStack.addArrangedSubview(calendarCard)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        popIfGone()
    }

    // MARK: - Rendering

    private func makeTargetCard() -> UIView {
        targetValueLabel.font = UIFont.metricNumber
        targetValueLabel.textColor = UIColor.accentGreen
        targetValueLabel.adjustsFontForContentSizeCategory = true
        targetValueLabel.setContentHuggingPriority(.required, for: .horizontal)
        targetUnitLabel.font = UIFont.label
        targetUnitLabel.textColor = UIColor.textSecondary
        targetUnitLabel.adjustsFontForContentSizeCategory = true

        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.title = "Change"
        configuration.titleTextAttributesTransformer = .cardTitle
        let change = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in self?.presentChangeTarget() })
        change.accessibilityLabel = "Change target"
        change.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [targetValueLabel, targetUnitLabel, change])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metrics.spaceTight

        let card = CardView(title: "Target", systemImage: "scope", iconTint: UIColor.accentGreen)
        card.contentStack.addArrangedSubview(row)
        return card
    }

    /// A checklist's Items, one per line, with Edit (hidden for the other kinds).
    private func makeItemsCard() -> UIView {
        itemsLabel.font = UIFont.bodyText
        itemsLabel.textColor = UIColor.textPrimary
        itemsLabel.adjustsFontForContentSizeCategory = true
        itemsLabel.numberOfLines = 0

        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.title = "Edit"
        configuration.titleTextAttributesTransformer = .cardTitle
        let edit = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in self?.presentEditItems() })
        edit.accessibilityLabel = "Edit items"
        edit.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [itemsLabel, edit])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = Metrics.spaceTight

        let card = CardView(title: "Items", systemImage: "checklist", iconTint: UIColor.accentGreen)
        card.contentStack.addArrangedSubview(row)
        return card
    }

    /// A tracked Habit's values from the last read; `render` draws with them, then reads
    /// again (Apple Health is async) and draws once more if they changed.
    private var trackedValues: [Day: Double] = [:]
    private var trackedLoad: Task<Void, Never>?

    private func render(refreshingTracked: Bool = true) {
        let today = Day.today()
        do {
            guard let habit = try dependencies.store.habit(habitID) else {
                habitExists = false
                popIfGone()
                return
            }
            self.habit = habit
            let model = HabitCardModel(habit: habit, checkIns: try dependencies.store.checkIns(for: habitID), trackedValues: trackedValues, today: today, columns: 1)
            if refreshingTracked, let tracking = habit.tracking {
                trackedLoad?.cancel()
                trackedLoad = Task { [weak self] in
                    guard let self else { return }
                    let values = await TrackedValues.load(tracking, store: dependencies.store, health: dependencies.healthReader, today: today)
                    guard !Task.isCancelled, values != trackedValues else { return }
                    trackedValues = values
                    render(refreshingTracked: false)
                }
            }
            title = "\(habit.emoji) \(habit.name)"
            streak.setStreak(model.streak, unit: model.streakUnit, caption: model.weekCaption)
            let summary = model.target?.summary(for: habit.kind, tracking: habit.tracking)
            targetValueLabel.text = summary?.value ?? "—"
            targetValueLabel.textColor = summary == nil ? UIColor.textTertiary : UIColor.accentGreen
            targetUnitLabel.text = [summary?.unit, habit.tracking?.metric.source].compactMap { $0 }.joined(separator: "\n")
            targetUnitLabel.numberOfLines = 0
            itemsCard.isHidden = habit.kind != .checklist
            itemsLabel.text = habit.items.map(\.name).joined(separator: "\n")
            calendar.model = .init(today: today, levels: model.levels, editableFrom: model.editableFrom)
        } catch {
            Self.logger.error("Failed to read Habit: \(error, privacy: .public)")
        }
    }

    private func popIfGone() {
        guard !habitExists, viewIfLoaded?.window != nil, presentedViewController == nil,
              navigationController?.transitionCoordinator == nil
        else { return }
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Actions

    /// A yes/no Day toggles its Check-in; a quantitative Day opens its number sheet, a
    /// checklist Day its list for that Day's Period.
    private func edit(_ day: Day) {
        guard let habit else { return }
        if let sheet = HabitCheckInSheet.sheet(for: habit, dependencies: dependencies, day: day, onChange: { [weak self] in self?.render() }) {
            present(sheet, animated: true)
        } else {
            toggle(day)
        }
    }

    private func presentChangeTarget() {
        guard let habit else { return }
        let sheet = HabitTargetViewController.sheet(dependencies: dependencies, habit: habit, target: habit.target(inForceOn: .today())) { [weak self] in
            self?.render()
        }
        present(sheet, animated: true)
    }

    private func presentEditItems() {
        guard let habit else { return }
        present(HabitItemsViewController.sheet(dependencies: dependencies, habit: habit) { [weak self] in self?.render() }, animated: true)
    }

    private func toggle(_ day: Day) {
        do {
            if try dependencies.store.checkIn(habitID, on: day) == nil {
                try dependencies.store.checkIn(habitID, on: day, amount: 1)
            } else {
                try dependencies.store.removeCheckIn(habitID, on: day)
            }
        } catch {
            Self.logger.error("Failed to toggle Check-in: \(error, privacy: .public)")
        }
        render()
    }

    private func archive() {
        do {
            try dependencies.store.archiveHabit(habitID)
            navigationController?.popViewController(animated: true)
        } catch {
            Self.logger.error("Failed to archive Habit: \(error, privacy: .public)")
        }
    }
}
