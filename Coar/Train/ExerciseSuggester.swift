import Foundation
import os

/// What New exercise fills in from a name (`.scratch/exercise-library/issues/02`): the
/// primary muscle group, the groups it also works, and the equipment, and where they came from.
struct ExerciseSuggestion: Equatable {

    enum Source: Equatable {
        case library, ai
    }

    let muscleGroup: MuscleGroup
    /// Never the primary group, none repeated.
    let secondaryMuscleGroups: [MuscleGroup]
    /// As Exercises store it; nil for none.
    let equipment: String?
    let source: Source

    init(muscleGroup: MuscleGroup, secondaryMuscleGroups: [MuscleGroup], equipment: String?, source: Source) {
        self.muscleGroup = muscleGroup
        var seen: Set<MuscleGroup> = [muscleGroup]
        self.secondaryMuscleGroups = secondaryMuscleGroups.filter { seen.insert($0).inserted }
        self.equipment = equipment
        self.source = source
    }

    init(_ entry: ExerciseLibrary.Entry) {
        self.init(muscleGroup: entry.muscleGroup, secondaryMuscleGroups: entry.secondaryMuscleGroups, equipment: entry.equipment, source: .library)
    }

    /// The model's strict JSON (`ExerciseSuggester.schema`); nil when its primary group isn't
    /// one of Coar's. Unknown secondary groups are dropped.
    init?(reply: Data) {
        struct Reply: Decodable {
            let muscle_group: String
            let also_works: [String]
            let equipment: String
            let other_equipment: String
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: reply),
              let primary = MuscleGroup.named(reply.muscle_group) else { return nil }
        let equipment: String?
        switch reply.equipment {
        case "None": equipment = nil
        case "Other":
            let named = reply.other_equipment.trimmingCharacters(in: .whitespacesAndNewlines)
            equipment = named.isEmpty ? nil : named
        default: equipment = Equipment(rawValue: reply.equipment)?.rawValue
        }
        self.init(muscleGroup: primary, secondaryMuscleGroups: reply.also_works.compactMap(MuscleGroup.named), equipment: equipment, source: .ai)
    }

    /// Under the muscle groups, so the user knows to check.
    var note: String {
        switch source {
        case .library: return "Filled in from the library."
        case .ai: return "Filled in by AI from the name. Check it."
        }
    }
}

extension MuscleGroup {
    /// The group with this title ("Chest"), ignoring case.
    static func named(_ title: String) -> MuscleGroup? {
        allCases.first { $0.title.caseInsensitiveCompare(title) == .orderedSame }
    }
}

/// Suggests an Exercise's details from its name: the library's entry when the name is
/// exactly one (free, no network), otherwise the OpenRouter text model. Nil when neither can
/// say: no key, no connection, an unreadable reply. It is a help, so failures stay quiet
/// (logged) and the form works as it always has.
final class ExerciseSuggester {

    private static let logger = Logger(category: "Train")

    private let client: OpenRouterClient

    init(client: OpenRouterClient) {
        self.client = client
    }

    static let system = """
    You classify a strength exercise, given only its name as someone wrote it in their workout log.

    - muscle_group: the one muscle group doing most of the work.
    - also_works: up to three other groups it clearly works, most important first; never the muscle_group itself; [] if none.
    - equipment: what it is done with. "DB" means dumbbell, "BB" barbell, "KB" kettlebell. Bodyweight exercises (pull-ups, dips, push-ups, planks) are "Bodyweight". Use "None" only if it can't be told. Use "Other" for equipment not in the list, and name it in other_equipment ("Trap bar", "Landmine"); otherwise other_equipment is "".
    Traps and lower back count as Back; adductors as Other.
    """

    static let schema: [String: Any] = {
        let groups = MuscleGroup.allCases.map(\.title)
        let equipment = Equipment.allCases.map(\.rawValue) + ["None", "Other"]
        return [
            "type": "object",
            "additionalProperties": false,
            "required": ["muscle_group", "also_works", "equipment", "other_equipment"],
            "properties": [
                "muscle_group": ["type": "string", "enum": groups],
                "also_works": ["type": "array", "items": ["type": "string", "enum": groups]],
                "equipment": ["type": "string", "enum": equipment],
                "other_equipment": ["type": "string"],
            ],
        ]
    }()

    func suggest(for name: String) async -> ExerciseSuggestion? {
        if let entry = ExerciseLibrary.entry(named: name) {
            return ExerciseSuggestion(entry)
        }
        guard client.keys.read() != nil else { return nil }
        do {
            // The same cheap text model the Describe tab uses: one AI text model in Coar.
            let reply = try await client.complete(model: FoodModels.text, system: Self.system, user: [.text(name)], schema: (name: "exercise", json: Self.schema), timeout: 15)
            return ExerciseSuggestion(reply: Data(reply.utf8))
        } catch {
            Self.logger.info("No suggestion for an exercise: \(OpenRouterError.from(error).message, privacy: .public)")
            return nil
        }
    }
}
