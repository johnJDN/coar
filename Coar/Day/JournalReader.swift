import Foundation
import FoundationModels

/// Turns a journal entry into events (`.scratch/day-page/issues/07`). On device, with Apple's
/// Foundation Models: nothing leaves the phone. Faked in tests and a simulator.
protocol JournalReading: AnyObject {
    /// Whether reading can happen now (Apple Intelligence on and ready).
    var isAvailable: Bool { get }
    func events(in entry: JournalExportEntry) async throws -> [JournalEventRecord]
}

@Generable(description: "What happened on one day, from a journal entry")
struct JournalDayReading {
    @Guide(description: "The day's main events in the order written: usually 3 to 8", .maximumCount(10))
    var events: [JournalEventReading]
}

@Generable
struct JournalEventReading {
    @Guide(description: "Two to five words naming the event, from the entry")
    var title: String
    var category: JournalCategoryReading
    @Guide(description: "24-hour HH:mm when the entry writes a clock time for this event, else an empty string")
    var time: String
    @Guide(description: "The part of the day it happened in, from any times and the order of the entry")
    var partOfDay: PartOfDayReading
}

@Generable
enum JournalCategoryReading: String {
    case work, social, exercise, food, health, travel, errands, rest, mood, other
}

@Generable
enum PartOfDayReading: String {
    case morning, afternoon, evening, night
}

enum JournalPrompt {
    static let instructions = """
    You read one day's entry from someone's journal and list the main events of that day, in the order written.
    Use only what this entry says. Never add an event, place, person or time that isn't in it.
    The entry is one short line per thing done, so most events span several lines: merge every line about the same outing or activity into a single event.
    Write each title yourself, two to five words, naming the event with the place, person or thing from the entry.
    Leave out waking up, going to bed, showering, getting ready, napping, eating with nothing said about what, relaxing, going home, and when the entry was written.
    A meal that names what was eaten is a food event titled with the meal and the food.
    Give a time only when the entry writes a clock time for that event; otherwise leave the time empty.
    """

    /// A reading's events as Coar keeps them: times in minutes, after midnight past 24 hours
    /// once the day has reached the afternoon, in the entry's order.
    static func records(_ reading: JournalDayReading, day: Day) -> [JournalEventRecord] {
        var reachedAfternoon = false
        return reading.events.enumerated().compactMap { index, event in
            let trimmed = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let title = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
            var minute = minutes(event.time)
            let part = PartOfDay(rawValue: event.partOfDay.rawValue)
            if var value = minute {
                // "Landed at 7" in the evening is 19:00: an hour before noon in a later part
                // of the day is the afternoon's or evening's.
                if value < 12 * 60, value >= 60, part == .afternoon || part == .evening || (part == .night && value >= 6 * 60) { value += 12 * 60 }
                if reachedAfternoon, value < 5 * 60 { value += 24 * 60 }
                if value >= 12 * 60 { reachedAfternoon = true }
                minute = value
            }
            return JournalEventRecord(day: day, title: title, category: JournalCategory(rawValue: event.category.rawValue) ?? .other,
                                      minuteOfDay: minute, partOfDay: part, order: index)
        }
    }

    /// "14:30" → 870; nil for anything else.
    static func minutes(_ time: String) -> Int? {
        let parts = time.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]), (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}

/// Apple's on-device model.
final class OnDeviceJournalReader: JournalReading {

    var isAvailable: Bool { SystemLanguageModel.default.availability == .available }

    func events(in entry: JournalExportEntry) async throws -> [JournalEventRecord] {
        let session = LanguageModelSession(instructions: JournalPrompt.instructions)
        // The model reads a few thousand words at most; a very long entry is cut.
        let text = String((entry.title + "\n" + entry.text).prefix(6_000))
        let reading = try await session.respond(to: text, generating: JournalDayReading.self).content
        return JournalPrompt.records(reading, day: entry.day)
    }
}
