import XCTest
@testable import Coar

/// Seam 1: the store façade. A Workout is a full copy of its Plan at start time (ADR 0003),
/// there is never more than one Active Workout, Finish keeps only the sets actually
/// performed, and the optional write-back moves weights to the Plan and nothing else
/// (CONTEXT.md "Workout", "Active Workout", "Logged Set").
@MainActor
final class WorkoutTests: XCTestCase {

    private struct Catalogue {
        let bench: ExerciseRecord
        let row: ExerciseRecord
        let squat: ExerciseRecord
    }

    private func stock(_ store: Store) throws -> Catalogue {
        Catalogue(
            bench: try store.createExercise(name: "Bench press", muscleGroup: .chest, equipment: "Barbell", restSeconds: 150),
            row: try store.createExercise(name: "Cable row", muscleGroup: .back, equipment: "Cable"),
            squat: try store.createExercise(name: "Back squat", muscleGroup: .quads, equipment: "Barbell", restSeconds: 180)
        )
    }

    /// Bench (3 × 5 at 100 kg) and row (2 × 8–12 at 50 kg) as a Superset, then squat (1 × 5 at 140 kg).
    private func makePush(_ store: Store, _ catalogue: Catalogue) throws -> PlanRecord {
        try store.createPlan(name: "Push", exercises: [
            PlanExerciseDraft(exerciseID: catalogue.bench.id, supersetGroup: 1, sets: [
                PlannedSetDraft(targetKilograms: 100, reps: RepRange(5)),
                PlannedSetDraft(targetKilograms: 100, reps: RepRange(5)),
                PlannedSetDraft(targetKilograms: 100, reps: RepRange(5)),
            ]),
            PlanExerciseDraft(exerciseID: catalogue.row.id, supersetGroup: 1, sets: [
                PlannedSetDraft(targetKilograms: 50, reps: RepRange(min: 8, max: 12)),
                PlannedSetDraft(targetKilograms: 50, reps: RepRange(min: 8, max: 12)),
            ]),
            PlanExerciseDraft(exerciseID: catalogue.squat.id, supersetGroup: nil, sets: [
                PlannedSetDraft(targetKilograms: 140, reps: RepRange(5)),
            ]),
        ])
    }

