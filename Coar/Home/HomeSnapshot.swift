import Foundation
import os

/// One Home square as it renders (DESIGN.md §1.5): a hero value, or nil for the empty form
/// in the same slot (`—`; `No data` for a Health square), and a caption under it.
struct HomeSquare: Equatable {
    var value: String?
    var caption: String
    /// Tapping the empty value slot can show the Apple Health prompt (spec story 80).
    var connects = false

    static let noBodyWeight = HomeSquare(value: nil, caption: "No Body Weight yet")
    static let noWorkout = HomeSquare(value: nil, caption: "No workouts yet")
}

/// Everything Home shows for today, derived once per render through the façade and the
/// Apple Health reader; nothing here is stored. Every card keeps its place whatever is
/// missing: no Target means `— target` captions and no dots, no Body Weight or Workout
/// means `—`, and Health with nothing to say means `No data`, never a 0
/// (`.scratch/data-model/issues/02`).
struct HomeSnapshot: Equatable {

    struct Habits: Equatable {
        /// The active Habits in the user's order, each judged for today as the Habits tab does.
        let rows: [HabitCardModel]
        /// How many are done today, as the hero; nil with no Habit at all.
        let hero: String?
        let caption: String

        static let none = Habits(rows: [], hero: nil, caption: "No habits yet")
    }

    struct Macros: Equatable {
        let rows: [MacroRow]
        /// A Target is in force today; without one the card offers to set targets.
        let hasTarget: Bool
    }

    struct MacroRow: Equatable {
        let macro: Macro
        /// "1,240": what was eaten today.
        let consumed: String
        /// "of 2,100 kcal" against the Target in force; "— target" without one.
        let targetCaption: String
        /// The `DotMatrix` to draw; nil without a Target.
        let dots: MacroDots?
    }

    let habits: Habits
    let macros: Macros
    let sleep: HomeSquare
    let steps: HomeSquare
    let bodyWeight: HomeSquare
    let lastWorkout: HomeSquare
    /// The Workout the Last Workout square opens; nil when there is none yet.
    let lastWorkoutID: WorkoutRecord.ID?

    private static let logger = Logger(category: "Home")

    /// What Home shows until the first load lands: every slot empty with no caption, so a
    /// fresh Home never claims "No habits yet" for the instant before it knows.
    static let placeholder = HomeSnapshot(
        habits: Habits(rows: [], hero: nil, caption: ""),
        macros: Macros(rows: Macro.allCases.map { MacroRow(macro: $0, consumed: "—", targetCaption: "", dots: nil) }, hasTarget: true),
        sleep: HomeSquare(value: nil, caption: ""),
        steps: HomeSquare(value: nil, caption: ""),
        bodyWeight: HomeSquare(value: nil, caption: ""),
        lastWorkout: HomeSquare(value: nil, caption: ""),
        lastWorkoutID: nil
    )

    /// Reads today through the façade and Apple Health. A façade failure throws; a Health
    /// read that fails is logged and its square shows `No data`, as the details do.
    @MainActor
    static func load(store: Store, health: HealthReader, healthStatus: HealthAccessStatus, unit: MassUnit, today: Day) async throws -> HomeSnapshot {
        let habits = try await habits(from: store, health: health, today: today)
        let macros = try macros(from: store, today: today)
        let bodyWeight = try bodyWeight(from: store, unit: unit)
        let lastWorkout = try store.recentWorkouts(limit: 1).first
        let sleep = await healthSquare(.sleep, from: health, status: healthStatus, today: today)
        let steps = await healthSquare(.steps, from: health, status: healthStatus, today: today)
        return HomeSnapshot(
            habits: habits,
            macros: macros,
            sleep: sleep,
            steps: steps,
            bodyWeight: bodyWeight,
            lastWorkout: lastWorkout.map { HomeSquare(value: $0.day.relativeTitle(to: today), caption: $0.activity?.name ?? $0.planName ?? "Workout") } ?? .noWorkout,
            lastWorkoutID: lastWorkout?.id
        )
    }

    @MainActor
    private static func habits(from store: Store, health: HealthReader, today: Day) async throws -> Habits {
        var rows: [HabitCardModel] = []
        for habit in try store.habits() {
            let values = if let tracking = habit.tracking {
                await TrackedValues.load(tracking, store: store, health: health, today: today)
            } else {
                [Day: Double]()
            }
            rows.append(HabitCardModel(habit: habit, checkIns: try store.checkIns(for: habit.id), trackedValues: values, today: today))
        }
        guard !rows.isEmpty else { return .none }
        let done = rows.filter(\.isDoneToday).count
        return Habits(rows: rows, hero: String(done), caption: "of \(rows.count) done today")
    }

    @MainActor
    private static func macros(from store: Store, today: Day) throws -> Macros {
        let consumed = Coar.Macros.sum(try store.entries(on: today).map(\.macros))
        let target = try store.target(inForceOn: today)?.macros
        let rows = Macro.allCases.map { macro in
            let dots = MacroDots(macro: macro, consumed: consumed[macro], target: target?[macro])
            return MacroRow(
                macro: macro,
                consumed: MacroSummary.amountText(consumed[macro]),
                targetCaption: dots.map { _ in "of \(MacroSummary.amountText(target![macro])) \(macro.unit)" } ?? "— target",
                dots: dots
            )
        }
        return Macros(rows: rows, hasTarget: target != nil)
    }

    /// Trend Weight once there are two points, the raw value before that, `—` with none
    /// (CONTEXT.md "Trend Weight").
    @MainActor
    private static func bodyWeight(from store: Store, unit: MassUnit) throws -> HomeSquare {
        let records = try store.bodyWeights()
        let kilograms = records.map(\.kilograms)
        guard let latest = records.last else { return .noBodyWeight }
        let hasTrend = TrendWeight.current(of: kilograms) != nil
        return HomeSquare(
            value: TrendWeight.hero(of: kilograms).map { unit.displayText(fromKilograms: $0) },
            caption: hasTrend ? "Trend Weight" : "\(latest.day.shortText) · Trend —"
        )
    }

    /// Today's Time Asleep or Steps; `No data` when Health has none, offering the prompt
    /// while it has never been shown.
    private static func healthSquare(_ metric: HealthMetric, from health: HealthReader, status: HealthAccessStatus, today: Day) async -> HomeSquare {
        var value: Double?
        do {
            value = try await metric.read([today], from: health)[today]
        } catch {
            logger.error("Failed to read \(metric.title, privacy: .public) from Apple Health: \(error, privacy: .public)")
        }
        let connects = value == nil && status == .notRequested
        return HomeSquare(
            value: value.map(metric.text),
            caption: connects ? "Tap to connect Apple Health" : metric.periodCaption,
            connects: connects
        )
    }
}
