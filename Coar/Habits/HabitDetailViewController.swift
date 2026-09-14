import UIKit
import os

/// A Habit's detail, pushed from its card: the streak as the hero and a month calendar for
/// fixing past Days (tapping a Day toggles its Check-in). Archive lives in the toolbar
/// menu; an archived Habit is restored or deleted from the tab's Archived section.
final class HabitDetailViewController: ScreenViewController {

    private static let logger = Logger(category: "Habits")

    private let dependencies: AppDependencies
    private let habitID: HabitRecord.ID
    private let streakLabel = UILabel()
    private let unitLabel = UILabel()
    private let calendar = MonthCalendarView()

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

        streakLabel.font = UIFont.heroNumber
        streakLabel.adjustsFontForContentSizeCategory = true
        streakLabel.setContentHuggingPriority(.required, for: .horizontal)
        unitLabel.font = UIFont.label
        unitLabel.textColor = UIColor.textSecondary
        unitLabel.adjustsFontForContentSizeCategory = true
        let hero = UIStackView(arrangedSubviews: [streakLabel, unitLabel])
        hero.axis = .horizontal
        hero.alignment = .firstBaseline
        hero.spacing = Metrics.spaceTight

        let streakCard = CardView(title: "Streak", systemImage: "flame.fill")
        streakCard.contentStack.addArrangedSubview(hero)
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

    // MARK: - Rendering

    private func render() {
        let today = Day.today()
        do {
            guard let habit = try dependencies.store.habit(habitID) else {
                navigationController?.popViewController(animated: true)
                return
            }
            let checkIns = try dependencies.store.checkIns(for: habitID)
            let model = HabitCardModel(habit: habit, checkIns: checkIns, today: today, columns: 1)
            title = "\(habit.emoji) \(habit.name)"
            streakLabel.text = String(model.streak)
            streakLabel.textColor = model.streak == 0 ? UIColor.textTertiary : UIColor.textPrimary
            unitLabel.text = model.streakUnit
            let met = Set(checkIns.filter { HabitCardModel.meets(habit: habit, amount: $0.amount) }.map(\.day))
            calendar.model = .init(today: today, met: met)
        } catch {
            Self.logger.error("Failed to read Habit: \(error, privacy: .public)")
        }
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