    /// Local noon on 10 September 2026, so an hour either way stays on the same Day.
    private let noon = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 12))!

    // MARK: Start

    func test_startingFromAPlan_copiesItsRowsAndTargetsIntoTheWorkout() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)

        let workout = try store.startWorkout(from: push.id, at: noon)

        let read = try XCTUnwrap(store.workout(workout.id))
        XCTAssertEqual(read.startedAt, noon)
        XCTAssertEqual(read.day, Day(noon))
        XCTAssertNil(read.finishedAt)
        XCTAssertEqual(read.planID, push.id)
        XCTAssertEqual(read.planName, "Push")
        XCTAssertEqual(read.exercises.map(\.name), ["Bench press", "Cable row", "Back squat"])
        XCTAssertEqual(read.exercises.map(\.exerciseID), [catalogue.bench.id, catalogue.row.id, catalogue.squat.id])
        XCTAssertEqual(read.exercises.map(\.supersetGroup), [1, 1, nil])
        XCTAssertEqual(read.exercises.map(\.restSeconds), [150, nil, 180])
        XCTAssertEqual(read.exercises.map { $0.sets.count }, [3, 2, 1])
        let rowSet = try XCTUnwrap(read.exercises[1].sets.first)
        XCTAssertEqual(rowSet.target, SetTarget(kilograms: 50, reps: RepRange(min: 8, max: 12)))
        XCTAssertEqual(rowSet.kilograms, 50)
        XCTAssertEqual(rowSet.reps, 8)
        XCTAssertFalse(rowSet.isCompleted)
    }

    func test_startingWithNoPlan_makesAnEmptyWorkout_andExercisesAddedTakeTheirOwnCopy() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)

        let workout = try store.startWorkout(from: nil, at: noon)
        try store.addExercise(catalogue.bench.id, to: workout.id)
        try store.updateExercise(catalogue.bench.id, name: "Incline bench press", muscleGroup: .chest, equipment: nil, restSeconds: nil)

        let read = try XCTUnwrap(store.workout(workout.id))
        XCTAssertNil(read.planID)
        XCTAssertEqual(read.title, "Empty workout")
        XCTAssertEqual(read.exercises.map(\.name), ["Bench press"])
        XCTAssertEqual(read.exercises.first?.restSeconds, 150)
        XCTAssertEqual(read.exercises.first?.sets.map(\.target), [nil, nil, nil])
    }

    func test_whileAWorkoutIsActive_startingAgainResumesIt() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)

        let first = try store.startWorkout(from: push.id, at: noon)
        let second = try store.startWorkout(from: nil, at: noon.addingTimeInterval(60))

        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(try store.activeWorkout()?.id, first.id)
        XCTAssertEqual(second.exercises.count, 3)
    }

    // MARK: Copy independence (ADR 0003)

    func test_editingThePlanAfterStarting_leavesTheWorkoutAlone() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let workout = try store.startWorkout(from: push.id, at: noon)

        var squat = PlanExerciseDraft(push.exercises[2])
        squat.sets = [PlannedSetDraft(targetKilograms: 150, reps: RepRange(3))]
        try store.updatePlan(push.id, name: "Push B", exercises: [squat])

        let read = try XCTUnwrap(store.workout(workout.id))
        XCTAssertEqual(read.exercises.map(\.name), ["Bench press", "Cable row", "Back squat"])
        XCTAssertEqual(read.exercises[2].sets.map(\.kilograms), [140])
        XCTAssertEqual(read.exercises[2].sets.map(\.target?.reps), [RepRange(5)])
        XCTAssertEqual(read.planName, "Push B")
    }

    func test_editingTheWorkout_leavesThePlanAlone() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let workout = try store.startWorkout(from: push.id, at: noon)
        let bench = workout.exercises[0]

        try store.updateLoggedSet(bench.sets[0].id, kilograms: 102.5, reps: 6, isCompleted: true)
        try store.addLoggedSet(to: bench.id)
        try store.removeLoggedSet(workout.exercises[1].sets[0].id)
        try store.removeExercise(workout.exercises[2].id)
        try store.addExercise(catalogue.row.id, to: workout.id)

        let plan = try XCTUnwrap(store.plan(push.id))
        XCTAssertEqual(plan.exercises.map(\.exerciseID), [catalogue.bench.id, catalogue.row.id, catalogue.squat.id])
        XCTAssertEqual(plan.exercises.map { $0.sets.count }, [3, 2, 1])
        XCTAssertEqual(plan.exercises[0].sets.map(\.targetKilograms), [100, 100, 100])

        let read = try XCTUnwrap(store.workout(workout.id))
        XCTAssertEqual(read.exercises.map(\.name), ["Bench press", "Cable row", "Cable row"])
        XCTAssertEqual(read.exercises[0].sets.count, 4)
        XCTAssertEqual(read.exercises[0].sets[0].kilograms, 102.5)
        XCTAssertEqual(read.exercises[0].sets[0].reps, 6)
        XCTAssertTrue(read.exercises[0].sets[0].isCompleted)
        // Add set repeats the last set's numbers, uncompleted, with no target of its own.
        XCTAssertEqual(read.exercises[0].sets[3].kilograms, 100)
        XCTAssertEqual(read.exercises[0].sets[3].reps, 5)
        XCTAssertFalse(read.exercises[0].sets[3].isCompleted)
        XCTAssertNil(read.exercises[0].sets[3].target)
        XCTAssertEqual(read.exercises[1].sets.count, 1)
    }

    // MARK: Finish

    func test_finish_dropsUncompletedSets_stampsFinishedAt_andClearsTheActiveWorkout() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let workout = try store.startWorkout(from: push.id, at: noon)
        let bench = workout.exercises[0]
        try store.updateLoggedSet(bench.sets[0].id, kilograms: 100, reps: 5, isCompleted: true)
        try store.updateLoggedSet(bench.sets[2].id, kilograms: 100, reps: 4, isCompleted: true)
        try store.updateLoggedSet(workout.exercises[2].sets[0].id, kilograms: 140, reps: 5, isCompleted: true)
        let end = noon.addingTimeInterval(3_600)

        let finished = try store.finishWorkout(workout.id, at: end)

        XCTAssertEqual(finished.finishedAt, end)
        XCTAssertEqual(finished.exercises.map { $0.sets.count }, [2, 0, 1])
        XCTAssertEqual(finished.exercises[0].sets.map(\.reps), [5, 4])
        XCTAssertNil(try store.activeWorkout())
        XCTAssertEqual(try store.workout(workout.id)?.exercises.map { $0.sets.count }, [2, 0, 1])
    }

    func test_afterFinishing_startingAgainMakesANewWorkout() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let first = try store.startWorkout(from: push.id, at: noon)
        try store.finishWorkout(first.id, at: noon.addingTimeInterval(3_600))

        let second = try store.startWorkout(from: push.id, at: noon.addingTimeInterval(7_200))

        XCTAssertNotEqual(second.id, first.id)
        XCTAssertEqual(try store.activeWorkout()?.id, second.id)
    }

    func test_writeBack_movesCompletedWeightsToThePlanByPosition_andNothingElse() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let workout = try store.startWorkout(from: push.id, at: noon)
        let bench = workout.exercises[0]
        let row = workout.exercises[1]
        // Bench: 102.5 × 6, (skipped), 105 × 3. Row: 55 × 12, 55 × 12, plus an extra 60 × 10.
        try store.updateLoggedSet(bench.sets[0].id, kilograms: 102.5, reps: 6, isCompleted: true)
        try store.updateLoggedSet(bench.sets[2].id, kilograms: 105, reps: 3, isCompleted: true)
        try store.updateLoggedSet(row.sets[0].id, kilograms: 55, reps: 12, isCompleted: true)
        try store.updateLoggedSet(row.sets[1].id, kilograms: 55, reps: 12, isCompleted: true)
        try store.addLoggedSet(to: row.id)
        let extra = try XCTUnwrap(store.workout(workout.id)?.exercises[1].sets.last)
        try store.updateLoggedSet(extra.id, kilograms: 60, reps: 10, isCompleted: true)
        // A curl added mid-Workout is not in the Plan; the squat is skipped entirely.
        let curl = try store.createExercise(name: "Curl", muscleGroup: .biceps)
        try store.addExercise(curl.id, to: workout.id)
        try store.finishWorkout(workout.id, at: noon.addingTimeInterval(3_600))

        try store.updatePlanTargets(from: workout.id)

        let plan = try XCTUnwrap(store.plan(push.id))
        XCTAssertEqual(plan.exercises.map(\.exerciseID), [catalogue.bench.id, catalogue.row.id, catalogue.squat.id])
        XCTAssertEqual(plan.exercises.map(\.supersetGroup), [1, 1, nil])
        // Completed sets write by position: bench set 1 and 2 (the skipped set 2 slid up), row sets 1 and 2; the extra row set has no slot.
        XCTAssertEqual(plan.exercises[0].sets.map(\.targetKilograms), [102.5, 105, 100])
        XCTAssertEqual(plan.exercises[1].sets.map(\.targetKilograms), [55, 55])
        XCTAssertEqual(plan.exercises[2].sets.map(\.targetKilograms), [140])
        XCTAssertEqual(plan.exercises[0].sets.map(\.reps), [RepRange(5), RepRange(5), RepRange(5)])
        XCTAssertEqual(plan.exercises[1].sets.map(\.reps), [RepRange(min: 8, max: 12), RepRange(min: 8, max: 12)])
        XCTAssertEqual(plan.exercises.map { $0.sets.count }, [3, 2, 1])
    }

    func test_writeBack_skipsZeroWeights_soABodyweightSetNeverBlanksATarget() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let workout = try store.startWorkout(from: push.id, at: noon)
        try store.updateLoggedSet(workout.exercises[0].sets[0].id, kilograms: 0, reps: 5, isCompleted: true)
        try store.finishWorkout(workout.id, at: noon.addingTimeInterval(3_600))

        try store.updatePlanTargets(from: workout.id)

        XCTAssertEqual(try store.plan(push.id)?.exercises[0].sets.map(\.targetKilograms), [100, 100, 100])
    }

    func test_discard_deletesTheWorkout() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let workout = try store.startWorkout(from: push.id, at: noon)

        try store.discardWorkout(workout.id)

        XCTAssertNil(try store.workout(workout.id))
        XCTAssertNil(try store.activeWorkout())
        XCTAssertEqual(try store.plan(push.id)?.exercises.count, 3)
    }

    func test_deletingAFinishedWorkout_removesItFromHistory_andLeavesThePlan() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let workout = try store.startWorkout(from: push.id, at: noon)
        try store.updateLoggedSet(workout.exercises[0].sets[0].id, kilograms: 100, reps: 5, isCompleted: true)
        try store.finishWorkout(workout.id, at: noon.addingTimeInterval(3_600))

        try store.discardWorkout(workout.id)

        XCTAssertNil(try store.workout(workout.id))
        XCTAssertEqual(try store.recentWorkouts(limit: 5), [])
        XCTAssertEqual(try store.workoutDays(from: Day(noon).advanced(by: -30), to: Day(noon)), [])
        XCTAssertEqual(try store.plan(push.id)?.exercises.count, 3)
    }

    // MARK: Past Workouts and Activities

    func test_pastWorkout_isFinishedOnItsDay_withThePlansSetsTicked_andNeverActive() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let running = try store.startWorkout(from: nil, at: noon)
        let lastWeek = noon.addingTimeInterval(-7 * 86_400)

        let past = try store.logPastWorkout(from: push.id, startedAt: lastWeek, duration: 3_600)

        XCTAssertEqual(past.day, Day(lastWeek))
        XCTAssertEqual(past.finishedAt, lastWeek.addingTimeInterval(3_600))
        XCTAssertEqual(past.title, "Push")
        XCTAssertEqual(past.completedSetCount, 6)
        XCTAssertEqual(try store.activeWorkout()?.id, running.id)
    }

    func test_editingAPastWorkout_movesItsDay_andDropsWhatWasLeftUnticked() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let past = try store.logPastWorkout(from: push.id, startedAt: noon, duration: 3_600)
        let firstSet = past.exercises[0].sets[0]
        try store.updateLoggedSet(firstSet.id, kilograms: firstSet.kilograms, reps: firstSet.reps, isCompleted: false)
        let dayBefore = noon.addingTimeInterval(-86_400)

        try store.setWorkoutTime(past.id, startedAt: dayBefore, duration: 5_400)
        try store.dropUncompletedSets(past.id)

        let edited = try XCTUnwrap(store.workout(past.id))
        XCTAssertEqual(edited.day, Day(dayBefore))
        XCTAssertEqual(edited.duration, 5_400)
        XCTAssertEqual(edited.completedSetCount, 5)
        XCTAssertEqual(edited.uncompletedSetCount, 0)
    }

    func test_activity_isAWorkoutDayWithNoSets_andItsNamesAreSuggestedMostRecentFirst() throws {
        let store = Store.inMemory()
        let yesterday = noon.addingTimeInterval(-86_400)
        try store.logActivity(name: "Run", startedAt: yesterday.addingTimeInterval(-86_400), duration: 1_800, distanceMeters: 5_000, notes: nil)
        try store.logActivity(name: " Pickleball ", startedAt: yesterday, duration: 3_600, distanceMeters: nil, notes: "Doubles")
        let game = try store.logActivity(name: "pickleball", startedAt: noon, duration: 5_400, distanceMeters: nil, notes: "  ")

        XCTAssertEqual(game.title, "pickleball")
        XCTAssertNil(game.activity?.notes)
        XCTAssertTrue(game.exercises.isEmpty)
        XCTAssertEqual(try store.activityNames(), ["pickleball", "Run"])
        XCTAssertEqual(try store.workoutDays(from: Day(noon).advanced(by: -7), to: Day(noon)).count, 3)

        try store.updateActivity(game.id, name: "Basketball", distanceMeters: 1_609.344, notes: "Pickup")
        let edited = try XCTUnwrap(store.workout(game.id)?.activity)
        XCTAssertEqual(edited.name, "Basketball")
        XCTAssertEqual(edited.distanceMeters, 1_609.344)
        XCTAssertEqual(edited.notes, "Pickup")
        XCTAssertEqual(DistanceUnit.miles.text(meters: 1_609.344), "1 mi")
    }

    // MARK: History

    func test_twoFinishedWorkoutsOnOneDay_bothCount_andTheDayIsMarkedOnce() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let day = Day(noon)
        let morning = try store.startWorkout(from: push.id, at: noon.addingTimeInterval(-3 * 3_600))
        try store.finishWorkout(morning.id, at: noon.addingTimeInterval(-2 * 3_600))
        let evening = try store.startWorkout(from: nil, at: noon.addingTimeInterval(5 * 3_600))
        try store.finishWorkout(evening.id, at: noon.addingTimeInterval(6 * 3_600))
        let active = try store.startWorkout(from: nil, at: noon.addingTimeInterval(7 * 3_600))

        XCTAssertEqual(try store.workouts(on: day).map(\.id), [morning.id, evening.id, active.id])
        XCTAssertEqual(try store.workoutDays(from: day.advanced(by: -30), to: day), [day])
        XCTAssertEqual(try store.workouts(on: day.advanced(by: 1)), [])
    }

    func test_recentWorkouts_listFinishedOnesLatestFirst_withoutTheActiveOne() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let older = try store.startWorkout(from: push.id, at: noon.addingTimeInterval(-48 * 3_600))
        try store.finishWorkout(older.id, at: noon.addingTimeInterval(-47 * 3_600))
        let newer = try store.startWorkout(from: nil, at: noon.addingTimeInterval(-24 * 3_600))
        try store.finishWorkout(newer.id, at: noon.addingTimeInterval(-23 * 3_600))
        try store.startWorkout(from: push.id, at: noon)

        XCTAssertEqual(try store.recentWorkouts(limit: 5).map(\.id), [newer.id, older.id])
        XCTAssertEqual(try store.recentWorkouts(limit: 1).map(\.id), [newer.id])
    }

    func test_workoutsContainingAnExercise_listEveryWorkoutWithARowForIt_earliestFirst() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let fromPlan = try store.startWorkout(from: push.id, at: noon.addingTimeInterval(-48 * 3_600))
        try store.finishWorkout(fromPlan.id, at: noon.addingTimeInterval(-47 * 3_600))
        let legsOnly = try store.startWorkout(from: nil, at: noon.addingTimeInterval(-24 * 3_600))
        try store.addExercise(catalogue.squat.id, to: legsOnly.id)
        try store.finishWorkout(legsOnly.id, at: noon.addingTimeInterval(-23 * 3_600))
        let active = try store.startWorkout(from: nil, at: noon)
        try store.addExercise(catalogue.bench.id, to: active.id)

        XCTAssertEqual(try store.workouts(containing: catalogue.bench.id).map(\.id), [fromPlan.id, active.id], "the Active Workout counts: its completed sets are real")
        XCTAssertEqual(try store.workouts(containing: catalogue.squat.id).map(\.id), [fromPlan.id, legsOnly.id])
        XCTAssertEqual(try store.workouts(containing: UUID()), [])
    }

    // MARK: Stale

    func test_anActiveWorkoutIsStaleTwelveHoursAfterItStarted() throws {
        let store = Store.inMemory()
        let workout = try store.startWorkout(from: nil, at: noon)

        XCTAssertFalse(workout.isStale(at: noon.addingTimeInterval(11 * 3_600)))
        XCTAssertTrue(workout.isStale(at: noon.addingTimeInterval(12 * 3_600)))
        let finished = try store.finishWorkout(workout.id, at: noon.addingTimeInterval(3_600))
        XCTAssertFalse(finished.isStale(at: noon.addingTimeInterval(48 * 3_600)))
    }
}
