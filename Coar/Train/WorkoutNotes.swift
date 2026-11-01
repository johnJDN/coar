import CoreData
import Foundation

/// What the Watch doesn't know about one of its workouts (`.scratch/walks/issues/01`): whether
/// the inhaler was used before it, and on a treadmill the distance its display showed at the
/// end and the incline it was mostly at. Kept by the Health Workout's identifier, as a link is
/// (ADR 0002: nothing of Health's is copied).
struct WorkoutNoteRecord: Equatable {
    let healthWorkoutID: UUID
    var usedInhaler = false
    /// The treadmill's distance, in metres.
    var treadmillMeters: Double?
    /// The average incline, roughly, when it changed during the walk.
    var inclinePercent: Double?

    var isEmpty: Bool { !usedInhaler && treadmillMeters == nil && inclinePercent == nil }

    /// "1.80 mi · 5%", in the locale's unit; nil without both.
    var settingsText: String? {
        guard let treadmillMeters, let inclinePercent else { return nil }
        return "\(TreadmillUnits.distanceText(treadmillMeters)) · \(TreadmillUnits.inclineText(inclinePercent))"
    }
}

/// A treadmill's numbers in the units its display shows: miles and mph with US units, else
/// kilometres and km/h. Kept in metres.
enum TreadmillUnits {
    static var usesMiles: Bool { Locale.current.measurementSystem == .us }
    static let metersPerMile = 1_609.344

    static var distanceUnit: String { usesMiles ? "mi" : "km" }
    static var speedUnit: String { usesMiles ? "mph" : "km/h" }

    static func displayDistance(_ meters: Double) -> Double {
        let value = usesMiles ? meters / metersPerMile : meters / 1_000
        return (value * 100).rounded() / 100
    }

    static func meters(fromDisplay value: Double) -> Double {
        usesMiles ? value * metersPerMile : value * 1_000
    }

    static func distanceText(_ meters: Double) -> String {
        "\(displayDistance(meters).formatted(.number.precision(.fractionLength(2)))) \(distanceUnit)"
    }

    /// A speed in metres a minute, shown as mph or km/h.
    static func displaySpeed(metersPerMinute: Double) -> Double {
        metersPerMinute * 60 / (usesMiles ? metersPerMile : 1_000)
    }

    static func metersPerMinute(fromDisplaySpeed value: Double) -> Double {
        value * (usesMiles ? metersPerMile : 1_000) / 60
    }

    static func speedText(metersPerMinute: Double) -> String {
        "\(displaySpeed(metersPerMinute: metersPerMinute).formatted(.number.precision(.fractionLength(1)))) \(speedUnit)"
    }

    static func inclineText(_ percent: Double) -> String {
        "\(percent.formatted(.number.precision(.fractionLength(0...1))))%"
    }
}

extension Store {

    func workoutNotes(for ids: [UUID]) throws -> [UUID: WorkoutNoteRecord] {
        guard !ids.isEmpty else { return [:] }
        let request = WorkoutNote.fetchRequest()
        request.predicate = NSPredicate(format: "healthWorkoutID IN %@", ids)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: true)]
        var result: [UUID: WorkoutNoteRecord] = [:]
        for note in try context.fetch(request) {
            guard let id = note.healthWorkoutID else { continue }
            result[id] = WorkoutNoteRecord(healthWorkoutID: id, usedInhaler: note.usedInhaler, treadmillMeters: note.treadmillMeters?.doubleValue,
                                           inclinePercent: note.inclinePercent?.doubleValue)
        }
        return result
    }

    /// The incline most recently set on any workout, for "Same incline as last time".
    func latestIncline() throws -> Double? {
        let request = WorkoutNote.fetchRequest()
        request.predicate = NSPredicate(format: "inclinePercent != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first?.inclinePercent?.doubleValue
    }

    /// Saves a workout's note; an empty one is removed.
    func setWorkoutNote(_ note: WorkoutNoteRecord) throws {
        let request = WorkoutNote.fetchRequest()
        request.predicate = NSPredicate(format: "healthWorkoutID == %@", note.healthWorkoutID as CVarArg)
        let existing = try context.fetch(request)
        if note.isEmpty {
            existing.forEach(context.delete)
        } else {
            let object = existing.first ?? WorkoutNote(context: context)
            existing.dropFirst().forEach(context.delete)
            object.healthWorkoutID = note.healthWorkoutID
            object.usedInhaler = note.usedInhaler
            object.treadmillMeters = note.treadmillMeters.map { NSNumber(value: $0) }
            object.inclinePercent = note.inclinePercent.map { NSNumber(value: $0) }
        }
        try save()
    }
}
