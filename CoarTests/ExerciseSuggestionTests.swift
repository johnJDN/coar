import XCTest
@testable import Coar

/// AI fill-in on New exercise (`.scratch/exercise-library/issues/02`): a library name fills
/// in for free, a model reply is read into Coar's own groups and equipment, and a suggestion
/// never overwrites what the user chose.
@MainActor
final class ExerciseSuggestionTests: XCTestCase {

    private func reply(_ json: String) -> ExerciseSuggestion? {
        ExerciseSuggestion(reply: Data(json.utf8))
    }

    // MARK: Reading a reply

    func test_aReply_becomesCoarsGroupsAndEquipment() {
        let dips = reply(#"{"muscle_group":"Chest","also_works":["Triceps","Shoulders"],"equipment":"Bodyweight","other_equipment":""}"#)
        XCTAssertEqual(dips, ExerciseSuggestion(muscleGroup: .chest, secondaryMuscleGroups: [.triceps, .shoulders], equipment: "Bodyweight", source: .ai))
    }

    func test_otherEquipment_isNamed_andNoneIsNil_andBadGroupsAreDropped() {
        let row = reply(#"{"muscle_group":"Back","also_works":["Biceps","Lats","Back"],"equipment":"Other","other_equipment":" Landmine "}"#)
        XCTAssertEqual(row?.secondaryMuscleGroups, [.biceps], "unknown dropped, the primary never repeated")
        XCTAssertEqual(row?.equipment, "Landmine")
        XCTAssertNil(reply(#"{"muscle_group":"Core","also_works":[],"equipment":"None","other_equipment":""}"#)?.equipment)
        XCTAssertNil(reply(#"{"muscle_group":"Lats","also_works":[],"equipment":"None","other_equipment":""}"#), "no known primary, no suggestion")
        XCTAssertNil(reply("nope"))
    }

    func test_aLibraryName_isSuggestedWithoutAnyRequest() async {
        var asked = false
        let client = OpenRouterClient(keys: FakeAPIKeyStore(key: "sk-or-test")) { request in
            asked = true
            throw URLError(.notConnectedToInternet)
        }
        let suggestion = await ExerciseSuggester(client: client).suggest(for: "  bulgarian SPLIT squat")
        XCTAssertEqual(suggestion?.muscleGroup, .quads)
        XCTAssertEqual(suggestion?.source, .library)
        XCTAssertFalse(asked)
    }

    func test_noKey_meansNoSuggestion_andNoRequest() async {
        var asked = false
        let client = OpenRouterClient(keys: FakeAPIKeyStore()) { request in
            asked = true
            throw URLError(.notConnectedToInternet)
        }
        let suggestion = await ExerciseSuggester(client: client).suggest(for: "Copenhagen plank")
        XCTAssertNil(suggestion)
        XCTAssertFalse(asked)
    }

    // MARK: When it may fill in

    func test_aSuggestion_fillsAnUntouchedForm_andReplacesOnlyItself() throws {
        let squat = ExerciseSuggestion(try XCTUnwrap(ExerciseLibrary.entry(named: "Goblet squat")))
        var draft = ExerciseForm.Draft()
        draft.name = "Goblet squat"
        XCTAssertTrue(draft.acceptsSuggestion(after: nil))

        draft.apply(squat)
        XCTAssertEqual(draft.muscleGroup, .quads)
        XCTAssertEqual(draft.secondaryGroups, [.glutes, .core])
        XCTAssertEqual(draft.equipment, "Dumbbell")
        XCTAssertTrue(draft.acceptsSuggestion(after: squat), "a later suggestion may replace this one")

        draft.equipmentChoice = .named(.kettlebell)
        XCTAssertFalse(draft.acceptsSuggestion(after: squat), "the user's own change stops it")
    }

    func test_otherEquipment_fillsTheOtherField() {
        var draft = ExerciseForm.Draft()
        draft.apply(ExerciseSuggestion(muscleGroup: .glutes, secondaryMuscleGroups: [.quads], equipment: "Trap bar", source: .ai))
        XCTAssertEqual(draft.equipmentChoice, .other)
        XCTAssertEqual(draft.equipment, "Trap bar")
    }

    func test_theSchema_offersExactlyCoarsLists() throws {
        let properties = try XCTUnwrap(ExerciseSuggester.schema["properties"] as? [String: Any])
        let groups = try XCTUnwrap((properties["muscle_group"] as? [String: Any])?["enum"] as? [String])
        XCTAssertEqual(groups, MuscleGroup.allCases.map(\.title))
        let equipment = try XCTUnwrap((properties["equipment"] as? [String: Any])?["enum"] as? [String])
        XCTAssertEqual(equipment, Equipment.allCases.map(\.rawValue) + ["None", "Other"])
    }
}
