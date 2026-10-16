import CryptoKit
import Foundation

/// One entry of an Apple Journal export, as Coar reads it (`.scratch/day-page/issues/07`):
/// the Mac's File → Export folder, one HTML file per entry under `Entries/`. A pure parser:
/// HTML in, the entry out.
struct JournalExportEntry: Equatable {
    let fileName: String
    /// The Day it's about (`JournalExport.day`).
    let day: Day
    let title: String
    /// The body as lines, without the "Written at" block or "Writing this at" lines.
    let text: String
    /// Where it was written, from the "Written at" block, when there is one.
    let place: Place?
    /// Changes when the title, Day, or text does.
    let textHash: String

    struct Place: Equatable {
        let name: String
        let latitude: Double
        let longitude: Double
    }
}

enum JournalExport {

    /// The Day a file name says ("2026-10-10_FRIDAY.html"): when it was written, which can be
    /// a day after the Day it's about.
    static func fileDay(_ fileName: String) -> Day? {
        Day(rawValue: String(fileName.prefix(10)))
    }

    static func parse(html: String, fileName: String) -> JournalExportEntry? {
        guard let header = firstDiv("pageHeader", in: html).map(plainText),
              let headerDate = headerFormatter.date(from: header.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        let title = firstDiv("title", in: html).map(plainText)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let day = self.day(header: Day(headerDate), title: title)

        // After the body's own div (the stylesheet names `div.bodyText` too, and the paragraph
        // holding the header and title comes before it). The exporter mixes quote styles.
        guard let start = html.range(of: #"<div class=["']bodyText["']>"#, options: .regularExpression) else { return nil }
        let body = String(html[start.upperBound...])
        let paragraphs = matches(of: #"<p class=["']p\d+["']>(.*?)</p>"#, in: body).map { plainText($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        var lines: [String] = []
        var place: JournalExportEntry.Place?
        for (index, line) in paragraphs.enumerated() {
            if line.hasPrefix("Written at:") {
                place = self.place(in: Array(paragraphs[(index + 1)...]))
                break
            }
            if line.lowercased().hasPrefix("writing this at") { continue }
            lines.append(line)
        }
        let text = lines.joined(separator: "\n").replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = SHA256.hash(data: Data("\(day.rawValue)\n\(title)\n\(text)".utf8))
        return JournalExportEntry(fileName: fileName, day: day, title: title, text: text, place: place, textHash: digest.map { String(format: "%02x", $0) }.joined())
    }

    /// John moves an entry written after midnight back to the Day it's about and titles it
    /// with that Day's weekday ("MONDAY"). So a weekday title wins, as the date within one
    /// day of the header that falls on it; otherwise the header's date.
    static func day(header: Day, title: String, calendar: Calendar = .current) -> Day {
        let names = calendar.standaloneWeekdaySymbols.map { $0.uppercased() }
        guard let weekday = names.firstIndex(of: title.uppercased().trimmingCharacters(in: .whitespaces)).map({ $0 + 1 }) else { return header }
        for offset in [0, -1, 1] {
            let candidate = header.advanced(by: offset)
            if calendar.component(.weekday, from: candidate.start(in: calendar)) == weekday { return candidate }
        }
        return header
    }

    /// "1530 SW Joshua St / Portland, OR / United States / https://maps.apple.com/?ll=45.43,-122.69&q=…":
    /// the city line (the one before the country) and the link's coordinates.
    private static func place(in lines: [String]) -> JournalExportEntry.Place? {
        guard let linkIndex = lines.firstIndex(where: { $0.contains("maps.apple.com") }),
              let match = lines[linkIndex].range(of: #"ll=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)"#, options: .regularExpression) else { return nil }
        let pair = lines[linkIndex][match].dropFirst(3).split(separator: ",")
        guard pair.count == 2, let latitude = Double(pair[0]), let longitude = Double(pair[1]) else { return nil }
        let named = lines[..<linkIndex].filter { !$0.isEmpty }
        let name = named.count >= 2 ? named[named.count - 2] : (named.first ?? "")
        return .init(name: name, latitude: latitude, longitude: longitude)
    }

    private static let headerFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()

    private static func firstDiv(_ className: String, in html: String) -> String? {
        matches(of: #"<div class=["']\#(className)["']>(.*?)</div>"#, in: html).first
    }

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    /// Tags dropped, line breaks kept, the common entities decoded.
    static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        for (entity, character) in ["&nbsp;": " ", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&amp;": "&"] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text.replacingOccurrences(of: #"&#(\d+);"#, with: "", options: .regularExpression).replacingOccurrences(of: "\u{00a0}", with: " ")
    }
}
