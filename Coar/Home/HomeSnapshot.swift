import Foundation
import os

/// One of Home's four small tiles as it renders (DESIGN.md §1.5): a value, or nil for `—`
/// in the same slot, and a caption under it naming what the value is.
struct HomeTile: Equatable {
    var value: String?
    var caption: String
    /// Tapping the tile shows the Apple Health prompt instead of the detail (spec story 80).
    var connects = false
}

/// Everything Home shows for today, derived once per render through the façade and the
/// Apple Health reader; nothing here is stored. Every card keeps its place whatever is
/// missing: no Target means a bare calorie count and empty bars, no Body Weight means `—`,
/// and Health with nothing to say means `—`, never a 0 (`.scratch/data-model/issues/02`).
struct HomeSnapshot: Equatable {

    struct Habits: Equatable {
        /// The active check-in Habits still to do today, in the user's order. Tracked Habits
        /// are left out; Coar keeps them itself, and Home's other cards show their data.
        let toDo: [HabitCardModel]
        /// The ones done for today (or for this week), in the user's order; shown on request.
        let done: [HabitCardModel]
        /// "3 of 7 done", or why there is nothing to list.
        let summary: String

        static let none = Habits(toDo: [], done: [], summary: "No habits yet")
        static let onlyTracked = Habits(toDo: [], done: [], summary: "No check-in habits")
    }

    struct Macros: Equatable {
        /// The ring's centre: calories left ("1,420"), over ("150"), or eaten without a Target.
        let calories: String
        /// "kcal left", "kcal over", or "kcal" without a Target.
        let caloriesCaption: String
        /// How much of the calorie Target was eaten, 0 to 1; nil without a Target.
        let calorieProgress: Double?
        /// Protein, fat, and carbs.
        let bars: [MacroBar]
        /// A Target is in force today; without one the card offers to set targets.
        let hasTarget: Bool
    }

    struct MacroBar: Equatable {
        let macro: Macro
        /// "32": what was eaten today.
        let consumed: String
        /// "/180g" against the Target in force; "g" without one.
        let target: String
        /// How much of the Target was eaten, 0 to 1; nil without a Target.
        let progress: Double?
    }

    let habits: Habits
    let macros: Macros
    let sleep: HomeTile
    let steps: HomeTile
    let bodyWeight: HomeTile
    let training: HomeTile

    private static let logger = Logger(category: "Home")

    /// What Home shows until the first load lands: every slot empty, so a fresh Home never
    /// claims "No habits yet" for the instant before it knows.
    static let placeholder = HomeSnapshot(
        habits: Habits(toDo: [], done: [], summary: ""),
        macros: Macros(calories: "—", caloriesCaption: "kcal", calorieProgress: nil, bars: [Macro.protein, .fat, .carbs].map { MacroBar(macro: $0, consumed: "—", target: "g", progress: nil) }, hasTarget: true),
        sleep: HomeTile(value: nil, caption: HealthMetric.sleep.title),
        steps: HomeTile(value: nil, caption: HealthMetric.steps.title),
        bodyWeight: HomeTile(value: nil, caption: ""),
        training: HomeTile(value: nil, caption: "This week")
    )

    /// Reads today through the façade and Apple Health. A façade failure throws; a Health
    /// read that fails is logged and its tile shows `—`, as the details do.
    @MainActor
    static func load(store: Store, health: HealthReader, healthStatus: HealthAccessStatus, unit: MassUnit, today: Day) async throws -> HomeSnapshot {
        HomeSnapshot(
            habits: try habits(from: store, today: today),
            macros: try macros(from: store, today: today),
            sleep: await healthTile(.sleep, from: health, status: healthStatus, today: today),
            steps: await healthTile(.steps, from: health, status: healthStatus, today: today),
            bodyWeight: try bodyWeight(from: store, unit: unit),
            training: try training(from: store, today: today)
        )
    }

