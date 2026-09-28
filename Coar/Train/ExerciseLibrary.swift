import Foundation

/// The built-in exercise library (`.scratch/exercise-library/`): common gym and home exercises
/// with their muscle groups and equipment in Coar's own terms, generated from the reviewed
/// `list.md`. Adding one copies it into the user's catalogue as an ordinary Exercise; nothing
/// links back here.
enum ExerciseLibrary {

    struct Entry: Hashable {
        let name: String
        let muscleGroup: MuscleGroup
        /// Also works, most important first; never the primary group.
        let secondaryMuscleGroups: [MuscleGroup]
        /// As Exercises store it: an `Equipment` title, or the name of anything else.
        let equipment: String

        init(_ name: String, _ muscleGroup: MuscleGroup, also: [MuscleGroup], equipment: String) {
            self.name = name
            self.muscleGroup = muscleGroup
            self.secondaryMuscleGroups = also
            self.equipment = equipment
        }
    }

    static let entries: [Entry] = [
        // Chest
        Entry("Bench press", .chest, also: [.triceps, .shoulders], equipment: "Barbell"),
        Entry("Incline bench press", .chest, also: [.shoulders, .triceps], equipment: "Barbell"),
        Entry("Decline bench press", .chest, also: [.triceps], equipment: "Barbell"),
        Entry("Dumbbell bench press", .chest, also: [.triceps, .shoulders], equipment: "Dumbbell"),
        Entry("Incline dumbbell press", .chest, also: [.shoulders, .triceps], equipment: "Dumbbell"),
        Entry("Decline dumbbell press", .chest, also: [.triceps], equipment: "Dumbbell"),
        Entry("Dumbbell floor press", .chest, also: [.triceps], equipment: "Dumbbell"),
        Entry("Dumbbell fly", .chest, also: [.shoulders], equipment: "Dumbbell"),
        Entry("Incline dumbbell fly", .chest, also: [.shoulders], equipment: "Dumbbell"),
        Entry("Dumbbell pullover", .chest, also: [.back, .triceps], equipment: "Dumbbell"),
        Entry("Cable fly", .chest, also: [.shoulders], equipment: "Cable"),
        Entry("Low-to-high cable fly", .chest, also: [.shoulders], equipment: "Cable"),
        Entry("Machine chest press", .chest, also: [.triceps, .shoulders], equipment: "Machine"),
        Entry("Incline machine press", .chest, also: [.shoulders, .triceps], equipment: "Machine"),
        Entry("Pec deck", .chest, also: [.shoulders], equipment: "Machine"),
        Entry("Smith machine bench press", .chest, also: [.triceps, .shoulders], equipment: "Smith machine"),
        Entry("Smith machine incline press", .chest, also: [.shoulders, .triceps], equipment: "Smith machine"),
        Entry("Push-up", .chest, also: [.triceps, .shoulders, .core], equipment: "Bodyweight"),
        Entry("Incline push-up", .chest, also: [.triceps, .shoulders], equipment: "Bodyweight"),
        Entry("Decline push-up", .chest, also: [.shoulders, .triceps], equipment: "Bodyweight"),
        Entry("Chest dip", .chest, also: [.triceps, .shoulders], equipment: "Bodyweight"),

        // Back
        Entry("Deadlift", .back, also: [.glutes, .hamstrings, .forearms], equipment: "Barbell"),
        Entry("Rack pull", .back, also: [.glutes, .forearms], equipment: "Barbell"),
        Entry("Barbell row", .back, also: [.biceps, .shoulders], equipment: "Barbell"),
        Entry("Pendlay row", .back, also: [.biceps, .shoulders], equipment: "Barbell"),
        Entry("T-bar row", .back, also: [.biceps, .shoulders], equipment: "Barbell"),
        Entry("Barbell shrug", .back, also: [.forearms], equipment: "Barbell"),
        Entry("Dumbbell deadlift", .back, also: [.glutes, .hamstrings, .forearms], equipment: "Dumbbell"),
        Entry("Dumbbell bent-over row", .back, also: [.biceps, .shoulders], equipment: "Dumbbell"),
        Entry("Single-arm dumbbell row", .back, also: [.biceps], equipment: "Dumbbell"),
        Entry("Renegade row", .back, also: [.core, .biceps], equipment: "Dumbbell"),
        Entry("Chest-supported dumbbell row", .back, also: [.biceps, .shoulders], equipment: "Dumbbell"),
        Entry("Dumbbell shrug", .back, also: [.forearms], equipment: "Dumbbell"),
        Entry("Lat pulldown", .back, also: [.biceps], equipment: "Cable"),
        Entry("Close-grip lat pulldown", .back, also: [.biceps], equipment: "Cable"),
        Entry("Straight-arm pulldown", .back, also: [], equipment: "Cable"),
        Entry("Seated cable row", .back, also: [.biceps], equipment: "Cable"),
        Entry("Single-arm cable row", .back, also: [.biceps], equipment: "Cable"),
        Entry("Machine row", .back, also: [.biceps], equipment: "Machine"),
        Entry("Assisted pull-up", .back, also: [.biceps], equipment: "Machine"),
        Entry("Pull-up", .back, also: [.biceps, .forearms], equipment: "Bodyweight"),
        Entry("Chin-up", .back, also: [.biceps, .forearms], equipment: "Bodyweight"),
        Entry("Inverted row", .back, also: [.biceps, .core], equipment: "Bodyweight"),
        Entry("Back extension", .back, also: [.glutes, .hamstrings], equipment: "Bodyweight"),

        // Shoulders
        Entry("Overhead press", .shoulders, also: [.triceps, .core], equipment: "Barbell"),
        Entry("Landmine press", .shoulders, also: [.chest, .triceps], equipment: "Barbell"),
        Entry("Upright row", .shoulders, also: [.back, .biceps], equipment: "EZ bar"),
        Entry("Seated dumbbell shoulder press", .shoulders, also: [.triceps], equipment: "Dumbbell"),
        Entry("Standing dumbbell shoulder press", .shoulders, also: [.triceps, .core], equipment: "Dumbbell"),
        Entry("Arnold press", .shoulders, also: [.triceps], equipment: "Dumbbell"),
        Entry("Lateral raise", .shoulders, also: [], equipment: "Dumbbell"),
        Entry("Front raise", .shoulders, also: [.chest], equipment: "Dumbbell"),
        Entry("Rear delt fly", .shoulders, also: [.back], equipment: "Dumbbell"),
        Entry("Cable lateral raise", .shoulders, also: [], equipment: "Cable"),
        Entry("Face pull", .shoulders, also: [.back], equipment: "Cable"),
        Entry("Machine shoulder press", .shoulders, also: [.triceps], equipment: "Machine"),
        Entry("Machine lateral raise", .shoulders, also: [], equipment: "Machine"),
        Entry("Reverse pec deck", .shoulders, also: [.back], equipment: "Machine"),
        Entry("Smith machine shoulder press", .shoulders, also: [.triceps], equipment: "Smith machine"),
        Entry("Band pull-apart", .shoulders, also: [.back], equipment: "Band"),
        Entry("Pike push-up", .shoulders, also: [.triceps], equipment: "Bodyweight"),

        // Biceps
        Entry("Barbell curl", .biceps, also: [.forearms], equipment: "Barbell"),
        Entry("EZ bar curl", .biceps, also: [.forearms], equipment: "EZ bar"),
        Entry("Preacher curl", .biceps, also: [], equipment: "EZ bar"),
        Entry("Dumbbell curl", .biceps, also: [.forearms], equipment: "Dumbbell"),
        Entry("Hammer curl", .biceps, also: [.forearms], equipment: "Dumbbell"),
        Entry("Incline dumbbell curl", .biceps, also: [], equipment: "Dumbbell"),
        Entry("Concentration curl", .biceps, also: [], equipment: "Dumbbell"),
        Entry("Spider curl", .biceps, also: [], equipment: "Dumbbell"),
        Entry("Cable curl", .biceps, also: [.forearms], equipment: "Cable"),
        Entry("Bayesian cable curl", .biceps, also: [], equipment: "Cable"),

        // Triceps
        Entry("Close-grip bench press", .triceps, also: [.chest, .shoulders], equipment: "Barbell"),
        Entry("Skull crusher", .triceps, also: [], equipment: "EZ bar"),
        Entry("Close-grip dumbbell press", .triceps, also: [.chest, .shoulders], equipment: "Dumbbell"),
        Entry("Dumbbell skull crusher", .triceps, also: [], equipment: "Dumbbell"),
        Entry("Overhead dumbbell triceps extension", .triceps, also: [], equipment: "Dumbbell"),
        Entry("Triceps kickback", .triceps, also: [], equipment: "Dumbbell"),
        Entry("Triceps pushdown", .triceps, also: [], equipment: "Cable"),
        Entry("Rope pushdown", .triceps, also: [], equipment: "Cable"),
        Entry("Overhead cable triceps extension", .triceps, also: [], equipment: "Cable"),
        Entry("Machine dip", .triceps, also: [.chest, .shoulders], equipment: "Machine"),
        Entry("Triceps dip", .triceps, also: [.chest, .shoulders], equipment: "Bodyweight"),
        Entry("Bench dip", .triceps, also: [.chest, .shoulders], equipment: "Bodyweight"),
        Entry("Diamond push-up", .triceps, also: [.chest, .shoulders], equipment: "Bodyweight"),

        // Forearms
        Entry("Reverse curl", .forearms, also: [.biceps], equipment: "EZ bar"),
        Entry("Wrist curl", .forearms, also: [], equipment: "Dumbbell"),
        Entry("Reverse wrist curl", .forearms, also: [], equipment: "Dumbbell"),
        Entry("Farmer's carry", .forearms, also: [.back, .core], equipment: "Dumbbell"),
        Entry("Dead hang", .forearms, also: [.back], equipment: "Bodyweight"),

        // Core
        Entry("Russian twist", .core, also: [], equipment: "Dumbbell"),
        Entry("Dumbbell side bend", .core, also: [], equipment: "Dumbbell"),
        Entry("Cable crunch", .core, also: [], equipment: "Cable"),
        Entry("Pallof press", .core, also: [], equipment: "Cable"),
        Entry("Cable woodchopper", .core, also: [.shoulders], equipment: "Cable"),
        Entry("Ab wheel rollout", .core, also: [.shoulders], equipment: "Ab wheel"),
        Entry("Plank", .core, also: [], equipment: "Bodyweight"),
        Entry("Side plank", .core, also: [], equipment: "Bodyweight"),
        Entry("Hanging leg raise", .core, also: [.forearms], equipment: "Bodyweight"),
        Entry("Hanging knee raise", .core, also: [.forearms], equipment: "Bodyweight"),
        Entry("Lying leg raise", .core, also: [], equipment: "Bodyweight"),
        Entry("Crunch", .core, also: [], equipment: "Bodyweight"),
        Entry("Decline sit-up", .core, also: [], equipment: "Bodyweight"),
        Entry("Bicycle crunch", .core, also: [], equipment: "Bodyweight"),
        Entry("Dead bug", .core, also: [], equipment: "Bodyweight"),
        Entry("Hollow hold", .core, also: [], equipment: "Bodyweight"),

        // Quads
        Entry("Back squat", .quads, also: [.glutes, .hamstrings, .core], equipment: "Barbell"),
        Entry("Front squat", .quads, also: [.glutes, .core], equipment: "Barbell"),
        Entry("Goblet squat", .quads, also: [.glutes, .core], equipment: "Dumbbell"),
        Entry("Heel-elevated goblet squat", .quads, also: [.glutes, .core], equipment: "Dumbbell"),
        Entry("Dumbbell sumo squat", .quads, also: [.glutes], equipment: "Dumbbell"),
        Entry("Bulgarian split squat", .quads, also: [.glutes], equipment: "Dumbbell"),
        Entry("Dumbbell split squat", .quads, also: [.glutes], equipment: "Dumbbell"),
        Entry("Walking lunge", .quads, also: [.glutes, .hamstrings], equipment: "Dumbbell"),
        Entry("Reverse lunge", .quads, also: [.glutes, .hamstrings], equipment: "Dumbbell"),
        Entry("Lateral lunge", .quads, also: [.glutes, .hamstrings], equipment: "Dumbbell"),
        Entry("Step-up", .quads, also: [.glutes], equipment: "Dumbbell"),
        Entry("Leg press", .quads, also: [.glutes, .hamstrings], equipment: "Machine"),
        Entry("Hack squat", .quads, also: [.glutes], equipment: "Machine"),
        Entry("Pendulum squat", .quads, also: [.glutes], equipment: "Machine"),
        Entry("Leg extension", .quads, also: [], equipment: "Machine"),
        Entry("Smith machine squat", .quads, also: [.glutes], equipment: "Smith machine"),
        Entry("Bodyweight squat", .quads, also: [.glutes], equipment: "Bodyweight"),
        Entry("Wall sit", .quads, also: [], equipment: "Bodyweight"),

        // Hamstrings
        Entry("Romanian deadlift", .hamstrings, also: [.glutes, .back], equipment: "Barbell"),
        Entry("Stiff-leg deadlift", .hamstrings, also: [.glutes, .back], equipment: "Barbell"),
        Entry("Good morning", .hamstrings, also: [.back, .glutes], equipment: "Barbell"),
        Entry("Dumbbell Romanian deadlift", .hamstrings, also: [.glutes, .back], equipment: "Dumbbell"),
        Entry("Single-leg Romanian deadlift", .hamstrings, also: [.glutes, .core], equipment: "Dumbbell"),
        Entry("Lying leg curl", .hamstrings, also: [], equipment: "Machine"),
        Entry("Seated leg curl", .hamstrings, also: [], equipment: "Machine"),
        Entry("Nordic curl", .hamstrings, also: [], equipment: "Bodyweight"),

        // Glutes
        Entry("Hip thrust", .glutes, also: [.hamstrings], equipment: "Barbell"),
        Entry("Sumo deadlift", .glutes, also: [.quads, .hamstrings, .back], equipment: "Barbell"),
        Entry("Trap bar deadlift", .glutes, also: [.quads, .hamstrings, .back], equipment: "Trap bar"),
        Entry("Dumbbell hip thrust", .glutes, also: [.hamstrings], equipment: "Dumbbell"),
        Entry("Kettlebell swing", .glutes, also: [.hamstrings, .core], equipment: "Kettlebell"),
        Entry("Cable kickback", .glutes, also: [.hamstrings], equipment: "Cable"),
        Entry("Cable pull-through", .glutes, also: [.hamstrings], equipment: "Cable"),
        Entry("Machine hip thrust", .glutes, also: [.hamstrings], equipment: "Machine"),
        Entry("Hip abduction", .glutes, also: [], equipment: "Machine"),
        Entry("Hip adduction", .glutes, also: [], equipment: "Machine"),
        Entry("Glute bridge", .glutes, also: [.hamstrings], equipment: "Bodyweight"),
        Entry("Single-leg glute bridge", .glutes, also: [.hamstrings], equipment: "Bodyweight"),

        // Calves
        Entry("Single-leg dumbbell calf raise", .calves, also: [], equipment: "Dumbbell"),
        Entry("Standing calf raise", .calves, also: [], equipment: "Machine"),
        Entry("Seated calf raise", .calves, also: [], equipment: "Machine"),
        Entry("Leg press calf raise", .calves, also: [], equipment: "Machine"),
        Entry("Smith machine calf raise", .calves, also: [], equipment: "Smith machine"),
    ]
}

