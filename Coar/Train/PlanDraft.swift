import Foundation

/// A Plan as typed on its editor: a name and its rows in order (CONTEXT.md "Plan"). Keeps
/// the Superset rule (CONTEXT.md "Superset": adjacent rows, two or more, sharing a group) as
/// rows are linked, unlinked, reordered, and removed: groups are renumbered 1, 2, … in row
/// order and a row left on its own has none.
struct PlanDraft: Equatable {
    var name = ""
    var exercises: [PlanExerciseDraft] = []

    /// What a row starts with when an Exercise is added: three sets of 8–12 with no weight.
    static let defaultSets = Array(repeating: RepRange(min: 8, max: 12), count: 3)

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Saveable: a name and at least one Exercise.
    var isComplete: Bool {
        !trimmedName.isEmpty && !exercises.isEmpty
    }

    /// Adds an Exercise at the end with the default sets, on its own.
    mutating func append(exerciseID: ExerciseRecord.ID) {
        exercises.append(PlanExerciseDraft(
            exerciseID: exerciseID,
            supersetGroup: nil,
            sets: Self.defaultSets.map { PlannedSetDraft(targetKilograms: 0, reps: $0) }
        ))
    }

    /// Replaces the row with the same id, or appends a new one.
    mutating func upsert(_ exercise: PlanExerciseDraft) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
        } else {
            exercises.append(exercise)
        }
        setGroups(from: links)
    }

    mutating func remove(_ id: PlanExerciseDraft.ID) {
        exercises.removeAll { $0.id == id }
        setGroups(from: links)
    }

    /// Puts the rows in the given order; ids not listed keep their relative order after. A
    /// Superset member moved away from its group leaves it.
    mutating func reorder(_ ids: [PlanExerciseDraft.ID]) {
        exercises.reorder(ids)
        setGroups(from: links)
    }

    // MARK: Supersets

    /// Whether the row and the one below it are in one Superset.
    func isLinkedToNext(_ id: PlanExerciseDraft.ID) -> Bool {
        guard let index = exercises.firstIndex(where: { $0.id == id }), index + 1 < exercises.count,
              let group = exercises[index].supersetGroup
        else { return false }
        return exercises[index + 1].supersetGroup == group
    }

    /// Joins the row and the one below it into one Superset, or parts them if they are in
    /// one already. Nothing happens on the last row.
    mutating func toggleLink(below id: PlanExerciseDraft.ID) {
        guard let index = exercises.firstIndex(where: { $0.id == id }), index + 1 < exercises.count else { return }
        var links = links
        links[index].toggle()
        setGroups(from: links)
    }

    /// "A1", "A2" for the first Superset's rows, "B1", "B2" for the next; nil for a row on
    /// its own.
    func supersetLabel(for id: PlanExerciseDraft.ID) -> String? {
        guard let index = exercises.firstIndex(where: { $0.id == id }), let group = exercises[index].supersetGroup else { return nil }
        let letter = String(UnicodeScalar(UInt8(ascii: "A") + UInt8(clamping: min(max(group - 1, 0), 25))))
        let position = exercises[...index].filter { $0.supersetGroup == group }.count
        return "\(letter)\(position)"
    }

    /// One flag per boundary between adjacent rows: true where the two are in one Superset.
    private var links: [Bool] {
        exercises.dropLast().map { isLinkedToNext($0.id) }
    }

    /// Rewrites every row's group from the boundary links: each run of linked rows gets the
    /// next number in row order; a row linked to nothing has none.
    private mutating func setGroups(from links: [Bool]) {
        var nextGroup = 1
        for index in exercises.indices {
            let linkedAbove = index > 0 && links[index - 1]
            let linkedBelow = index < links.count && links[index]
            if linkedAbove {
                exercises[index].supersetGroup = exercises[index - 1].supersetGroup
            } else if linkedBelow {
                exercises[index].supersetGroup = nextGroup
                nextGroup += 1
            } else {
                exercises[index].supersetGroup = nil
            }
        }
    }
}