    @MainActor
    private static func habits(from store: Store, today: Day) throws -> Habits {
        let habits = try store.habits()
        let rows = try habits.filter { $0.tracking == nil }.map {
            HabitCardModel(habit: $0, checkIns: try store.checkIns(for: $0.id), today: today)
        }
        guard !rows.isEmpty else { return habits.isEmpty ? .none : .onlyTracked }
        let done = rows.filter(isDone)
        return Habits(toDo: rows.filter { !isDone($0) }, done: done, summary: "\(done.count) of \(rows.count) done")
    }

    /// Done for Home: checked in today, or a weekly Habit whose week is already met.
    private static func isDone(_ row: HabitCardModel) -> Bool {
        row.isDoneToday || row.isWeekMet
    }

    @MainActor
    private static func macros(from store: Store, today: Day) throws -> Macros {
        let consumed = Coar.Macros.sum(try store.entries(on: today).map(\.macros))
        let target = try store.target(inForceOn: today)?.macros
        let bars = [Macro.protein, .fat, .carbs].map { macro in
            MacroBar(
                macro: macro,
                consumed: MacroSummary.amountText(consumed[macro]),
                target: target.map { "/\(MacroSummary.amountText($0[macro]))\(macro.unit)" } ?? macro.unit,
                progress: target.map { progress(consumed[macro], of: $0[macro]) }
            )
        }
        guard let target, target.calories > 0 else {
            return Macros(calories: MacroSummary.amountText(consumed.calories), caloriesCaption: "kcal", calorieProgress: nil, bars: bars, hasTarget: target != nil)
        }
        let left = target.calories - consumed.calories
        return Macros(
            calories: MacroSummary.amountText(abs(left.rounded())),
            caloriesCaption: left.rounded() < 0 ? "kcal over" : "kcal left",
            calorieProgress: progress(consumed.calories, of: target.calories),
            bars: bars,
            hasTarget: true
        )
    }

    /// Eaten against a Target, capped at full; a zero Target reads as nothing to fill.
    private static func progress(_ consumed: Double, of target: Double) -> Double {
        target > 0 ? min(1, max(0, consumed / target)) : 0
    }

    /// Trend Weight once there are two points, the raw value before that, `—` with none
    /// (CONTEXT.md "Trend Weight"); the unit is the caption.
    @MainActor
    private static func bodyWeight(from store: Store, unit: MassUnit) throws -> HomeTile {
        let kilograms = try store.bodyWeights().map(\.kilograms)
        return HomeTile(value: TrendWeight.hero(of: kilograms).map { unit.displayValueText(fromKilograms: $0) }, caption: unit.symbol)
    }

    /// Days with a Workout (Activities included) this Monday-to-Sunday week, against the
    /// weekly workouts Habit's target when there is one: "1/3", or "1" without.
    @MainActor
    private static func training(from store: Store, today: Day) throws -> HomeTile {
        let days = try store.workoutDays(from: today.startOfWeek, to: today).count
        let goal = try store.habits()
            .first { $0.tracking?.metric == .workouts && $0.target(inForceOn: today)?.period == .week }
            .flatMap { $0.target(inForceOn: today)?.amount }
        return HomeTile(value: goal.map { "\(days)/\(HabitAmount.text($0))" } ?? String(days), caption: "This week")
    }

    /// Today's Time Asleep or Steps; `—` when Health has none, offering the prompt while it
    /// has never been shown.
    private static func healthTile(_ metric: HealthMetric, from health: HealthReader, status: HealthAccessStatus, today: Day) async -> HomeTile {
        var value: Double?
        do {
            value = try await metric.read([today], from: health)[today]
        } catch {
            logger.error("Failed to read \(metric.title, privacy: .public) from Apple Health: \(error, privacy: .public)")
        }
        let connects = value == nil && status == .notRequested
        return HomeTile(value: value.map(metric.text), caption: connects ? "Connect" : metric.title, connects: connects)
    }
}
