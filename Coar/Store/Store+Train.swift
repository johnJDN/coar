import CoreData

/// The façade's Train catalogue surface: Exercises, and Plans with their Planned Sets.
extension Store {

    // MARK: - Exercises

    /// Creates an Exercise. Blank equipment is stored as none.
    @discardableResult
    func createExercise(name: String, muscleGroup: MuscleGroup, equipment: String? = nil, restSeconds: Int? = nil) throws -> ExerciseRecord {
        let exercise = Exercise(context: context)
        exercise.id = UUID()
        exercise.isArchived = false
        try write(name: name, muscleGroup: muscleGroup, equipment: equipment, restSeconds: restSeconds, to: exercise)
        return ExerciseRecord(exercise)!
    }

    /// Replaces the Exercise's details. Plans read the catalogue live, so they show the
    /// change at once; Workouts keep their own copy (ADR 0003).
    func updateExercise(_ id: ExerciseRecord.ID, name: String, muscleGroup: MuscleGroup, equipment: String?, restSeconds: Int?) throws {
        guard let exercise = try fetchExercise(id) else { return }
        try write(name: name, muscleGroup: muscleGroup, equipment: equipment, restSeconds: restSeconds, to: exercise)
    }

    /// Active Exercises by name: what the catalogue and the Plan editor's picker list.
    func exercises() throws -> [ExerciseRecord] {
        try fetchExercises(archived: false)
    }

    /// Archived Exercises by name.
    func archivedExercises() throws -> [ExerciseRecord] {
        try fetchExercises(archived: true)
    }

    func exercise(_ id: ExerciseRecord.ID) throws -> ExerciseRecord? {
        try fetchExercise(id).flatMap(ExerciseRecord.init)
    }

    /// Hides the Exercise from the picker; the Plans and Workouts that use it keep it
    /// (CONTEXT.md "Archived").
    func archiveExercise(_ id: ExerciseRecord.ID) throws {
        try fetchExercise(id)?.isArchived = true
        try save()
    }

    func restoreExercise(_ id: ExerciseRecord.ID) throws {
        try fetchExercise(id)?.isArchived = false
        try save()
    }

    // MARK: - Plans

    /// Creates a Plan with its rows and their Planned Sets in the given order.
    @discardableResult
    func createPlan(name: String, exercises: [PlanExerciseDraft]) throws -> PlanRecord {
        let plan = Plan(context: context)
        plan.id = UUID()
        plan.isArchived = false
        try write(name: name, exercises: exercises, to: plan)
        return PlanRecord(plan)!
    }

    /// Replaces the Plan's name and rows: drafts carrying an existing row's or set's `id`
    /// update it in place, new ids insert, and rows and sets left out are removed. Workouts
    /// started before keep their own copy of everything (ADR 0003).
    func updatePlan(_ id: PlanRecord.ID, name: String, exercises: [PlanExerciseDraft]) throws {
        guard let plan = try fetchPlan(id) else { return }
        try write(name: name, exercises: exercises, to: plan)
    }

    /// Active Plans by name: the Train root's Plans section.
    func plans() throws -> [PlanRecord] {
        try fetchPlans(archived: false)
    }

    /// Archived Plans by name.
    func archivedPlans() throws -> [PlanRecord] {
        try fetchPlans(archived: true)
    }

    func plan(_ id: PlanRecord.ID) throws -> PlanRecord? {
        try fetchPlan(id).flatMap(PlanRecord.init)
    }

    /// Hides the Plan from the Plans section; its Workouts stay (CONTEXT.md "Archived").
    func archivePlan(_ id: PlanRecord.ID) throws {
        try fetchPlan(id)?.isArchived = true
        try save()
    }

    func restorePlan(_ id: PlanRecord.ID) throws {
        try fetchPlan(id)?.isArchived = false
        try save()
    }

    // MARK: - Writes

    private func write(name: String, muscleGroup: MuscleGroup, equipment: String?, restSeconds: Int?, to exercise: Exercise) throws {
        exercise.name = name
        exercise.muscleGroup = muscleGroup.rawValue
        let trimmedEquipment = equipment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        exercise.equipment = trimmedEquipment.isEmpty ? nil : trimmedEquipment
        exercise.restSeconds = restSeconds.map { NSNumber(value: $0) }
        try save()
    }