extension ExerciseLibrary {

    /// A name as the library compares names: case and spacing don't matter.
    static func key(_ name: String) -> String {
        name.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The entry with exactly this name, if the library has one.
    static func entry(named name: String) -> Entry? {
        let wanted = key(name)
        return entries.first { key($0.name) == wanted }
    }

    /// The entries to offer, by primary muscle group in `MuscleGroup` order: none the user
    /// already has (any exercise of theirs with that name, archived too, so a second copy is
    /// never made), and only those whose name or primary group matches `filter`.
    static func offered(excluding existingNames: [String], filter: String) -> [(group: MuscleGroup, entries: [Entry])] {
        let have = Set(existingNames.map(key))
        let filter = key(filter)
        let shown = entries.filter { entry in
            !have.contains(key(entry.name))
                && (filter.isEmpty || key(entry.name).contains(filter) || key(entry.muscleGroup.title).contains(filter))
        }
        return MuscleGroup.allCases.compactMap { group in
            let inGroup = shown.filter { $0.muscleGroup == group }
            return inGroup.isEmpty ? nil : (group, inGroup)
        }
    }

    /// Copies the entry into the user's catalogue: an ordinary Exercise from here on.
    @MainActor @discardableResult
    static func add(_ entry: Entry, to store: Store) throws -> ExerciseRecord {
        try store.createExercise(name: entry.name, muscleGroup: entry.muscleGroup, secondaryMuscleGroups: entry.secondaryMuscleGroups, equipment: entry.equipment)
    }

    /// "Chest + Triceps, Shoulders · Dumbbell", as a user's exercise reads in lists.
    static func details(of entry: Entry) -> String {
        let muscles = entry.secondaryMuscleGroups.isEmpty
            ? entry.muscleGroup.title
            : "\(entry.muscleGroup.title) + \(entry.secondaryMuscleGroups.map(\.title).joined(separator: ", "))"
        return "\(muscles) · \(entry.equipment)"
    }
}
