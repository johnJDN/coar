import CoreData
import Foundation

/// What the Watch doesn't know about one of its workouts (`.scratch/walks/issues/01`): whether
/// the inhaler was used before it, and a treadmill's speed and incline. Kept by the Health
/// Workout's identifier, as a link is (ADR 0002: nothing of Health's is copied).
struct WorkoutNoteRecord: Equatable {
    let healthWorkoutID: UUID
    var usedInhaler = false
    var speedKmh: Double?
    var inclinePercent: Double?

    var isEmpty: Bool { !usedInhaler && speedKmh == nil && inclinePercent == nil }

    /// "3.0 mph · 6%", in the locale's unit; nil without both.
    var settingsText: String? {
        guard let speedKmh, let inclinePercent else { return nil }
        return "\(TreadmillSpeed.text(speedKmh)) · \(inclinePercent.formatted(.number.precision(.fractionLength(0...1))))%"
    }
}

/// A treadmill's speed in the unit its display shows: mph with US units, else km/h. Kept in
/// km/h.
enum TreadmillSpeed {
    static var usesMiles: Bool { Locale.current.measurementSystem == .us }
    static let kmPerMile = 1.609344

    static var unit: String { usesMiles ? "mph" : "km/h" }

    static func display(_ kmh: Double) -> Double {
        let value = usesMiles ? kmh / kmPerMile : kmh
        return (value * 10).rounded() / 10
    }

    static func kmh(fromDisplay value: Double) -> Double {
        usesMiles ? value * kmPerMile : value
    }

    static func text(_ kmh: Double) -> String {
        "\(display(kmh).formatted(.number.precision(.fractionLength(1)))) \(unit)"
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
            result[id] = WorkoutNoteRecord(healthWorkoutID: id, usedInhaler: note.usedInhaler, speedKmh: note.speedKmh?.doubleValue, inclinePercent: note.inclinePercent?.doubleValue)
        }
        return result
    }

    /// The speed and incline most recently set on any workout, for "Same as last time".
    func latestTreadmillSettings() throws -> (speedKmh: Double, inclinePercent: Double)? {
        let request = WorkoutNote.fetchRequest()
        request.predicate = NSPredicate(format: "speedKmh != nil AND inclinePercent != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        guard let note = try context.fetch(request).first, let speed = note.speedKmh?.doubleValue, let incline = note.inclinePercent?.doubleValue else { return nil }
        return (speed, incline)
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
            object.speedKmh = note.speedKmh.map { NSNumber(value: $0) }
            object.inclinePercent = note.inclinePercent.map { NSNumber(value: $0) }
        }
        try save()
    }
}
