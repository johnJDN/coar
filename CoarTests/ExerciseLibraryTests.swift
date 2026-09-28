import XCTest
@testable import Coar

/// The built-in exercise library (`.scratch/exercise-library/`): its data holds together, it
/// never offers what the user already has, the filter finds names and muscle groups, and
/// adding copies an entry into an ordinary Exercise.
@MainActor
final class ExerciseLibraryTests: XCTestCase {

    // MARK: The data

    func test_theLibrary_holdsTogether() {
        let entries = ExerciseLibrary.entries
        XCTAssertEqual(entries.count, 148)
        XCTAssertEqual(Set(entries.map { ExerciseLibrary.key($0.name) }).count, entries.count, "names are unique")
        for entry in entries {
            XCTAssertFalse(entry.secondaryMuscleGroups.contains(entry.muscleGroup), "\(entry.name) repeats its primary group")
            XCTAssertEqual(Set(entry.secondaryMuscleGroups).count, entry.secondaryMuscleGroups.count, "\(entry.name) repeats a group")
            let known = Equipment.allCases.map(\.rawValue) + ["Ab wheel", "Trap bar"]
            XCTAssertTrue(known.contains(entry.equipment), "\(entry.name): \(entry.equipment)")
        }
        XCTAssertFalse(entries.contains { $0.muscleGroup == .other }, "nothing is filed under Other")
    }

    func test_everyExerciseJohnDoes_isThere() {
        for name in ["Incline dumbbell press", "Incline dumbbell fly", "Chest dip", "Pull-up", "Chin-up", "Single-arm dumbbell row",
                     "Seated dumbbell shoulder press", "Lateral raise", "Rear delt fly", "Dumbbell curl", "Hammer curl",
                     "Heel-elevated goblet squat", "Bulgarian split squat", "Dumbbell Romanian deadlift"] {
            XCTAssertNotNil(ExerciseLibrary.entry(named: name), name)
        }
        XCTAssertEqual(ExerciseLibrary.entry(named: " chest  DIP ")?.muscleGroup, .chest)
    }

    // MARK: Offering

    func test_whatTheUserHas_isNotOffered_archivedIncluded() {
        let offered = ExerciseLibrary.offered(excluding: ["pull-up", "Chest Dip"], filter: "")
        let names = offered.flatMap(\.entries).map(\.name)
        XCTAssertEqual(names.count, 146)
        XCTAssertFalse(names.contains("Pull-up"))
        XCTAssertFalse(names.contains("Chest dip"))
        XCTAssertEqual(offered.map(\.group), MuscleGroup.allCases.filter { $0 != .other }, "grouped in muscle-group order")
    }

    func test_theFilter_matchesANameOrAMuscleGroup() {
        let curls = ExerciseLibrary.offered(excluding: [], filter: "curl").flatMap(\.entries).map(\.name)
        XCTAssertTrue(curls.contains("Hammer curl"))
        XCTAssertTrue(curls.contains("Lying leg curl"), "names match anywhere")
        let calves = ExerciseLibrary.offered(excluding: [], filter: "calves")
        XCTAssertEqual(calves.map(\.group), [.calves])
        XCTAssertEqual(calves.first?.entries.count, 5)
        XCTAssertTrue(ExerciseLibrary.offered(excluding: [], filter: "zzz").isEmpty)
    }

    // MARK: Adding

    func test_addingAnEntry_makesAnOrdinaryExercise_thenItIsNoLongerOffered() throws {
        let store = Store.inMemory()
        let entry = try XCTUnwrap(ExerciseLibrary.entry(named: "Incline dumbbell press"))

        let added = try ExerciseLibrary.add(entry, to: store)

        XCTAssertEqual(added.name, "Incline dumbbell press")
        XCTAssertEqual(added.muscleGroup, .chest)
        XCTAssertEqual(added.secondaryMuscleGroups, [.shoulders, .triceps])
        XCTAssertEqual(added.equipment, "Dumbbell")
        XCTAssertNil(added.restSeconds)
        XCTAssertEqual(try store.exercises().map(\.id), [added.id])
        try store.updateExercise(added.id, name: "Incline DB press 30°", muscleGroup: .chest, secondaryMuscleGroups: [.shoulders, .triceps], equipment: "Dumbbell", restSeconds: 150)
        XCTAssertEqual(try store.exercise(added.id)?.name, "Incline DB press 30°", "renamed like any other")
    }
}
