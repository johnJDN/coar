import XCTest
@testable import Coar

/// Seam 2: the Progression rule (CONTEXT.md "Progression", "Estimated 1RM"). Estimated 1RM
/// is Epley, w × (1 + r/30); a Workout's value is the best one among its completed Logged
/// Sets of the Exercise; one point per Workout containing the Exercise.
final class ProgressionTests: XCTestCase {

    // MARK: Epley

    func test_estimatedOneRepMax_isEpleyOnKnownPairs() {
        // Worked by hand: 100 × (1 + 5/30) = 116.667; 60 × (1 + 10/30) = 80; 100 × (1 + 1/30) = 103.333.
        XCTAssertEqual(Progression.estimatedOneRepMax(kilograms: 100, reps: 5), 116.667, accuracy: 0.001)
        XCTAssertEqual(Progression.estimatedOneRepMax(kilograms: 60, reps: 10), 80, accuracy: 0.001)
        XCTAssertEqual(Progression.estimatedOneRepMax(kilograms: 100, reps: 1), 103.333, accuracy: 0.001)
    }

    // MARK: Best of a Workout

    func test_bestOfSets_picksTheHighestEstimatedOneRepMaxAmongCompletedSets() {
        // 100 × 5 → 116.7, 110 × 3 → 121, 120 × 5 → 140 but never completed.
        let sets = [
            set(kilograms: 100, reps: 5, isCompleted: true),
            set(kilograms: 110, reps: 3, isCompleted: true),
            set(kilograms: 120, reps: 5, isCompleted: false),
        ]

        XCTAssertEqual(try XCTUnwrap(Progression.best(of: sets)), 121, accuracy: 0.001)
    }

    func test_bestOfSets_withNothingCompleted_isNoValue() {
        let sets = [
            set(kilograms: 100, reps: 5, isCompleted: false),
            set(kilograms: 110, reps: 3, isCompleted: false),
        ]

        XCTAssertNil(Progression.best(of: sets))
        XCTAssertNil(Progression.best(of: []))
    }

    func test_bestOfSets_ignoresCompletedSetsWithNoWeightOrNoReps() {
        // A bodyweight set or one with no reps typed says nothing about a single-rep max.
        let sets = [
            set(kilograms: 0, reps: 12, isCompleted: true),
            set(kilograms: 80, reps: 0, isCompleted: true),
        ]

        XCTAssertNil(Progression.best(of: sets))
    }

    // MARK: Points

    func test_points_areOnePerWorkoutContainingTheExercise_inWorkoutOrder() throws {
        let bench = UUID()
        let squat = UUID()
        let first = workout(startedAt: date(day: 1), rows: [
            row(exercise: bench, sets: [set(kilograms: 100, reps: 5, isCompleted: true)]),
            row(exercise: squat, sets: [set(kilograms: 200, reps: 5, isCompleted: true)]),
        ])
        let second = workout(startedAt: date(day: 3), rows: [
            row(exercise: bench, sets: [set(kilograms: 100, reps: 8, isCompleted: true)]),
            row(exercise: bench, sets: [set(kilograms: 110, reps: 3, isCompleted: true)]),
        ])

        let points = Progression.points(for: bench, in: [first, second])

        XCTAssertEqual(points.map(\.workoutID), [first.id, second.id])
        XCTAssertEqual(points.map(\.date), [first.startedAt, second.startedAt])
        XCTAssertEqual(try XCTUnwrap(points.first).kilograms, 116.667, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(points.last).kilograms, 126.667, accuracy: 0.001, "the best across both rows of the Exercise")
    }

    func test_points_skipWorkoutsWithNoCompletedSetOfTheExercise() {
        let bench = UUID()
        let squat = UUID()
        let planned = workout(startedAt: date(day: 1), rows: [
            row(exercise: bench, sets: [set(kilograms: 100, reps: 5, isCompleted: false)]),
        ])
        let legs = workout(startedAt: date(day: 2), rows: [
            row(exercise: squat, sets: [set(kilograms: 200, reps: 5, isCompleted: true)]),
        ])
        let done = workout(startedAt: date(day: 3), rows: [
            row(exercise: bench, sets: [set(kilograms: 100, reps: 5, isCompleted: true)]),
        ])

        XCTAssertEqual(Progression.points(for: bench, in: [planned, legs, done]).map(\.workoutID), [done.id])
        XCTAssertTrue(Progression.points(for: bench, in: []).isEmpty)
    }

    // MARK: Fixtures

    private func set(kilograms: Double, reps: Int, isCompleted: Bool) -> LoggedSetRecord {
        LoggedSetRecord(id: UUID(), kilograms: kilograms, reps: reps, isCompleted: isCompleted, target: nil)
    }

    private func row(exercise: ExerciseRecord.ID, sets: [LoggedSetRecord]) -> WorkoutExerciseRecord {
        WorkoutExerciseRecord(id: UUID(), name: "Exercise", exerciseID: exercise, supersetGroup: nil, restSeconds: nil, sets: sets)
    }

    private func workout(startedAt: Date, rows: [WorkoutExerciseRecord]) -> WorkoutRecord {
        WorkoutRecord(id: UUID(), startedAt: startedAt, day: Day(startedAt), finishedAt: startedAt.addingTimeInterval(3600), planID: nil, planName: nil, exercises: rows, modifiedAt: startedAt)
    }

    private func date(day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12))!
    }
}
