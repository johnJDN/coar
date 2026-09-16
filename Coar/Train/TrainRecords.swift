import Foundation

/// One of the fixed body regions an Exercise primarily trains (CONTEXT.md "Muscle Group").
/// Never free text; raw values are stored.
enum MuscleGroup: Int16, CaseIterable {
    case chest = 0
    case back = 1
    case shoulders = 2
    case biceps = 3
    case triceps = 4
    case forearms = 5
    case core = 6
    case quads = 7
    case hamstrings = 8
    case glutes = 9
    case calves = 10

    var title: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .core: return "Core"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        }
    }
}

/// A rep range as a Plan prescribes it (CONTEXT.md "Planned Set"): a min and a max; a single
/// number is min = max and shows as one number.
struct RepRange: Hashable {
    let min: Int
    let max: Int

    /// A range; a max below the min is lifted to it.
    init(min: Int, max: Int) {
        self.min = min
        self.max = Swift.max(min, max)
    }

    /// A single rep count: min = max.
    init(_ reps: Int) {
        self.init(min: reps, max: reps)
    }

    /// "5" or "8–12".
    var text: String {
        min == max ? "\(min)" : "\(min)–\(max)"
    }
}

/// An Exercise as read through the façade (CONTEXT.md "Exercise"): a named movement with its
/// primary Muscle Group, the equipment it uses when given, and its own rest default when it
/// has one.
struct ExerciseRecord: Hashable, Identifiable {
    let id: UUID
    let name: String
    let muscleGroup: MuscleGroup
    /// Nil when none was given.
    let equipment: String?
    /// Nil when the Exercise has no default of its own.
    let restSeconds: Int?
    let isArchived: Bool
    let modifiedAt: Date
}

/// A Plan as read through the façade (CONTEXT.md "Plan"): a named, ordered list of Exercises
/// with their Planned Sets. Exercise names and details are read live from the catalogue; a
/// Workout takes its own copy when it starts (ADR 0003).
struct PlanRecord: Hashable, Identifiable {
    let id: UUID
    let name: String
    let isArchived: Bool
    let exercises: [PlanExerciseRecord]
    let modifiedAt: Date
}

/// One row of a Plan: an Exercise, its place in a Superset if any, and its Planned Sets.
struct PlanExerciseRecord: Hashable, Identifiable {
    let id: UUID
    /// The Exercise as it stands now.
    let exercise: ExerciseRecord
    /// Adjacent rows sharing a group are one Superset (CONTEXT.md "Superset"); nil for a
    /// row on its own.
    let supersetGroup: Int?
    let sets: [PlannedSetRecord]

    var exerciseID: ExerciseRecord.ID { exercise.id }
}

/// A Planned Set as read through the façade: the target weight in kilograms (ADR 0004) and
/// the rep range.
struct PlannedSetRecord: Hashable, Identifiable {
    let id: UUID
    let targetKilograms: Double
    let reps: RepRange
}

/// A Plan row as typed on the Plan editor. New drafts get a fresh `id`; drafts carrying an
/// existing row's `id` update it in place, so reordering keeps identity.
struct PlanExerciseDraft: Hashable, Identifiable {
    var id: UUID
    var exerciseID: ExerciseRecord.ID
    var supersetGroup: Int?
    var sets: [PlannedSetDraft]

    init(id: UUID = UUID(), exerciseID: ExerciseRecord.ID, supersetGroup: Int?, sets: [PlannedSetDraft]) {
        self.id = id
        self.exerciseID = exerciseID
        self.supersetGroup = supersetGroup
        self.sets = sets
    }

    init(_ record: PlanExerciseRecord) {
        self.init(id: record.id, exerciseID: record.exerciseID, supersetGroup: record.supersetGroup, sets: record.sets.map(PlannedSetDraft.init))
    }
}

/// A Planned Set as typed on the Plan editor, its weight already in kilograms.
struct PlannedSetDraft: Hashable, Identifiable {
    var id: UUID
    var targetKilograms: Double
    var reps: RepRange

    init(id: UUID = UUID(), targetKilograms: Double, reps: RepRange) {
        self.id = id
        self.targetKilograms = targetKilograms
        self.reps = reps
    }

    /// A set whose weight was typed in the display unit: stored as the kilograms of that
    /// value at display precision (ADR 0004).
    init(id: UUID = UUID(), weight: Double, in unit: MassUnit, reps: RepRange) {
        self.init(id: id, targetKilograms: unit.kilograms(fromDisplayValue: weight), reps: reps)
    }

    init(_ record: PlannedSetRecord) {
        self.init(id: record.id, targetKilograms: record.targetKilograms, reps: record.reps)
    }
}
