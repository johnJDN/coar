import XCTest
@testable import Coar

/// Seam 2: the rest-timer trigger rule. Completing a set starts the timer, except inside a
/// Superset, where only a set of the group's last Exercise does (CONTEXT.md "Superset");
/// the duration is the Exercise's rest default or 120 s.
final class RestTimerRuleTests: XCTestCase {

    // MARK: Straight sets

    func test_straightSets_everyRowStartsTheTimer() {
        let groups: [Int?] = [nil, nil, nil]
        for index in groups.indices {
            XCTAssertTrue(RestTimerRule.starts(afterSetOn: index, groups: groups), "row \(index)")
        }
    }

    func test_singleRow_startsTheTimer() {
        XCTAssertTrue(RestTimerRule.starts(afterSetOn: 0, groups: [nil]))
    }

    // MARK: Superset groups

    func test_twoExerciseGroup_onlyTheSecondStartsTheTimer() {
        let groups: [Int?] = [1, 1]
        XCTAssertFalse(RestTimerRule.starts(afterSetOn: 0, groups: groups))
        XCTAssertTrue(RestTimerRule.starts(afterSetOn: 1, groups: groups))
    }

    func test_threeExerciseGroup_onlyTheThirdStartsTheTimer() {
        let groups: [Int?] = [1, 1, 1]
        XCTAssertFalse(RestTimerRule.starts(afterSetOn: 0, groups: groups))
        XCTAssertFalse(RestTimerRule.starts(afterSetOn: 1, groups: groups))
        XCTAssertTrue(RestTimerRule.starts(afterSetOn: 2, groups: groups))
    }

    func test_mixedWorkout_groupsAndStraightRowsFollowTheirOwnRule() {
        // A1 A2 · straight · B1 B2 B3
        let groups: [Int?] = [1, 1, nil, 2, 2, 2]
        XCTAssertEqual(groups.indices.map { RestTimerRule.starts(afterSetOn: $0, groups: groups) },
                       [false, true, true, false, false, true])
    }

    func test_rowOutsideTheWorkout_neverStartsTheTimer() {
        XCTAssertFalse(RestTimerRule.starts(afterSetOn: 3, groups: [nil, nil]))
        XCTAssertFalse(RestTimerRule.starts(afterSetOn: -1, groups: [nil, nil]))
    }

    // MARK: Duration

    func test_duration_isTheRestDefaultOr120Seconds() {
        XCTAssertEqual(RestTimerRule.seconds(restDefault: 90), 90)
        XCTAssertEqual(RestTimerRule.seconds(restDefault: nil), 120)
        XCTAssertEqual(RestTimerRule.seconds(restDefault: 0), 120)
    }

    // MARK: On a Workout

    func test_workout_answersTheDurationForTheRowThatStartsIt() {
        let bench = WorkoutExerciseRecord(id: UUID(), name: "Bench press", exerciseID: nil, supersetGroup: 1, restSeconds: 150, sets: [])
        let row = WorkoutExerciseRecord(id: UUID(), name: "Cable row", exerciseID: nil, supersetGroup: 1, restSeconds: nil, sets: [])
        let squat = WorkoutExerciseRecord(id: UUID(), name: "Back squat", exerciseID: nil, supersetGroup: nil, restSeconds: 180, sets: [])
        let workout = WorkoutRecord(
            id: UUID(), startedAt: Date(), day: Day(Date()), finishedAt: nil, planID: nil, planName: nil,
            exercises: [bench, row, squat], modifiedAt: Date()
        )

        XCTAssertNil(workout.restSeconds(afterSetOn: bench.id), "A1 never starts the timer")
        XCTAssertEqual(workout.restSeconds(afterSetOn: row.id), 120, "A2 starts it with the fallback: the row has no default")
        XCTAssertEqual(workout.restSeconds(afterSetOn: squat.id), 180)
        XCTAssertNil(workout.restSeconds(afterSetOn: UUID()))
    }
}
