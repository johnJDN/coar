import CoreData
import UIKit

/// What a journal event was about (CONTEXT.md "Journal event").
enum JournalCategory: String, CaseIterable {
    case work, social, exercise, food, health, travel, errands, rest, mood, other

    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    var systemImage: String {
        switch self {
        case .work: return "briefcase.fill"
        case .social: return "person.2.fill"
        case .exercise: return "figure.run"
        case .food: return "fork.knife"
        case .health: return "cross.case.fill"
        case .travel: return "car.fill"
        case .errands: return "bag.fill"
        case .rest: return "sofa.fill"
        case .mood: return "heart.fill"
        case .other: return "circle.fill"
        }
    }

    /// Journal events stay quiet next to what Coar measured: one neutral tint, except the
    /// ones that echo a metric's accent.
    var tint: UIColor {
        switch self {
        case .exercise: return UIColor.accentGreen
        case .food: return UIColor.accentAmber
        case .social: return UIColor.accentLavender
        default: return UIColor.textSecondary
        }
    }
}

/// The part of a Day an event without a time belongs to, and where it sits on the timeline.
enum PartOfDay: String, CaseIterable {
    case morning, afternoon, evening, night

    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// Minutes after midnight it's placed at: 8 AM, 1 PM, 6 PM, 10 PM.
    var anchorMinute: Int {
        switch self {
        case .morning: return 8 * 60
        case .afternoon: return 13 * 60
        case .evening: return 18 * 60
        case .night: return 22 * 60
        }
    }

    static func containing(minute: Int) -> PartOfDay {
        switch minute {
        case ..<(12 * 60): return .morning
        case ..<(17 * 60): return .afternoon
        case ..<(21 * 60): return .evening
        default: return .night
        }
    }
}

/// One thing that happened, from a journal entry (CONTEXT.md "Journal event").
struct JournalEventRecord: Equatable {
    let day: Day
    let title: String
    let category: JournalCategory
    /// Minutes after midnight when the entry said; may pass 24 hours for after midnight.
    let minuteOfDay: Int?
    let partOfDay: PartOfDay?
    /// Its place in the entry, for events at the same time.
    let order: Int
}

/// A journal entry as Coar last read it: which file, its Day, and its text's hash, so an
/// unchanged entry isn't read twice.
struct JournalEntryRead: Equatable {
    let fileName: String
    let day: Day
    let textHash: String
}

extension Store {

    func journalEvents(on day: Day) throws -> [JournalEventRecord] {
        let request = JournalEvent.fetchRequest()
        request.predicate = NSPredicate(format: "day == %@", day.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "fileName", ascending: true), NSSortDescriptor(key: "order", ascending: true)]
        return try context.fetch(request).compactMap { event in
            guard let raw = event.day, let day = Day(rawValue: raw) else { return nil }
            return JournalEventRecord(
                day: day, title: event.title ?? "", category: event.category.flatMap(JournalCategory.init) ?? .other,
                minuteOfDay: event.minuteOfDay?.intValue, partOfDay: event.partOfDay.flatMap(PartOfDay.init), order: Int(event.order)
            )
        }
    }

    /// Every entry read so far, by file name.
    func journalEntriesRead() throws -> [String: JournalEntryRead] {
        var result: [String: JournalEntryRead] = [:]
        for entry in try context.fetch(JournalEntry.fetchRequest()) {
            guard let file = entry.fileName, let raw = entry.day, let day = Day(rawValue: raw) else { continue }
            result[file] = JournalEntryRead(fileName: file, day: day, textHash: entry.textHash ?? "")
        }
        return result
    }

    /// Records one read of an entry and its events, replacing any earlier read of the same
    /// file (an edited entry, or one moved to another Day).
    func saveJournalRead(_ read: JournalEntryRead, events: [JournalEventRecord]) throws {
        let entries = JournalEntry.fetchRequest()
        entries.predicate = NSPredicate(format: "fileName == %@", read.fileName)
        try context.fetch(entries).forEach(context.delete)
        let oldEvents = JournalEvent.fetchRequest()
        oldEvents.predicate = NSPredicate(format: "fileName == %@", read.fileName)
        try context.fetch(oldEvents).forEach(context.delete)

        let readID = UUID()
        let entry = JournalEntry(context: context)
        entry.fileName = read.fileName
        entry.day = read.day.rawValue
        entry.textHash = read.textHash
        entry.readID = readID
        for event in events {
            let object = JournalEvent(context: context)
            object.fileName = read.fileName
            object.readID = readID
            object.day = event.day.rawValue
            object.title = event.title
            object.category = event.category.rawValue
            object.minuteOfDay = event.minuteOfDay.map { NSNumber(value: $0) }
            object.partOfDay = event.partOfDay?.rawValue
            object.order = Int16(event.order)
        }
        try save()
    }
}
