import Foundation
import os

/// Reads Apple Journal exports into journal events (`.scratch/day-page/issues/07`). John
/// exports the whole journal from the Mac (File → Export) into one iCloud Drive folder he
/// picks once in Settings; whenever Coar opens, entries about the last 30 Days that are new or
/// changed are read on device and their events stored. The entry text itself isn't kept.
@MainActor
final class JournalImporter {

    /// What Settings shows.
    struct Status: Codable, Equatable {
        var folderName: String?
        var lastChecked: Date?
        /// Entries from the last month that have events.
        var read = 0
        /// Entries waiting for the on-device model.
        var waiting = 0
        var problem: String?
    }

    static let days = 30
    private static let logger = Logger(category: "Journal")
    private static let bookmarkKey = "journalFolderBookmark"
    private static let statusKey = "journalStatus"

    private let store: Store
    private let reader: JournalReading
    private let defaults: UserDefaults
    private var running = false

    init(store: Store, reader: JournalReading, defaults: UserDefaults = .standard) {
        self.store = store
        self.reader = reader
        self.defaults = defaults
    }

    private(set) var status: Status {
        get { defaults.data(forKey: Self.statusKey).flatMap { try? JSONDecoder().decode(Status.self, from: $0) } ?? Status() }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.statusKey) }
    }

    /// Keeps a bookmark to the folder (this device only) and reads it.
    func setFolder(_ url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            defaults.set(try url.bookmarkData(), forKey: Self.bookmarkKey)
            var status = self.status
            status.folderName = url.lastPathComponent
            status.problem = nil
            self.status = status
        } catch {
            Self.logger.error("Failed to keep the journal folder: \(error, privacy: .public)")
        }
        await run(force: true)
    }

    /// Reads what's new, at most every ten minutes unless forced.
    func run(force: Bool = false, today: Day = .today()) async {
        guard !running, let bookmark = defaults.data(forKey: Self.bookmarkKey) else { return }
        if !force, let last = status.lastChecked, Date().timeIntervalSince(last) < 600 { return }
        running = true
        defer { running = false }
        var stale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale) else {
            var status = self.status
            status.problem = "Coar can't find the journal folder any more. Choose it again."
            self.status = status
            return
        }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        if stale, let fresh = try? folder.bookmarkData() { defaults.set(fresh, forKey: Self.bookmarkKey) }
        status = await importEntries(in: folder, today: today, previous: status)
    }

    /// The pass itself, apart from bookmarks so tests can point it at a folder.
    func importEntries(in folder: URL, today: Day, previous: Status = Status()) async -> Status {
        var status = previous
        status.lastChecked = Date()
        status.problem = nil
        guard let entries = Self.entriesFolder(in: folder) else {
            status.problem = "No journal export in that folder. Export from Journal on your Mac (File → Export) into it."
            return status
        }
        let first = today.advanced(by: 1 - Self.days)
        // A file is named for when it was written, up to a day after the Day it's about.
        let names = Self.entryNames(in: entries).filter { name in JournalExport.fileDay(name).map { $0 >= first.advanced(by: -1) } ?? false }
        let known = (try? store.journalEntriesRead()) ?? [:]
        var read = 0, waiting = 0
        for name in names {
            guard let html = await Self.read(entries.appending(path: name)),
                  let entry = JournalExport.parse(html: html, fileName: name),
                  entry.day >= first, entry.day <= today else { continue }
            if let place = entry.place {
                try? store.setPlace(on: entry.day, latitude: place.latitude, longitude: place.longitude, name: place.name, fromJournal: true)
            }
            if known[name]?.textHash == entry.textHash { read += 1; continue }
            guard reader.isAvailable else { waiting += 1; continue }
            do {
                let events = try await reader.events(in: entry)
                try store.saveJournalRead(JournalEntryRead(fileName: name, day: entry.day, textHash: entry.textHash), events: events)
                read += 1
            } catch {
                Self.logger.error("Failed to read a journal entry: \(error, privacy: .public)")
                waiting += 1
            }
        }
        status.read = read
        status.waiting = waiting
        if waiting > 0, !reader.isAvailable {
            status.problem = "Turn on Apple Intelligence to read \(waiting) \(waiting == 1 ? "entry" : "entries") on this iPhone."
        }
        return status
    }

    /// `Entries/` in the chosen folder, in an `AppleJournalEntries` export inside it, or one
    /// level further down.
    static func entriesFolder(in folder: URL) -> URL? {
        let manager = FileManager.default
        let candidates = [folder.appending(path: "Entries"), folder.appending(path: "AppleJournalEntries/Entries")]
            + ((try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []).map { $0.appending(path: "Entries") }
        return candidates.first { url in
            var isDirectory: ObjCBool = false
            return manager.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory) && isDirectory.boolValue
        } ?? (folder.lastPathComponent == "Entries" ? folder : nil)
    }

    /// The entry files' names, including ones iCloud hasn't brought down yet (listed as
    /// ".name.icloud").
    static func entryNames(in folder: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        return names.compactMap { name in
            if name.hasPrefix("."), name.hasSuffix(".icloud") { return String(name.dropFirst().dropLast(7)) }
            return name.hasSuffix(".html") ? name : nil
        }.sorted()
    }

    /// The file's text, downloading it from iCloud first if needed.
    private static func read(_ url: URL) async -> String? {
        await Task.detached {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            var text: String?
            var coordinationError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                text = try? String(contentsOf: readable, encoding: .utf8)
            }
            return text
        }.value
    }
}

#if DEBUG
/// Splits an entry one event per line, for a simulator without Apple Intelligence.
final class DebugJournalReader: JournalReading {
    var isAvailable: Bool { true }
    func events(in entry: JournalExportEntry) async throws -> [JournalEventRecord] {
        entry.text.split(separator: "\n").prefix(6).enumerated().map { index, line in
            JournalEventRecord(day: entry.day, title: String(line.prefix(40)), category: .other, minuteOfDay: nil, partOfDay: .afternoon, order: index)
        }
    }
}
#endif
