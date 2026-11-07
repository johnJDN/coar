import XCTest
@testable import Coar

/// Indoor walks (`.scratch/walks/issues/01`): a Watch workout's note (inhaler, the treadmill's
/// distance and incline) in the store façade (seam 1), its dedupe, and the pure rule that puts
/// walks at any speed and incline on one effort.
@MainActor
final class WalksTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// A 35-minute indoor walk `daysAgo`, at `mph` and `incline`, by someone whose heart rate
    /// rises 4 beats per mL/kg/min from a resting 60 (so one fitness throughout).
    private func walk(daysAgo: Double, mph: Double, incline: Double, inhaler: Bool = false, beatsPerUnit: Double = 4) -> (workout: HealthWorkout, note: WorkoutNoteRecord?) {
        let start = now.addingTimeInterval(-daysAgo * 86_400)
        let metersPerMinute = mph * 1_609.344 / 60
        let heart = 60 + beatsPerUnit * (WalkEffort.oxygen(metersPerMinute: metersPerMinute, inclinePercent: incline) - 3.5)
        let workout = HealthWorkout(id: UUID(), name: "Indoor walk", start: start, end: start.addingTimeInterval(35 * 60), activeKilocalories: 210,
                                    averageHeartRate: heart, isWalk: true, isIndoor: true)
        return (workout, WorkoutNoteRecord(healthWorkoutID: workout.id, usedInhaler: inhaler, treadmillMeters: metersPerMinute * 35, inclinePercent: incline))
    }

    // MARK: The note

    func test_aNote_isSavedAndReadByItsWorkout_andAnEmptyOneIsRemoved() throws {
        let store = Store.inMemory()
        let id = UUID()
        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: id, usedInhaler: true, treadmillMeters: 2_900, inclinePercent: 5))

        XCTAssertEqual(try store.workoutNotes(for: [id, UUID()]), [id: WorkoutNoteRecord(healthWorkoutID: id, usedInhaler: true, treadmillMeters: 2_900, inclinePercent: 5)])

        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: id, usedInhaler: false, treadmillMeters: 2_900, inclinePercent: 5))
        XCTAssertEqual(try store.workoutNotes(for: [id])[id]?.usedInhaler, false)

        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: id))
        XCTAssertEqual(try store.workoutNotes(for: [id]), [:])
        XCTAssertEqual(try store.context.count(for: WorkoutNote.fetchRequest()), 0)
    }

    func test_theInhaler_isMarkedOnALiftingWorkout_whileActiveAndAfter() throws {
        let store = Store.inMemory()
        let workout = try store.startWorkout(from: nil, at: now)
        XCTAssertFalse(try XCTUnwrap(store.workout(workout.id)).usedInhaler)

        try store.setUsedInhaler(true, on: workout.id)
        XCTAssertTrue(try XCTUnwrap(store.workout(workout.id)).usedInhaler)

        _ = try store.finishWorkout(workout.id, at: now.addingTimeInterval(3_600))
        XCTAssertTrue(try XCTUnwrap(store.workout(workout.id)).usedInhaler)
        try store.setUsedInhaler(false, on: workout.id)
        XCTAssertFalse(try XCTUnwrap(store.workout(workout.id)).usedInhaler)
    }

    // MARK: The calendar

    func test_theCalendar_showsEveryWalk_butNotOtherWorkouts_orWalksLinkedToAWorkout() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = Day(now, in: calendar)
        let indoor = walk(daysAgo: 0, mph: 3, incline: 5).workout
        let outdoor = HealthWorkout(id: UUID(), name: "Walk", start: now.addingTimeInterval(-3_600), end: now, activeKilocalories: 95, averageHeartRate: 92, isWalk: true)
        let linked = HealthWorkout(id: UUID(), name: "Walk", start: now.addingTimeInterval(-7_200), end: now, activeKilocalories: 95, averageHeartRate: 92, isWalk: true)
        let lift = HealthWorkout(id: UUID(), name: "Strength training", start: now, end: now, activeKilocalories: 300, averageHeartRate: 118)

        let days = CalendarWalks.byDay([indoor, lift, outdoor, linked], linked: [linked.id], in: calendar)

        XCTAssertEqual(days, [day: [outdoor, indoor]], "earliest first")
    }

    func test_tappingACalendarDay_opensTheOneThingOnIt_orTheList_orOffersToLog() throws {
        let store = Store.inMemory()
        let lift = try store.logPastWorkout(from: nil, startedAt: now, duration: 3_000)
        let walkOne = walk(daysAgo: 0, mph: 3, incline: 5).workout
        let walkTwo = walk(daysAgo: 0, mph: 3, incline: 5).workout

        XCTAssertEqual(CalendarWalks.tap(workouts: [], walks: []), .logPastWorkout)
        XCTAssertEqual(CalendarWalks.tap(workouts: [lift], walks: []), .workout(lift))
        XCTAssertEqual(CalendarWalks.tap(workouts: [], walks: [walkOne]), .walk(walkOne))
        XCTAssertEqual(CalendarWalks.tap(workouts: [lift], walks: [walkOne]), .list)
        XCTAssertEqual(CalendarWalks.tap(workouts: [], walks: [walkOne, walkTwo]), .list)
        XCTAssertEqual(CalendarWalks.tap(workouts: [lift, lift], walks: []), .list)
    }

    func test_twoNotesForOneWorkout_keepTheLatestModified() async throws {
        let store = Store.inMemory()
        let id = UUID()
        for (inhaler, modifiedAt) in [(true, now.addingTimeInterval(60)), (false, now)] {
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

    func test_theLatestIncline_isOfferedForTheNextWalk() throws {
        let store = Store.inMemory()
        XCTAssertNil(try store.latestIncline())
        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: UUID(), treadmillMeters: 2_800, inclinePercent: 2))
        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: UUID(), treadmillMeters: 2_900, inclinePercent: 5))
        try store.setWorkoutNote(WorkoutNoteRecord(healthWorkoutID: UUID(), usedInhaler: true))

        XCTAssertEqual(try store.latestIncline(), 5)
    }

    func test_aTypedDistance_readsBackAsTyped() {
        for typed in [1.5, 1.75, 1.8, 2.04, 2.5, 3.1] {
            XCTAssertEqual(TreadmillUnits.displayDistance(TreadmillUnits.meters(fromDisplay: typed)), typed, accuracy: 0.0001)
        }
    }

    // MARK: Effort

    func test_effort_followsTheACSMWalkingEquation() {
        // 3.0 mph (80.47 m/min) at 5%: 8.05 + 7.24 + 3.5.
        XCTAssertEqual(WalkEffort.oxygen(metersPerMinute: 80.4672, inclinePercent: 5), 18.79, accuracy: 0.01)
        XCTAssertEqual(WalkEffort.oxygen(metersPerMinute: 80.4672, inclinePercent: 0), 11.55, accuracy: 0.01)
    }

    func test_aHeartRate_movesAlongTheLineFromResting() {
        XCTAssertEqual(WalkEffort.heartRate(120, atOxygen: 13.5, movedTo: 8.5, resting: 60), 90)
        XCTAssertNil(WalkEffort.heartRate(55, atOxygen: 13.5, movedTo: 8.5, resting: 60), "below resting can't be moved")
    }

    func test_walksAtDifferentSpeedsAndInclines_scoreTheSame_forTheSameFitness() throws {
        let summary = try XCTUnwrap(WalkEffort.summary([walk(daysAgo: 3, mph: 3.0, incline: 5), walk(daysAgo: 1, mph: 3.5, incline: 2)], restingHeartRate: 60, now: now))

        XCTAssertEqual(summary.scored.count, 2)
        XCTAssertNotEqual(summary.scored[0].heartRate, summary.scored[1].heartRate, accuracy: 1)
        XCTAssertEqual(summary.scored[0].atReference, summary.scored[1].atReference, accuracy: 0.01)
    }

    func test_theInhalerComparison_usesRecentWalks_andTheTrend_comparesTheFirstAndLatest() throws {
        let walks = [
            walk(daysAgo: 120, mph: 3.0, incline: 5, inhaler: true, beatsPerUnit: 4.5),
            walk(daysAgo: 100, mph: 3.0, incline: 5, beatsPerUnit: 4.5),
            walk(daysAgo: 20, mph: 3.0, incline: 4, inhaler: true, beatsPerUnit: 3.8),
            walk(daysAgo: 10, mph: 3.2, incline: 5, beatsPerUnit: 4),
            walk(daysAgo: 5, mph: 3.0, incline: 6, beatsPerUnit: 4),
        ]

        let summary = try XCTUnwrap(WalkEffort.summary(walks, restingHeartRate: 60, now: now))

        XCTAssertEqual(summary.withInhaler?.walks, 1, "the inhaler walk 120 days ago is outside the window")
        XCTAssertEqual(summary.without?.walks, 2)
        XCTAssertLessThan(try XCTUnwrap(summary.withInhaler).heartRate, try XCTUnwrap(summary.without).heartRate)
        XCTAssertEqual(summary.earlier?.walks, 2)
        XCTAssertGreaterThan(try XCTUnwrap(summary.earlier).heartRate, try XCTUnwrap(summary.later).heartRate)
    }

    func test_aWalkWithoutItsTreadmillNumbersOrAHeartRate_isNotScored() {
        var noIncline = walk(daysAgo: 1, mph: 3, incline: 5)
        noIncline.note?.inclinePercent = nil
        let noHeart = HealthWorkout(id: UUID(), name: "Indoor walk", start: now, end: now.addingTimeInterval(1_800), activeKilocalories: nil, averageHeartRate: nil, isWalk: true, isIndoor: true)
        XCTAssertNil(WalkEffort.summary([noIncline, (noHeart, WorkoutNoteRecord(healthWorkoutID: noHeart.id, treadmillMeters: 2_500, inclinePercent: 5))], restingHeartRate: 60, now: now))
    }
}
