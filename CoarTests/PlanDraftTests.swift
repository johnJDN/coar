import XCTest
@testable import Coar

/// Seam 2: pure rule functions. The Plan editor's draft keeps the Superset rule (CONTEXT.md
/// "Superset": adjacent rows, two or more) as rows are linked, unlinked, reordered, and
/// removed; a rep range shows as one number when min = max.
final class PlanDraftTests: XCTestCase {

    private let bench = UUID()
    private let row = UUID()
    private let squat = UUID()
    private let curl = UUID()

    private func draft(_ exerciseIDs: UUID...) -> PlanDraft {
        var draft = PlanDraft(name: "Push")
        for id in exerciseIDs { draft.append(exerciseID: id) }
        return draft
    }

    private func groups(_ draft: PlanDraft) -> [Int?] {
        draft.exercises.map(\.supersetGroup)
    }

    func test_appendedRow_startsWithThreeSetsOfEightToTwelve_andNoSuperset() {
        let plan = draft(bench)

        let row = try! XCTUnwrap(plan.exercises.first)
        XCTAssertEqual(row.exerciseID, bench)
        XCTAssertNil(row.supersetGroup)
        XCTAssertEqual(row.sets.map(\.reps), Array(repeating: RepRange(min: 8, max: 12), count: 3))
        XCTAssertEqual(row.sets.map(\.targetKilograms), [0, 0, 0])
    }

    func test_linkingTwoAdjacentRows_makesOneSuperset_andAThirdExtendsIt() {
        var plan = draft(bench, row, squat)

        plan.toggleLink(below: plan.exercises[0].id)
        XCTAssertEqual(groups(plan), [1, 1, nil])
        XCTAssertTrue(plan.isLinkedToNext(plan.exercises[0].id))
        XCTAssertFalse(plan.isLinkedToNext(plan.exercises[1].id))

        plan.toggleLink(below: plan.exercises[1].id)
        XCTAssertEqual(groups(plan), [1, 1, 1])
    }

    func test_unlinkingInsideAGroup_splitsIt_andAGroupOfOneIsNoGroup() {
        var plan = draft(bench, row, squat, curl)
        plan.toggleLink(below: plan.exercises[0].id)
        plan.toggleLink(below: plan.exercises[1].id)
        plan.toggleLink(below: plan.exercises[2].id)

        plan.toggleLink(below: plan.exercises[1].id)
        XCTAssertEqual(groups(plan), [1, 1, 2, 2])

        plan.toggleLink(below: plan.exercises[2].id)
        XCTAssertEqual(groups(plan), [1, 1, nil, nil])
    }

    func test_twoSeparateSupersets_haveDistinctGroups() {
        var plan = draft(bench, row, squat, curl)

        plan.toggleLink(below: plan.exercises[0].id)
        plan.toggleLink(below: plan.exercises[2].id)

        XCTAssertEqual(groups(plan), [1, 1, 2, 2])
    }

    func test_reorderingAMemberAway_breaksItsSuperset_andTheRestStayGrouped() {
        var plan = draft(bench, row, squat, curl)
        plan.toggleLink(below: plan.exercises[0].id)
        plan.toggleLink(below: plan.exercises[1].id)

        // bench, squat, curl, row: bench and squat stay adjacent; row is on its own.
        plan.reorder([bench, squat, curl, row].map { id in plan.exercises.first { $0.exerciseID == id }!.id })

        XCTAssertEqual(plan.exercises.map(\.exerciseID), [bench, squat, curl, row])
        XCTAssertEqual(groups(plan), [1, 1, nil, nil])
    }

    func test_removingTheMiddleOfAGroup_leavesTheNeighboursGrouped_andRemovingAPairMateUngroupsTheOther() {
        var plan = draft(bench, row, squat)
        plan.toggleLink(below: plan.exercises[0].id)
        plan.toggleLink(below: plan.exercises[1].id)

        plan.remove(plan.exercises[1].id)
        XCTAssertEqual(groups(plan), [1, 1])

        plan.remove(plan.exercises[1].id)
        XCTAssertEqual(groups(plan), [nil])
    }

    func test_theLastRow_cannotLinkBelow() {
        var plan = draft(bench, row)

        plan.toggleLink(below: plan.exercises[1].id)

        XCTAssertEqual(groups(plan), [nil, nil])
        XCTAssertFalse(plan.isLinkedToNext(plan.exercises[1].id))
    }

    func test_isComplete_needsANameAndAtLeastOneExercise() {
        XCTAssertFalse(PlanDraft(name: "Push").isComplete)
        XCTAssertFalse(draft(bench).with(name: "  ").isComplete)
        XCTAssertTrue(draft(bench).isComplete)
    }

    func test_superset_labelsRowsA1A2_thenB1B2() {
        var plan = draft(bench, row, squat, curl)
        plan.toggleLink(below: plan.exercises[0].id)
        plan.toggleLink(below: plan.exercises[2].id)

        XCTAssertEqual(plan.exercises.map { plan.supersetLabel(for: $0.id) }, ["A1", "A2", "B1", "B2"])
    }

    func test_repRange_showsOneNumberWhenMinIsMax_andLiftsAMaxBelowTheMin() {
        XCTAssertEqual(RepRange(5).text, "5")
        XCTAssertEqual(RepRange(min: 8, max: 12).text, "8–12")
        XCTAssertEqual(RepRange(min: 10, max: 6), RepRange(10))
    }
}

private extension PlanDraft {
    func with(name: String) -> PlanDraft {
        var copy = self
        copy.name = name
        return copy
    }
}
