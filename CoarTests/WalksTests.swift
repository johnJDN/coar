import XCTest
@testable import Coar

/// Indoor walks (`.scratch/walks/issues/01`): a Watch workout's note (inhaler, treadmill speed
/// and incline) in the store façade (seam 1), its dedupe, and the pure rule that groups walks
/// done the same way.
@MainActor
final class WalksTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func walk(daysLater: Int, heartRate: Double?) -> HealthWorkout {
        let begin = start.addingTimeInterval(Double(daysLater) * 86_400)
        return HealthWorkout(id: UUID(), name: "Indoor walk", start: begin, end: begin.addingTimeInterval(35 * 60), activeKilocalories: 210,
                             averageHeartRate: heartRate, isWalk: true, isIndoor: true)
    }

    // MARK: The note

    func test_aNote_isSavedAndReadByItsWorkout_andAnEmptyOneIsRemoved() throws {
        let store = Store.inMemory()
        let id = UUID()
        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: id, usedInhaler: true, speedKmh: 4.8, inclinePercent: 6))

        XCTAssertEqual(try store.workoutNotes(for: [id, UUID()]), [id: WorkoutNoteRecord(healthWorkoutID: id, usedInhaler: true, speedKmh: 4.8, inclinePercent: 6)])

        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: id, usedInhaler: false, speedKmh: 4.8, inclinePercent: 6))
        XCTAssertEqual(try store.workoutNotes(for: [id])[id]?.usedInhaler, false)

        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: id))
        XCTAssertEqual(try store.workoutNotes(for: [id]), [:])
        XCTAssertEqual(try store.context.count(for: WorkoutNote.fetchRequest()), 0)
    }

    func test_theLatestSettings_areOfferedForTheNextWalk() throws {
        let store = Store.inMemory()
        XCTAssertNil(try store.latestTreadmillSettings())
        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: UUID(), speedKmh: 4.0, inclinePercent: 2))
        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: UUID(), speedKmh: 4.8, inclinePercent: 6))
        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: UUID(), usedInhaler: true))

        let last = try XCTUnwrap(store.latestTreadmillSettings())

        XCTAssertEqual(last.speedKmh, 4.8)
        XCTAssertEqual(last.inclinePercent, 6)
    }

    func test_twoNotesForOneWorkout_keepTheLatestModified() async throws {
        let store = Store.inMemory()
        let id = UUID()
        for (inhaler, modifiedAt) in [(true, start.addingTimeInterval(60)), (false, start)] {
            let note = WorkoutNote(context: store.context)
            note.healthWorkoutID = id
            note.usedInhaler = inhaler
            note.modifiedAt = modifiedAt
        }
        try store.context.save()

        let report = try await store.runDedupePass()

        XCTAssertEqual(report, DedupePass.Report(workoutNotesDeleted: 1))
        XCTAssertEqual(try store.workoutNotes(for: [id])[id]?.usedInhaler, true)
    }

    func test_settings_needBothSpeedAndIncline() {
        XCTAssertNil(WorkoutNoteRecord(healthWorkoutID: UUID(), speedKmh: 4.8).settingsText)
        XCTAssertNil(WorkoutNoteRecord(healthWorkoutID: UUID(), inclinePercent: 6).settingsText)
        XCTAssertNotNil(WorkoutNoteRecord(healthWorkoutID: UUID(), speedKmh: 4.8, inclinePercent: 6).settingsText)
    }

    func test_aTypedSpeed_readsBackAsTyped() {
        for typed in [2.5, 3.0, 3.3, 4.0, 5.5, 6.2] {
            XCTAssertEqual(TreadmillSpeed.display(TreadmillSpeed.kmh(fromDisplay: typed)), typed, accuracy: 0.0001)
        }
    }

    // MARK: Walks done the same way

    func test_walks_areGroupedBySpeedAndIncline_withAndWithoutTheInhaler() {
        let walks = [
            walk(daysLater: 0, heartRate: 130), walk(daysLater: 2, heartRate: 126), walk(daysLater: 4, heartRate: 120),
            walk(daysLater: 6, heartRate: 110), walk(daysLater: 8, heartRate: 105),
        ]
        func note(_ walk: HealthWorkout, inhaler: Bool, kmh: Double = 4.8, incline: Double = 6) -> WorkoutNoteRecord {
            WorkoutNoteRecord(healthWorkoutID: walk.id, usedInhaler: inhaler, speedKmh: kmh, inclinePercent: incline)
        }
        let pairs: [(workout: HealthWorkout, note: WorkoutNoteRecord?)] = [
            (walks[0], note(walks[0], inhaler: false)),
            (walks[1], note(walks[1], inhaler: true)),
            (walks[2], note(walks[2], inhaler: false)),
            (walks[3], note(walks[3], inhaler: false, kmh: 4.0, incline: 2)),
            (walks[4], nil),
        ]

        let groups = WalkComparison.groups(pairs)

        XCTAssertEqual(groups.count, 2)
        let main = groups[0]
        XCTAssertEqual(main.count, 3)
        XCTAssertEqual(main.without?.average, 125)
        XCTAssertEqual(main.without?.count, 2)
        XCTAssertEqual(main.withInhaler?.average, 126)
        XCTAssertEqual(main.first, 130)
        XCTAssertEqual(main.latest, 120)
        XCTAssertNil(groups[1].withInhaler)
    }

    func test_aWalkWithoutAHeartRateOrSettings_isLeftOut() {
        let noHeart = walk(daysLater: 0, heartRate: nil)
        let noIncline = walk(daysLater: 1, heartRate: 120)
        let groups = WalkComparison.groups([
            (noHeart, WorkoutNoteRecord(healthWorkoutID: noHeart.id, speedKmh: 4.8, inclinePercent: 6)),
            (noIncline, WorkoutNoteRecord(healthWorkoutID: noIncline.id, usedInhaler: true, speedKmh: 4.8)),
        ])
        XCTAssertEqual(groups, [])
    }
}
