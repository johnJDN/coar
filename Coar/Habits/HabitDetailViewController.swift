import UIKit
import os

/// A Habit's detail, pushed from its card: the streak as the hero and a month calendar for
/// fixing past Days (tapping a Day toggles its Check-in). Archive lives in the toolbar
/// menu; an archived Habit is restored or deleted from the tab's Archived section.
final class HabitDetailViewController: ScreenViewController {

    private static let logger = Logger(category: "Habits")

    private let dependencies: AppDependencies
    private let habitID: HabitRecord.ID
    private let streak = StreakHeroView()
    private let calendar = MonthCalendarView()
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

        calendar.onTapDay = { [weak self] day in self?.toggle(day) }
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

    private func render() {
        let today = Day.today()
        do {
            guard let habit = try dependencies.store.habit(habitID) else {
                habitExists = false
                popIfGone()
                return
            }
            let model = HabitCardModel(habit: habit, checkIns: try dependencies.store.checkIns(for: habitID), today: today, columns: 1)
            title = "\(habit.emoji) \(habit.name)"
            streak.setStreak(model.streak, unit: model.streakUnit)
            calendar.model = .init(today: today, met: model.met)
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
