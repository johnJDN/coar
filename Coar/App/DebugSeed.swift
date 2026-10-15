#if DEBUG
import Foundation

/// Sample records for looking at screens in the simulator. Launch a debug build with
/// `-SeedSampleData` and the process runs on an in-memory store (no CloudKit, nothing kept)
/// holding two Habits with today's Check-ins, a Target, a morning and a lunch of Entries, a Meal,
/// three Body Weights, and a finished Workout from a Plan yesterday. Never used by tests.
enum DebugSeed {

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-SeedSampleData")
    }

    @MainActor
    static func store() -> Store {
        let store = Store.inMemory()
        do {
            let today = Day.today()
            let calendar = Calendar.current
            let at = { (day: Day, hour: Int, minute: Int) in
                calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day.start())!
            }

            let phone = try store.createHabit(emoji: "📵", name: "No phone on waking", kind: .yesNo, targetAmount: 1, period: .day, effectiveFrom: today.advanced(by: -10))
            let read = try store.createHabit(emoji: "📖", name: "Read", kind: .quantitative, targetAmount: 20, period: .day, effectiveFrom: today.advanced(by: -10))
            try store.createHabit(emoji: "🏃", name: "Run", kind: .yesNo, targetAmount: 3, period: .week, effectiveFrom: today.advanced(by: -10))
            try store.checkIn(phone.id, on: today, amount: 1)
            try store.checkIn(read.id, on: today, amount: 12)
            let supplements = try store.createHabit(
                emoji: "💊", name: "Supplements", kind: .checklist, targetAmount: 3, period: .day,
                items: ["Vitamin D", "Fish oil", "Magnesium"].map { HabitItemDraft(name: $0) }, effectiveFrom: today.advanced(by: -10)
            )
            try store.setChecklistItem(supplements.id, item: supplements.items[0].id, on: today, ticked: true)
            try store.createHabit(
                emoji: "🏋️", name: "Work out 3 days a week", kind: .tracked, targetAmount: 3, period: .week,
                tracking: HabitTracking(metric: .workouts, comparison: .atLeast), effectiveFrom: today.advanced(by: -10)
            )
            try store.createHabit(
                emoji: "🔥", name: "Calories under 110%", kind: .tracked, targetAmount: 110, period: .day,
                tracking: HabitTracking(metric: .calories, comparison: .atMost), effectiveFrom: today.advanced(by: -10)
            )

            try store.setTarget(Macros(calories: 2_100, protein: 180, fat: 60, carbs: 210), effectiveFrom: today.advanced(by: -10))
            let eggs = try store.createFoodItem(name: "Eggs", servings: [ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), isDefault: true)])
            let rice = try store.createFoodItem(name: "Rice", servings: [ServingDraft(name: "1 cup", macros: Macros(calories: 200, protein: 4, fat: 0, carbs: 44), isDefault: true)])
            try store.logEntry(foodItem: eggs.id, serving: eggs.servings[0].id, quantity: 4, at: at(today, 8, 0))
            try store.logEntry(foodItem: rice.id, serving: rice.servings[0].id, quantity: 2, at: at(today, 12, 30))
            try store.createMeal(name: "Eggs & rice", components: [
                MealComponentDraft(foodItemID: eggs.id, servingID: eggs.servings[0].id, quantity: 2),
                MealComponentDraft(foodItemID: rice.id, servingID: rice.servings[0].id, quantity: 1),
            ])

            // Four months of most-days weigh-ins drifting from 88 to 84 kg, with water swings.
            for offset in stride(from: -120, through: -1, by: 1) where offset % 7 != -3 && offset % 11 != -5 {
                let swing = sin(Double(offset) * 1.7) * 0.6 + cos(Double(offset) * 0.6) * 0.3
                try store.logBodyWeight(kilograms: ((84.0 - Double(offset) * 4 / 120 + swing) * 10).rounded() / 10, on: today.advanced(by: offset))
            }

            let bench = try store.createExercise(name: "Bench press", muscleGroup: .chest, secondaryMuscleGroups: [.triceps, .shoulders], equipment: "Barbell", restSeconds: 150)
            let push = try store.createPlan(name: "Push", exercises: [
                PlanExerciseDraft(exerciseID: bench.id, supersetGroup: nil, sets: PlanDraft.defaultSets.map { PlannedSetDraft(targetKilograms: 60, reps: $0) }),
            ])
            let started = at(today.advanced(by: -1), 18, 0)
            let workout = try store.startWorkout(from: push.id, at: started)
            try store.finishWorkout(workout.id, at: started.addingTimeInterval(50 * 60))
        } catch {
            assertionFailure("Seeding sample data failed: \(error)")
        }
        return store
    }
}
#endif
