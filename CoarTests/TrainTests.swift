import XCTest
@testable import Coar

/// Seam 1: the store façade. An Exercise is a catalogue entry with a fixed Muscle Group; a
/// Plan is an ordered list of Exercises, each with ordered Planned Sets, adjacent rows
/// groupable as a Superset (CONTEXT.md "Exercise", "Plan", "Planned Set", "Superset").
/// Weights are stored in kilograms whatever unit they were typed in (ADR 0004); archiving
/// hides from the picker and nothing else (CONTEXT.md "Archived").
@MainActor
final class TrainTests: XCTestCase {

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

    // MARK: Exercises

    func test_newExercise_readsBack_andTheCatalogueListsByName() throws {
        let store = Store.inMemory()

        let catalogue = try stock(store)

        let read = try XCTUnwrap(store.exercise(catalogue.bench.id))
        XCTAssertEqual(read.name, "Bench press")
        XCTAssertEqual(read.muscleGroup, .chest)
        XCTAssertEqual(read.equipment, "Barbell")
        XCTAssertEqual(read.restSeconds, 150)
        XCTAssertFalse(read.isArchived)
        XCTAssertNil(try store.exercise(catalogue.row.id)?.restSeconds)
        XCTAssertEqual(try store.exercises().map(\.name), ["Back squat", "Bench press", "Cable row"])
    }

    func test_blankEquipment_readsBackAsNone() throws {
        let store = Store.inMemory()

        let pullUp = try store.createExercise(name: "Pull-up", muscleGroup: .back, equipment: "  ")

        XCTAssertNil(try store.exercise(pullUp.id)?.equipment)
    }

