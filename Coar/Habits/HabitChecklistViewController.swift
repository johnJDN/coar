import SwiftUI
import UIKit
import os

/// The checklist Habit's sheet: its Items with a tick each, for the Period holding `day`
/// (that Day, or its week). A tap writes at once through the façade (`setChecklistItem`),
/// so ticking a supplement mid-morning is one tap and the sheet can be left open all day.
final class HabitChecklistViewController: UIHostingController<HabitChecklist> {

    private static let logger = Logger(category: "Habits")

    private let dependencies: AppDependencies
    private let habitID: HabitRecord.ID
    private let day: Day
    private let onChange: () -> Void

    init(dependencies: AppDependencies, habitID: HabitRecord.ID, day: Day, onChange: @escaping () -> Void) {
        self.dependencies = dependencies
        self.habitID = habitID
        self.day = day
        self.onChange = onChange
        super.init(rootView: HabitChecklist(model: .init(items: [], ticked: [], caption: ""), onToggle: { _, _ in }))
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        load()
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    static func sheet(dependencies: AppDependencies, habitID: HabitRecord.ID, day: Day, onChange: @escaping () -> Void) -> UIViewController {
        HabitChecklistViewController(dependencies: dependencies, habitID: habitID, day: day, onChange: onChange)
            .inSheet(detents: [.medium(), .large()])
    }

    private func load() {
        do {
            guard let habit = try dependencies.store.habit(habitID) else { return }
            let target = habit.target(inForceOn: day)
            let period = target?.period ?? .day
            let ticked = Checklist.ticked(in: try dependencies.store.checkIns(for: habitID), period: period, containing: day)
            let count = ticked.intersection(habit.items.map(\.id)).count
            title = "\(habit.emoji) \(habit.name)"
            navigationItem.subtitle = period == .week ? Self.weekTitle(of: day) : day.title()
            var caption = "\(count) of \(habit.items.count) ticked"
            if let target, Int(target.amount) < habit.items.count {
                caption += " · \(HabitAmount.text(target.amount)) needed"
            }
            rootView = HabitChecklist(
                model: .init(items: habit.items, ticked: ticked, caption: caption),
                onToggle: { [weak self] item, ticked in self?.toggle(item, ticked: ticked) }
            )
        } catch {
            Self.logger.error("Failed to read checklist: \(error, privacy: .public)")
        }
    }

    private func toggle(_ item: HabitItemRecord.ID, ticked: Bool) {
        do {
            try dependencies.store.setChecklistItem(habitID, item: item, on: day, ticked: ticked)
        } catch {
            Self.logger.error("Failed to tick Item: \(error, privacy: .public)")
        }
        load()
        onChange()
    }

    /// "This week", or "Week of Sep 7" for an earlier one.
    private static func weekTitle(of day: Day) -> String {
        day.startOfWeek == Day.today().startOfWeek ? "This week" : "Week of \(day.startOfWeek.shortText)"
    }
}

/// The Items with their ticks (ADR 0001: SwiftUI leaf, values in, closures out).
struct HabitChecklist: View {

    struct Model: Equatable {
        var items: [HabitItemRecord]
        var ticked: Set<HabitItemRecord.ID>
        var caption: String
    }

    let model: Model
    let onToggle: (HabitItemRecord.ID, Bool) -> Void

    var body: some View {
        Form {
            Section {
                ForEach(model.items) { item in
                    let isTicked = model.ticked.contains(item.id)
                    Button {
                        onToggle(item.id, !isTicked)
                    } label: {
                        HStack(spacing: Metrics.spaceInner) {
                            Text(item.name)
                                .foregroundStyle(isTicked ? Color.textSecondary : Color.textPrimary)
                            Spacer()
                            Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(isTicked ? Color.accentGreen : Color.textTertiary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isTicked)
                    .accessibilityLabel(item.name)
                    .accessibilityValue(isTicked ? "Ticked" : "Not ticked")
                    .formRow()
                }
            } footer: {
                Text(model.caption)
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .background(Color.background)
    }
}

/// The sheet a Habit's today control opens: the number sheet for an amount, the checklist
/// for a checklist; nil for a yes/no Habit, which toggles in place. The Habits tab, Home,
/// and the detail's calendar all open check-ins through here.
enum HabitCheckInSheet {
    static func sheet(for habit: HabitRecord, dependencies: AppDependencies, day: Day, onChange: @escaping () -> Void) -> UIViewController? {
        switch habit.kind {
        case .yesNo: return nil
        case .quantitative: return HabitAmountViewController.sheet(dependencies: dependencies, habitID: habit.id, day: day, onChange: onChange)
        case .checklist: return HabitChecklistViewController.sheet(dependencies: dependencies, habitID: habit.id, day: day, onChange: onChange)
        }
    }

    /// The same, looked up by id; nil when the Habit is gone or cannot be read.
    @MainActor
    static func sheet(habitID: HabitRecord.ID, dependencies: AppDependencies, day: Day, onChange: @escaping () -> Void) -> UIViewController? {
        guard let habit = try? dependencies.store.habit(habitID) else { return nil }
        return sheet(for: habit, dependencies: dependencies, day: day, onChange: onChange)
    }
}
