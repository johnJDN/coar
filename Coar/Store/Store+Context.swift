import CoreData
import Foundation

/// About me (CONTEXT.md "About me"): the user's birthday, sex, and height. Stored in Coar,
/// filled from Apple Health on request; any field may be unknown.
struct AboutMe: Equatable {
    enum Sex: String, CaseIterable {
        case female, male, other

        var title: String {
            switch self {
            case .female: return "Female"
            case .male: return "Male"
            case .other: return "Other"
            }
        }
    }

    var birthDate: Date?
    var sex: Sex?
    var heightCentimetres: Double?

    var isEmpty: Bool { birthDate == nil && sex == nil && heightCentimetres == nil }

    /// Whole years on a Day, or nil without a birthday.
    func age(on day: Day = .today(), calendar: Calendar = .current) -> Int? {
        birthDate.flatMap { calendar.dateComponents([.year], from: $0, to: day.start(in: calendar)).year }
    }

    /// What Health has filled in, kept where Coar already has a value.
    func filling(from health: AboutMe) -> AboutMe {
        AboutMe(birthDate: birthDate ?? health.birthDate, sex: sex ?? health.sex, heightCentimetres: heightCentimetres ?? health.heightCentimetres)
    }
}

/// A Day's mood and energy, each 1 (lowest) to 5, or nil before it's set.
struct MoodRecord: Equatable {
    let day: Day
    var mood: Int?
    var energy: Int?
}

/// Where the user was on a Day: a rounded location and its name, recorded once a Day by the
/// device, or read from a journal entry's "Written at".
struct PlaceRecord: Equatable {
    let day: Day
    let latitude: Double
    let longitude: Double
    let name: String
    let fromJournal: Bool
}

extension Store {

    // MARK: - About me

    func aboutMe() throws -> AboutMe {
        let request = Profile.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        guard let profile = try context.fetch(request).first else { return AboutMe() }
        return AboutMe(birthDate: profile.birthDate, sex: profile.sex.flatMap(AboutMe.Sex.init), heightCentimetres: profile.heightCentimetres?.doubleValue)
    }

    func setAboutMe(_ aboutMe: AboutMe) throws {
        let existing = try context.fetch(Profile.fetchRequest())
        let profile = existing.first ?? Profile(context: context)
        existing.dropFirst().forEach(context.delete)
        profile.birthDate = aboutMe.birthDate
        profile.sex = aboutMe.sex?.rawValue
        profile.heightCentimetres = aboutMe.heightCentimetres.map { NSNumber(value: $0) }
        try save()
    }

    // MARK: - Mood and energy

    func mood(on day: Day) throws -> MoodRecord? {
        try fetchMood(on: day).map { MoodRecord(day: day, mood: $0.mood > 0 ? Int($0.mood) : nil, energy: $0.energy > 0 ? Int($0.energy) : nil) }
    }

    /// Sets one or both for a Day; nil leaves that one as it was.
    func setMood(on day: Day, mood: Int? = nil, energy: Int? = nil) throws {
        let record = try fetchMood(on: day) ?? DayMood(context: context)
        record.day = day.rawValue
        if let mood { record.mood = Int16(min(5, max(1, mood))) }
        if let energy { record.energy = Int16(min(5, max(1, energy))) }
        try save()
    }

    private func fetchMood(on day: Day) throws -> DayMood? {
        let request = DayMood.fetchRequest()
        request.predicate = NSPredicate(format: "day == %@", day.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    // MARK: - Place

    /// The Day's place: the device's if it recorded one, else a journal entry's.
    func place(on day: Day) throws -> PlaceRecord? {
        let request = DayPlace.fetchRequest()
        request.predicate = NSPredicate(format: "day == %@", day.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "fromJournal", ascending: true), NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first.flatMap { PlaceRecord($0) }
    }

    /// Records a Day's place. The device's replaces whatever the Day had; a journal's is kept
    /// only while the device has none.
    func setPlace(on day: Day, latitude: Double, longitude: Double, name: String, fromJournal: Bool) throws {
        let request = DayPlace.fetchRequest()
        request.predicate = NSPredicate(format: "day == %@", day.rawValue)
        let existing = try context.fetch(request)
        if fromJournal, existing.contains(where: { !$0.fromJournal }) { return }
        let record = existing.first(where: { $0.fromJournal == fromJournal }) ?? DayPlace(context: context)
        if !fromJournal { existing.filter { $0 != record }.forEach(context.delete) }
        record.day = day.rawValue
        record.latitude = latitude
        record.longitude = longitude
        record.name = name
        record.fromJournal = fromJournal
        try save()
    }
}

private extension PlaceRecord {
    init?(_ object: DayPlace) {
        guard let raw = object.day, let day = Day(rawValue: raw) else { return nil }
        self.init(day: day, latitude: object.latitude, longitude: object.longitude, name: object.name ?? "", fromJournal: object.fromJournal)
    }
}
