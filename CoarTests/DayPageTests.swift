import XCTest
@testable import Coar

/// The Day page and its context (`.scratch/day-page/`): the timeline's order and what it
/// leaves out, reading journal times, the importer, and the new records.
@MainActor
final class DayPageTests: XCTestCase {

    private let oct15 = Day(year: 2026, month: 10, day: 15)

    private func at(_ hour: Int, _ minute: Int = 0, on day: Day? = nil) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: (day ?? oct15).start())!
    }

    private func entry(_ name: String, at date: Date) -> EntryRecord {
        EntryRecord(id: UUID(), loggedAt: date, day: oct15, name: name, servingName: "serving", quantity: 1,
                    macros: Macros(calories: 300, protein: 20, fat: 10, carbs: 30), foodItemID: nil, mealID: nil, components: [], modifiedAt: date)
    }

    // MARK: Timeline

    func test_timeline_isInTimeOrder_untimedJournalEventsAfterTimedOnesAtTheirPartOfDay() {
        var inputs = DayTimeline.Inputs(day: oct15)
        inputs.woke = at(7, 40)
        inputs.entries = [entry("Eggs", at: at(8))]
        inputs.journal = [
            JournalEventRecord(day: oct15, title: "Office work", category: .work, minuteOfDay: nil, partOfDay: .morning, order: 0),
            JournalEventRecord(day: oct15, title: "Lunch with Neil", category: .social, minuteOfDay: 12 * 60 + 30, partOfDay: .afternoon, order: 1),
        ]
        inputs.fellAsleep = at(0, 15, on: oct15.advanced(by: 1))

        let titles = DayTimeline.items(inputs).map(\.title)

        XCTAssertEqual(titles, ["Woke up", "Eggs", "Office work", "Lunch with Neil", "Fell asleep"])
    }

    func test_timeline_leavesOutJournalMealsOnALoggedDay_andWatchWorkoutsLinkedToOne() {
        let health = HealthWorkout(id: UUID(), name: "Strength training", start: at(18, 5), end: at(18, 55), activeKilocalories: 318, averageHeartRate: 118)
        let walk = HealthWorkout(id: UUID(), name: "Walk", start: at(7, 30), end: at(7, 50), activeKilocalories: 95, averageHeartRate: 92)
        var inputs = DayTimeline.Inputs(day: oct15)
        inputs.entries = [entry("Rice", at: at(12))]
        inputs.workouts = [WorkoutRecord(id: UUID(), startedAt: at(18), day: oct15, finishedAt: at(19), planID: nil, planName: "Push", exercises: [], healthWorkoutID: health.id, modifiedAt: at(19))]
        inputs.healthWorkouts = [health, walk]
        inputs.journal = [JournalEventRecord(day: oct15, title: "Dinner: pho", category: .food, minuteOfDay: nil, partOfDay: .evening, order: 0)]

        let items = DayTimeline.items(inputs)

        XCTAssertEqual(items.map(\.title), ["Walk", "Rice", "Push"])
        XCTAssertEqual(items.last?.detail, "1h · 318 cal · 118 bpm", "the linked Watch workout's effort shows on the Coar one")
    }

    func test_timeline_aJournalMealShows_onADayWithoutAFoodLog() {
        var inputs = DayTimeline.Inputs(day: oct15)
        inputs.journal = [JournalEventRecord(day: oct15, title: "Dinner: pho", category: .food, minuteOfDay: nil, partOfDay: .evening, order: 0)]
        XCTAssertEqual(DayTimeline.items(inputs).map(\.title), ["Dinner: pho"])
        XCTAssertEqual(DayTimeline.items(inputs).first?.timeText, "Evening")
    }

    // MARK: Reading journal times

    func test_readTimes_moveIntoTheEvening_andPastMidnight() {
        let reading = JournalDayReading(events: [
            JournalEventReading(title: "Office", category: .work, time: "09:00", partOfDay: .morning),
            JournalEventReading(title: "Landed in SF", category: .travel, time: "07:00", partOfDay: .evening),
            JournalEventReading(title: "Got home", category: .travel, time: "01:30", partOfDay: .night),
            JournalEventReading(title: "  ", category: .other, time: "", partOfDay: .night),
        ])

        let records = JournalPrompt.records(reading, day: oct15)

        XCTAssertEqual(records.map(\.minuteOfDay), [9 * 60, 19 * 60, 25 * 60 + 30], "7 in the evening is 19:00; 1:30 after it is past midnight; an empty title is dropped")
        XCTAssertEqual(JournalPrompt.minutes("14:30"), 870)
        XCTAssertNil(JournalPrompt.minutes(""))
    }

    // MARK: Importer

    private final class CountingReader: JournalReading {
        var isAvailable = true
        var reads: [String] = []
        func events(in entry: JournalExportEntry) async throws -> [JournalEventRecord] {
            reads.append(entry.fileName)
            return [JournalEventRecord(day: entry.day, title: entry.text.components(separatedBy: "\n").first ?? "", category: .other, minuteOfDay: nil, partOfDay: .morning, order: 0)]
        }
    }

    private func html(_ header: String, _ title: String, _ lines: [String]) -> String {
        let body = lines.map { #"<p class="p2"><span class="s2">\#($0)</span></p>"# }.joined()
        return #"<html><body><p class="p1"><span class="s1"><div class='pageContainer'><div class="pageHeader">\#(header)</div><div class="assetGrid"></div><div class='title'>\#(title)</div><div class='bodyText'></span></p>\#(body)</body></html>"#
    }

    func test_importer_readsTheLastMonthOnce_rereadsAnEditedEntry_andKeepsItsPlace() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let entries = folder.appending(path: "AppleJournalEntries/Entries")
        try FileManager.default.createDirectory(at: entries, withIntermediateDirectories: true)
        try html("Wednesday, October 14, 2026", "WEDNESDAY", ["Went to the office", "Written at:", "1530 SW Joshua St", "Portland, OR", "United States", "https://maps.apple.com/?ll=45.43,-122.69&amp;q=x"])
            .write(to: entries.appending(path: "2026-10-15_WEDNESDAY.html"), atomically: true, encoding: .utf8)
        try html("Monday, August 3, 2026", "MONDAY", ["Too long ago"]).write(to: entries.appending(path: "2026-08-03_MONDAY.html"), atomically: true, encoding: .utf8)
        let store = Store.inMemory()
        let reader = CountingReader()
        let importer = JournalImporter(store: store, reader: reader, defaults: UserDefaults(suiteName: #function)!)

        let first = await importer.importEntries(in: folder, today: oct15)
        XCTAssertEqual(first.read, 1)
        XCTAssertEqual(reader.reads, ["2026-10-15_WEDNESDAY.html"], "the August entry is outside the month")
        XCTAssertEqual(try store.journalEvents(on: Day(year: 2026, month: 10, day: 14)).map(\.title), ["Went to the office"], "its Day is the header's, not the file name's")
        XCTAssertEqual(try store.place(on: Day(year: 2026, month: 10, day: 14))?.name, "Portland, OR")

        _ = await importer.importEntries(in: folder, today: oct15)
        XCTAssertEqual(reader.reads.count, 1, "an unchanged entry isn't read again")

        try html("Wednesday, October 14, 2026", "WEDNESDAY", ["Went to the office early"]).write(to: entries.appending(path: "2026-10-15_WEDNESDAY.html"), atomically: true, encoding: .utf8)
        _ = await importer.importEntries(in: folder, today: oct15)
        XCTAssertEqual(reader.reads.count, 2)
        XCTAssertEqual(try store.journalEvents(on: Day(year: 2026, month: 10, day: 14)).map(\.title), ["Went to the office early"], "the new read replaces the old events")
    }

    func test_importer_waitsWithoutAppleIntelligence() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder.appending(path: "Entries"), withIntermediateDirectories: true)
        try html("Wednesday, October 14, 2026", "WEDNESDAY", ["Went to the office"]).write(to: folder.appending(path: "Entries/2026-10-14_WEDNESDAY.html"), atomically: true, encoding: .utf8)
        let reader = CountingReader()
        reader.isAvailable = false
        let importer = JournalImporter(store: Store.inMemory(), reader: reader, defaults: UserDefaults(suiteName: #function)!)

        let status = await importer.importEntries(in: folder, today: oct15)

        XCTAssertEqual(status.waiting, 1)
        XCTAssertNotNil(status.problem)
        XCTAssertTrue(reader.reads.isEmpty)
    }

    // MARK: Records

    func test_mood_setsEachHalfOnItsOwn() throws {
        let store = Store.inMemory()
        try store.setMood(on: oct15, mood: 4)
        try store.setMood(on: oct15, energy: 2)
        XCTAssertEqual(try store.mood(on: oct15), MoodRecord(day: oct15, mood: 4, energy: 2))
        XCTAssertNil(try store.mood(on: oct15.advanced(by: -1)))
    }

    func test_place_theDevicesWinsOverAJournals() throws {
        let store = Store.inMemory()
        try store.setPlace(on: oct15, latitude: 45.52, longitude: -122.68, name: "Portland, OR", fromJournal: false)
        try store.setPlace(on: oct15, latitude: 44.56, longitude: -123.28, name: "Corvallis, OR", fromJournal: true)
        XCTAssertEqual(try store.place(on: oct15)?.name, "Portland, OR")
    }

    func test_aboutMe_savesAndFillsOnlyWhatsMissing() throws {
        let store = Store.inMemory()
        try store.setAboutMe(AboutMe(birthDate: nil, sex: .male, heightCentimetres: nil))
        let filled = try store.aboutMe().filling(from: AboutMe(birthDate: at(0), sex: .female, heightCentimetres: 175))
        XCTAssertEqual(filled.sex, .male, "what Coar has stays")
        XCTAssertEqual(filled.heightCentimetres, 175)
        XCTAssertEqual(AboutMe(birthDate: Calendar.current.date(from: DateComponents(year: 2002, month: 3, day: 14))).age(on: oct15), 24)
    }

    func test_dedupe_removesEventsOfAnEarlierReadOfTheSameEntry() async throws {
        let store = Store.inMemory()
        try store.saveJournalRead(JournalEntryRead(fileName: "a.html", day: oct15, textHash: "1"), events: [
            JournalEventRecord(day: oct15, title: "Kept", category: .work, minuteOfDay: nil, partOfDay: .morning, order: 0),
        ])
        // Another device's read of the same entry, arriving by sync.
        let stray = JournalEvent(context: store.context)
        stray.fileName = "a.html"; stray.readID = UUID(); stray.day = oct15.rawValue; stray.title = "Stale"
        try store.context.save()

        _ = try await store.runDedupePass()

        XCTAssertEqual(try store.journalEvents(on: oct15).map(\.title), ["Kept"])
    }
}
