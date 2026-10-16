import XCTest
@testable import Coar

/// Reading an Apple Journal export entry (`.scratch/day-page/issues/07`): its Day (a weekday
/// title wins over the header by a day), its text without the "Written at" block or "Writing
/// this at" lines, and the place from the block.
final class JournalExportTests: XCTestCase {

    private func entry(header: String, title: String, lines: [String]) -> String {
        let body = lines.map { $0.isEmpty ? #"<p class="p3"><span class="s2"><br></span></p>"# : #"<p class="p2"><span class="s2">\#($0)</span></p>"# }.joined()
        return """
        <html><body><p class="p1"><span class="s1"><div class="pageContainer"><div class="pageHeader">\(header)</div>
        <div class="assetGrid"></div><div class="title">\(title)</div><div class="bodyText"></span></p>\(body)</body></html>
        """
    }

    func test_parse_readsTheBody_dropsWritingThisAt_andTakesThePlace() throws {
        let html = entry(header: "Wednesday, May 20, 2020", title: "Woke up at like 8:30", lines: [
            "Went down and had some cereal", "", "Played Mario Kart til like 4", "Writing this at 1:46", "",
            "Written at:", "", "1530 SW Joshua St", "Portland, OR", "United States", "",
            "https://maps.apple.com/?ll=45.4375610351562,-122.695030212402&amp;q=1530 SW Joshua St", "",
            "On May 20, 2020, the weather was cloudy.",
        ])

        let parsed = try XCTUnwrap(JournalExport.parse(html: html, fileName: "2020-05-21_Woke_up_at.html"))

        XCTAssertEqual(parsed.day, Day(year: 2020, month: 5, day: 20), "the header's Day, not the file name's")
        XCTAssertEqual(parsed.title, "Woke up at like 8:30")
        XCTAssertEqual(parsed.text, "Went down and had some cereal\n\nPlayed Mario Kart til like 4")
        XCTAssertEqual(parsed.place, .init(name: "Portland, OR", latitude: 45.4375610351562, longitude: -122.695030212402))
    }

    func test_aWeekdayTitle_winsOverTheHeaderByADay() {
        // Tuesday Sep 2, 2025 titled WEDNESDAY: the date wasn't moved; it's about Wednesday.
        XCTAssertEqual(JournalExport.day(header: Day(year: 2025, month: 9, day: 2), title: "WEDNESDAY"), Day(year: 2025, month: 9, day: 3))
        // Saturday Feb 21, 2026 titled SUNDAY.
        XCTAssertEqual(JournalExport.day(header: Day(year: 2026, month: 2, day: 21), title: "SUNDAY"), Day(year: 2026, month: 2, day: 22))
        // Matching, or not a weekday: the header.
        XCTAssertEqual(JournalExport.day(header: Day(year: 2026, month: 10, day: 7), title: "WEDNESDAY"), Day(year: 2026, month: 10, day: 7))
        XCTAssertEqual(JournalExport.day(header: Day(year: 2023, month: 4, day: 3), title: "Woke up at 8"), Day(year: 2023, month: 4, day: 3))
    }

    func test_theHash_changesWhenTheTextDoes() throws {
        let one = try XCTUnwrap(JournalExport.parse(html: entry(header: "Friday, October 10, 2026", title: "FRIDAY", lines: ["Went to work"]), fileName: "a.html"))
        let same = try XCTUnwrap(JournalExport.parse(html: entry(header: "Friday, October 10, 2026", title: "FRIDAY", lines: ["Went to work"]), fileName: "a.html"))
        let edited = try XCTUnwrap(JournalExport.parse(html: entry(header: "Friday, October 10, 2026", title: "FRIDAY", lines: ["Went to work early"]), fileName: "a.html"))
        XCTAssertEqual(one.textHash, same.textHash)
        XCTAssertNotEqual(one.textHash, edited.textHash)
    }

    func test_fileDay_readsTheFileNamesDate() {
        XCTAssertEqual(JournalExport.fileDay("2026-10-10_FRIDAY.html"), Day(year: 2026, month: 10, day: 10))
        XCTAssertNil(JournalExport.fileDay("index.html"))
    }
}