    func test_updatingAnExercise_changesTheCatalogue_andWhatItsPlansShowNow() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)

        try store.updateExercise(catalogue.bench.id, name: "Incline bench press", muscleGroup: .chest, equipment: "Dumbbells", restSeconds: nil)

        let read = try XCTUnwrap(store.exercise(catalogue.bench.id))
        XCTAssertEqual(read.name, "Incline bench press")
        XCTAssertEqual(read.equipment, "Dumbbells")
        XCTAssertNil(read.restSeconds)
        XCTAssertEqual(try store.plan(push.id)?.exercises.first?.exercise.name, "Incline bench press")
    }

    func test_archivedExercise_leavesThePicker_staysInItsPlan_andRestores() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)

        try store.archiveExercise(catalogue.row.id)

        XCTAssertEqual(try store.exercises().map(\.id), [catalogue.squat.id, catalogue.bench.id])
        XCTAssertEqual(try store.archivedExercises().map(\.id), [catalogue.row.id])
        let inPlan = try XCTUnwrap(store.plan(push.id)).exercises
        XCTAssertEqual(inPlan.map(\.exerciseID), [catalogue.bench.id, catalogue.row.id, catalogue.squat.id])
        XCTAssertEqual(inPlan.map(\.exercise.isArchived), [false, true, false])

        try store.restoreExercise(catalogue.row.id)

        XCTAssertEqual(try store.exercises().count, 3)
        XCTAssertEqual(try store.archivedExercises(), [])
    }

    // MARK: Plans

    func test_newPlan_readsBackItsExercisesAndSetsInOrder() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)

        let push = try makePush(store, catalogue)

        let read = try XCTUnwrap(store.plan(push.id))
        XCTAssertEqual(read.name, "Push")
        XCTAssertFalse(read.isArchived)
        XCTAssertEqual(read.exercises.map(\.exercise.name), ["Bench press", "Cable row", "Back squat"])
        XCTAssertEqual(read.exercises.map(\.exerciseID), [catalogue.bench.id, catalogue.row.id, catalogue.squat.id])
        XCTAssertEqual(read.exercises.map(\.exercise.muscleGroup), [.chest, .back, .quads])
        XCTAssertEqual(read.exercises.map(\.exercise.restSeconds), [150, nil, 180])
        XCTAssertEqual(read.exercises.map { $0.sets.count }, [3, 2, 1])
        XCTAssertEqual(read.exercises[1].sets.map(\.reps), [RepRange(min: 8, max: 12), RepRange(min: 8, max: 12)])
        XCTAssertEqual(read.exercises[2].sets.first?.targetKilograms, 140)
        XCTAssertEqual(try store.plans().map(\.name), ["Push"])
    }

    func test_updatingAPlan_keepsRowsAndSetsByIdInTheNewOrder_andDropsTheOnesLeftOut() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)
        let bench = push.exercises[0]
        let squat = push.exercises[2]
        var benchDraft = PlanExerciseDraft(bench)
        benchDraft.sets = [
            PlannedSetDraft(id: bench.sets[2].id, targetKilograms: 102.5, reps: RepRange(5)),
            PlannedSetDraft(id: bench.sets[0].id, targetKilograms: 100, reps: RepRange(min: 3, max: 5)),
        ]
        benchDraft.supersetGroup = nil

        try store.updatePlan(push.id, name: "Push A", exercises: [PlanExerciseDraft(squat), benchDraft])

        let read = try XCTUnwrap(store.plan(push.id))
        XCTAssertEqual(read.name, "Push A")
        XCTAssertEqual(read.exercises.map(\.id), [squat.id, bench.id])
        XCTAssertEqual(read.exercises.map(\.exercise.name), ["Back squat", "Bench press"])
        let sets = read.exercises[1].sets
        XCTAssertEqual(sets.map(\.id), [bench.sets[2].id, bench.sets[0].id])
        XCTAssertEqual(sets.map(\.targetKilograms), [102.5, 100])
        XCTAssertEqual(sets.map(\.reps), [RepRange(5), RepRange(min: 3, max: 5)])
        XCTAssertEqual(read.exercises.map(\.supersetGroup), [nil, nil])
    }

    func test_supersetGroupMembership_persists() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)

        let push = try makePush(store, catalogue)

        let read = try XCTUnwrap(store.plan(push.id))
        XCTAssertEqual(read.exercises.map(\.supersetGroup), [1, 1, nil])
    }

    func test_plannedSetWeightEnteredInPounds_isStoredInKilograms_andReadsBackInEitherUnit() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)

        let plan = try store.createPlan(name: "Bench day", exercises: [
            PlanExerciseDraft(exerciseID: catalogue.bench.id, supersetGroup: nil, sets: [
                PlannedSetDraft(weight: 135, in: .pounds, reps: RepRange(5)),
            ]),
        ])

        // 135 lb is 61.235 kg.
        let set = try XCTUnwrap(store.plan(plan.id)?.exercises.first?.sets.first)
        XCTAssertEqual(set.targetKilograms, 61.235, accuracy: 0.001)
        XCTAssertEqual(MassUnit.pounds.displayValue(fromKilograms: set.targetKilograms), 135)
        XCTAssertEqual(MassUnit.kilograms.displayValue(fromKilograms: set.targetKilograms), 61.2)
    }

    func test_archivedPlan_leavesTheList_andRestores() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let push = try makePush(store, catalogue)

        try store.archivePlan(push.id)

        XCTAssertEqual(try store.plans(), [])
        XCTAssertEqual(try store.archivedPlans().map(\.id), [push.id])
        XCTAssertEqual(try store.plan(push.id)?.exercises.count, 3)

        try store.restorePlan(push.id)

        XCTAssertEqual(try store.plans().map(\.id), [push.id])
    }

    func test_plans_listByNameRegardlessOfCase() throws {
        let store = Store.inMemory()
        let catalogue = try stock(store)
        let legs = [PlanExerciseDraft(exerciseID: catalogue.squat.id, supersetGroup: nil, sets: [])]
        try store.createPlan(name: "pull", exercises: legs)
        try store.createPlan(name: "Legs", exercises: legs)

        XCTAssertEqual(try store.plans().map(\.name), ["Legs", "pull"])
    }
}
