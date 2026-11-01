import XCTest
@testable import Coar

/// Linking a Workout to a Health Workout (`.scratch/watch-link/`): which Health Workouts it
/// could be linked to, the one worth a single tap, and what the link stores. Seam 1 (the
/// façade, in memory) and the pure matching rule; Health is faked.
@MainActor
final class HealthWorkoutTests: XCTestCase {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private let sep16 = Day(year: 2026, month: 9, day: 16)

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        Self.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: sep16.start(in: Self.calendar))!
    }

    private func health(_ name: String = "Strength training", from start: Date, minutes: Int, kilocalories: Double? = 320, heartRate: Double? = 118) -> HealthWorkout {
        HealthWorkout(id: UUID(), name: name, start: start, end: start.addingTimeInterval(Double(minutes) * 60), activeKilocalories: kilocalories, averageHeartRate: heartRate)
    }

    // MARK: Which one

    func test_theHealthWorkoutThatOverlapsMost_comesFirst_andThoseNotAlreadyLinkedOnly() {
        let workout = (start: at(18), end: at(19))
        let overlapping = health(from: at(18, 5), minutes: 50)
        let partly = health("Run", from: at(18, 45), minutes: 30)
        let morning = health("Walk", from: at(7), minutes: 20)
        let taken = health(from: at(18), minutes: 60)

        let candidates = HealthWorkout.candidates(for: workout, among: [morning, partly, overlapping, taken], alreadyLinked: [taken.id])

        XCTAssertEqual(candidates.map(\.id), [overlapping.id, partly.id, morning.id])
    }

    func test_withoutAnyOverlap_theNearestComesFirst() {
        let workout = (start: at(18), end: at(19))
        let near = health(from: at(19, 30), minutes: 20)
        let far = health(from: at(7), minutes: 20)
        XCTAssertEqual(HealthWorkout.candidates(for: workout, among: [far, near], alreadyLinked: []).map(\.id), [near.id, far.id])
    }

    func test_oneTapIsOfferedOnlyForTheOneHealthWorkoutThatOverlaps() {
        let workout = (start: at(18), end: at(19))
        let match = health(from: at(18, 2), minutes: 55)
        let morning = health("Walk", from: at(7), minutes: 20)
        XCTAssertEqual(HealthWorkout.suggestion(for: workout, among: [morning, match], alreadyLinked: [])?.id, match.id)

        let second = health("Pickleball", from: at(18, 30), minutes: 30)
        XCTAssertNil(HealthWorkout.suggestion(for: workout, among: [match, second], alreadyLinked: []), "two overlap: the user chooses")
        XCTAssertNil(HealthWorkout.suggestion(for: workout, among: [morning], alreadyLinked: []), "none overlap")
        XCTAssertNil(HealthWorkout.suggestion(for: workout, among: [match], alreadyLinked: [match.id]), "already linked elsewhere")
    }

    func test_effortText_namesWhatHealthHas() {
        XCTAssertEqual(health(from: at(18), minutes: 50).effortText, "320 cal · 118 bpm")
        XCTAssertEqual(health(from: at(18), minutes: 50, kilocalories: 319.6, heartRate: nil).effortText, "320 cal")
        XCTAssertEqual(health(from: at(18), minutes: 50, kilocalories: nil, heartRate: 117.5).effortText, "118 bpm")
        XCTAssertNil(health(from: at(18), minutes: 50, kilocalories: nil, heartRate: nil).effortText)
    }

    // MARK: The link

    func test_aFinishedWorkout_keepsOnlyTheIdentifier_andUnlinksWithNil() throws {
        let store = Store.inMemory()
        let workout = try store.logPastWorkout(from: nil, startedAt: at(18), duration: 3_000, in: Self.calendar)
        let id = UUID()

        try store.linkHealthWorkout(id, to: workout.id)
        XCTAssertEqual(try store.workout(workout.id)?.healthWorkoutID, id)

        try store.linkHealthWorkout(nil, to: workout.id)
        XCTAssertNil(try store.workout(workout.id)?.healthWorkoutID)
    }

    func test_aHealthWorkoutBelongsToOneWorkout_linkingItAgainMovesIt() throws {
        let store = Store.inMemory()
        let first = try store.logPastWorkout(from: nil, startedAt: at(7), duration: 3_000, in: Self.calendar)
        let second = try store.logPastWorkout(from: nil, startedAt: at(18), duration: 3_000, in: Self.calendar)
        let id = UUID()

        try store.linkHealthWorkout(id, to: first.id)
        XCTAssertEqual(try store.linkedHealthWorkoutIDs(), [id])
        XCTAssertEqual(try store.linkedHealthWorkoutIDs(excluding: first.id), [], "a Workout's own link isn't taken")

        try store.linkHealthWorkout(id, to: second.id)
        XCTAssertNil(try store.workout(first.id)?.healthWorkoutID)
        XCTAssertEqual(try store.workout(second.id)?.healthWorkoutID, id)
    }

    func test_aFinishedWorkout_isLinkedByItself_toTheOneHealthWorkoutOverlappingIt() throws {
        let store = Store.inMemory()
        let lift = try store.logPastWorkout(from: nil, startedAt: at(18), duration: 3_000, in: Self.calendar)
        let morning = try store.logPastWorkout(from: nil, startedAt: at(7), duration: 1_800, in: Self.calendar)
        let watch = health(from: at(18, 2), minutes: 48)
        let walk = health("Walk", from: at(12), minutes: 20)

        XCTAssertTrue(try store.autoLinkHealthWorkouts(on: [sep16], among: [walk, watch]))

        XCTAssertEqual(try store.workout(lift.id)?.healthWorkoutID, watch.id)
        XCTAssertNil(try store.workout(morning.id)?.healthWorkoutID, "nothing overlaps it")
        XCTAssertFalse(try store.autoLinkHealthWorkouts(on: [sep16], among: [walk, watch]), "nothing left to link")
    }

    func test_noLinkIsMadeByItself_whenItIsntClear() throws {
        let store = Store.inMemory()
        let lift = try store.logPastWorkout(from: nil, startedAt: at(18), duration: 3_600, in: Self.calendar)
        let twoOnTheWatch = [health(from: at(18), minutes: 25), health(from: at(18, 30), minutes: 25)]
        XCTAssertFalse(try store.autoLinkHealthWorkouts(on: [sep16], among: twoOnTheWatch), "two overlap it: the user picks")

        let other = try store.logPastWorkout(from: nil, startedAt: at(18, 30), duration: 3_600, in: Self.calendar)
        let oneOnTheWatch = health(from: at(18), minutes: 90)
        XCTAssertFalse(try store.autoLinkHealthWorkouts(on: [sep16], among: [oneOnTheWatch]), "two Workouts overlap it: the user picks")
        XCTAssertNil(try store.workout(lift.id)?.healthWorkoutID)
        XCTAssertNil(try store.workout(other.id)?.healthWorkoutID)
    }

    func test_aWorkoutTheUserUnlinked_isntLinkedAgainByItself_untilTheyLinkIt() throws {
        let store = Store.inMemory()
        let lift = try store.logPastWorkout(from: nil, startedAt: at(18), duration: 3_000, in: Self.calendar)
        let watch = health(from: at(18), minutes: 50)
        try store.autoLinkHealthWorkouts(on: [sep16], among: [watch])

        try store.linkHealthWorkout(nil, to: lift.id)
        XCTAssertFalse(try store.autoLinkHealthWorkouts(on: [sep16], among: [watch]))
        XCTAssertNil(try store.workout(lift.id)?.healthWorkoutID)

        try store.linkHealthWorkout(watch.id, to: lift.id)
        XCTAssertEqual(try store.workout(lift.id)?.watchLinkDeclined, false)
    }

    func test_anActiveWorkout_isntLinkedByItself() throws {
        let store = Store.inMemory()
        let active = try store.startWorkout(from: nil, at: at(18), in: Self.calendar)
        XCTAssertFalse(try store.autoLinkHealthWorkouts(on: [sep16], among: [health(from: at(18), minutes: 50)]))
        XCTAssertNil(try store.workout(active.id)?.healthWorkoutID)
    }

    func test_anActiveWorkout_cannotBeLinked() throws {
        let store = Store.inMemory()
        let active = try store.startWorkout(from: nil, at: at(18), in: Self.calendar)
        try store.linkHealthWorkout(UUID(), to: active.id)
        XCTAssertNil(try store.workout(active.id)?.healthWorkoutID)
    }

    func test_theFakeReader_readsADay_andByIdentifier() async throws {
        let reader = FakeHealthWorkoutReader(calendar: Self.calendar)
        let evening = health(from: at(18), minutes: 50)
        let morning = health("Walk", from: at(7), minutes: 20)
        reader.workouts = [evening, morning]

        let day = try await reader.healthWorkouts(on: sep16)
        XCTAssertEqual(day.map(\.id), [morning.id, evening.id])
        let byID = try await reader.healthWorkouts(withIDs: [evening.id])
        XCTAssertEqual(byID, [evening.id: evening])
    }
}