    private func write(name: String, exercises drafts: [PlanExerciseDraft], to plan: Plan) throws {
        plan.name = name
        let existingRows = reconcile(plan.exerciseObjects, keeping: Set(drafts.map(\.id)), id: \.id)
        for (position, draft) in drafts.enumerated() {
            let row = existingRows[draft.id] ?? PlanExercise(context: context)
            row.id = draft.id
            row.sortOrder = Int32(position)
            row.supersetGroup = draft.supersetGroup.map { NSNumber(value: $0) }
            row.exercise = try fetchExercise(draft.exerciseID)
            row.plan = plan
            let existingSets = reconcile(row.plannedSetObjects, keeping: Set(draft.sets.map(\.id)), id: \.id)
            for (setPosition, setDraft) in draft.sets.enumerated() {
                let set = existingSets[setDraft.id] ?? PlannedSet(context: context)
                set.id = setDraft.id
                set.sortOrder = Int32(setPosition)
                set.targetKilograms = setDraft.targetKilograms
                set.repMin = Int32(setDraft.reps.min)
                set.repMax = Int32(setDraft.reps.max)
                set.planExercise = row
            }
        }
        try save()
    }

    // MARK: - Fetches

    private func fetchExercises(archived: Bool) throws -> [ExerciseRecord] {
        let request = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == %@", NSNumber(value: archived))
        return try context.fetch(request).compactMap(ExerciseRecord.init)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func fetchExercise(_ id: ExerciseRecord.ID) throws -> Exercise? {
        let request = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchPlans(archived: Bool) throws -> [PlanRecord] {
        let request = Plan.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == %@", NSNumber(value: archived))
        return try context.fetch(request).compactMap(PlanRecord.init)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func fetchPlan(_ id: PlanRecord.ID) throws -> Plan? {
        let request = Plan.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

extension ExerciseRecord {
    init?(_ object: Exercise) {
        guard let id = object.id, let modifiedAt = object.modifiedAt,
              let muscleGroup = MuscleGroup(rawValue: object.muscleGroup)
        else { return nil }
        self.init(
            id: id,
            name: object.name ?? "",
            muscleGroup: muscleGroup,
            equipment: object.equipment,
            restSeconds: object.restSeconds?.intValue,
            isArchived: object.isArchived,
            modifiedAt: modifiedAt
        )
    }
}

private extension PlanRecord {
    init?(_ object: Plan) {
        guard let id = object.id, let modifiedAt = object.modifiedAt else { return nil }
        self.init(
            id: id,
            name: object.name ?? "",
            isArchived: object.isArchived,
            exercises: object.exerciseRecords,
            modifiedAt: modifiedAt
        )
    }
}

extension Plan {
    var exerciseObjects: [PlanExercise] {
        Array(exercises as? Set<PlanExercise> ?? [])
    }

    /// The rows in the user's order. A row whose Exercise is gone is dropped.
    var exerciseRecords: [PlanExerciseRecord] {
        exerciseObjects
            .sorted(by: Store.bySortOrder)
            .compactMap { row in
                guard let id = row.id, let exercise = row.exercise.flatMap(ExerciseRecord.init) else { return nil }
                return PlanExerciseRecord(
                    id: id,
                    exercise: exercise,
                    supersetGroup: row.supersetGroup?.intValue,
                    sets: row.plannedSetRecords
                )
            }
    }
}

extension PlanExercise {
    var plannedSetObjects: [PlannedSet] {
        Array(plannedSets as? Set<PlannedSet> ?? [])
    }

    /// The Planned Sets in the user's order.
    var plannedSetRecords: [PlannedSetRecord] {
        plannedSetObjects
            .sorted(by: Store.bySortOrder)
            .compactMap { set in
                guard let id = set.id else { return nil }
                return PlannedSetRecord(id: id, targetKilograms: set.targetKilograms, reps: RepRange(min: Int(set.repMin), max: Int(set.repMax)))
            }
    }
}
