import UIKit

/// One row of the Day page's timeline (`.scratch/day-page/issues/06`).
struct DayItem: Equatable {
    enum Kind: Equatable {
        case woke, fellAsleep
        case meal(EntryRecord.ID)
        case workout(WorkoutRecord.ID)
        case healthWorkout
        case weighIn
        case journal
    }

    let kind: Kind
    /// Where it sorts: minutes after this Day's midnight (past 1,440 for after midnight).
    let minute: Int
    /// Whether the time is only the part of the Day ("Morning").
    let isApproximate: Bool
    let systemImage: String
    let tint: UIColor
    let title: String
    let detail: String?

    /// "7:40 AM", or "Morning" for an approximate one.
    var timeText: String {
        if isApproximate { return PartOfDay.containing(minute: minute % 1_440).title }
        let hour = (minute / 60) % 24, minutes = minute % 60
        let date = Calendar.current.date(bySettingHour: hour, minute: minutes, second: 0, of: Date(timeIntervalSinceReferenceDate: 0))!
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// How a Day's timeline is put together (a pure rule): everything Coar knows about the Day,
/// in time order. A journal event without a time sits at the start of its part of the Day,
/// after anything timed there, in the entry's order. Journal meals are left out when the Day
/// has a food log; Watch workouts linked to a Coar Workout show as that Workout.
enum DayTimeline {

    struct Inputs {
        var day: Day
        var woke: Date?
        var fellAsleep: Date?
        var entries: [EntryRecord] = []
        var workouts: [WorkoutRecord] = []
        var healthWorkouts: [HealthWorkout] = []
        var weighedIn: String?
        var journal: [JournalEventRecord] = []
    }

    static func items(_ inputs: Inputs, calendar: Calendar = .current) -> [DayItem] {
        let midnight = inputs.day.start(in: calendar)
        func minute(_ date: Date) -> Int { Int(date.timeIntervalSince(midnight) / 60) }
        var items: [DayItem] = []

        if let woke = inputs.woke {
            items.append(DayItem(kind: .woke, minute: minute(woke), isApproximate: false, systemImage: "sun.max.fill", tint: UIColor.accentTeal, title: "Woke up", detail: nil))
        }
        for entry in inputs.entries {
            items.append(DayItem(kind: .meal(entry.id), minute: minute(entry.loggedAt), isApproximate: false, systemImage: "fork.knife", tint: UIColor.accentAmber,
                                 title: entry.name, detail: FoodText.calories(entry.macros)))
        }
        let linked = Set(inputs.workouts.compactMap(\.healthWorkoutID))
        for workout in inputs.workouts {
            let effort = inputs.healthWorkouts.first { $0.id == workout.healthWorkoutID }?.effortText
            items.append(DayItem(kind: .workout(workout.id), minute: minute(workout.startedAt), isApproximate: false, systemImage: "dumbbell.fill", tint: UIColor.accentGreen,
                                 title: workout.title, detail: [workout.duration.map(Self.duration), effort].compactMap { $0 }.joined(separator: " · ").nilIfEmpty))
        }
        for health in inputs.healthWorkouts where !linked.contains(health.id) {
            items.append(DayItem(kind: .healthWorkout, minute: minute(health.start), isApproximate: false, systemImage: "applewatch", tint: UIColor.accentGreen,
                                 title: health.name, detail: [Self.duration(health.duration), health.effortText].compactMap { $0 }.joined(separator: " · ")))
        }
        if let weighedIn = inputs.weighedIn {
            items.append(DayItem(kind: .weighIn, minute: PartOfDay.morning.anchorMinute, isApproximate: true, systemImage: "scalemass.fill", tint: UIColor.accentTeal, title: "Weighed in", detail: weighedIn))
        }
        let hasFoodLog = !inputs.entries.isEmpty
        for event in inputs.journal where !(hasFoodLog && event.category == .food) {
            let at = event.minuteOfDay ?? (event.partOfDay ?? .morning).anchorMinute
            items.append(DayItem(kind: .journal, minute: at, isApproximate: event.minuteOfDay == nil, systemImage: event.category.systemImage, tint: event.category.tint,
                                 title: event.title, detail: nil))
        }
        if let fellAsleep = inputs.fellAsleep {
            items.append(DayItem(kind: .fellAsleep, minute: minute(fellAsleep), isApproximate: false, systemImage: "moon.fill", tint: UIColor.accentTeal, title: "Fell asleep", detail: nil))
        }
        // Timed before approximate at the same minute; otherwise the order they were added,
        // which keeps a journal entry's events in its own order.
        return items.enumerated().sorted { lhs, rhs in
            (lhs.element.minute, lhs.element.isApproximate ? 1 : 0, lhs.offset) < (rhs.element.minute, rhs.element.isApproximate ? 1 : 0, rhs.offset)
        }.map(\.element)
    }

    /// "1h 05m", "45m".
    static func duration(_ seconds: TimeInterval) -> String {
        HealthText.duration(seconds)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
