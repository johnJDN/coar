import Foundation

/// Weights, set schemes, and captions as the Train screens show them.
enum TrainText {

    /// "135" / "22.5": a stored weight in the display unit, whole when it is whole (ADR 0004).
    static func weightValue(_ kilograms: Double, in unit: MassUnit) -> String {
        unit.displayValue(fromKilograms: kilograms).formatted(.number.precision(.fractionLength(0...1)))
    }

    /// "135 lbs" / "22.5 kg"; `—` when no weight is lifted.
    static func weight(_ kilograms: Double, in unit: MassUnit) -> String {
        guard kilograms > 0 else { return "—" }
        return "\(weightValue(kilograms, in: unit)) \(unit.symbol)"
    }

    /// "257 lbs": an Estimated 1RM in the display unit, whole, since it is an estimate.
    static func estimatedOneRepMax(_ kilograms: Double, in unit: MassUnit) -> String {
        "\(unit.displayValue(fromKilograms: kilograms).formatted(.number.precision(.fractionLength(0)))) \(unit.symbol)"
    }

    /// The scheme of a row's Planned Sets: "3 × 8–12 · 135 lbs" when every set is the same
    /// (the weight left off when there is none), "3 sets" when they differ, "No sets".
    static func scheme(of sets: [PlannedSetDraft], in unit: MassUnit) -> String {
        guard let first = sets.first else { return "No sets" }
        let uniform = sets.allSatisfy { $0.reps == first.reps && $0.targetKilograms == first.targetKilograms }
        guard uniform else { return count(sets.count, "set") }
        let scheme = "\(sets.count) × \(first.reps.text)"
        return first.targetKilograms > 0 ? "\(scheme) · \(weight(first.targetKilograms, in: unit))" : scheme
    }

    /// "Chest + Triceps, Shoulders · Barbell · Rest 150 s": what the catalogue says under an
    /// Exercise's name.
    static func details(of exercise: ExerciseRecord) -> String {
        let muscles = exercise.secondaryMuscleGroups.isEmpty
            ? exercise.muscleGroup.title
            : "\(exercise.muscleGroup.title) + \(exercise.secondaryMuscleGroups.map(\.title).joined(separator: ", "))"
        return [muscles, exercise.equipment, exercise.restSeconds.map(rest)].compactMap { $0 }.joined(separator: " · ")
    }

    /// "Rest 150 s".
    static func rest(_ seconds: Int) -> String {
        "Rest \(seconds) s"
    }

    /// "1 exercise" / "3 exercises".
    static func count(_ count: Int, _ noun: String) -> String {
        "\(count) \(count == 1 ? noun : noun + "s")"
    }

    // MARK: Workouts

    /// "135 lbs × 5": a Logged Set as history shows it; `—` for the weight when none was lifted.
    static func setLine(_ set: LoggedSetRecord, in unit: MassUnit) -> String {
        "\(weight(set.kilograms, in: unit)) × \(set.reps)"
    }

    /// "Sep 10 · 3 exercises · 12 sets": what a Workout card says under its title.
    static func caption(of workout: WorkoutRecord) -> String {
        let sets = workout.exercises.reduce(0) { $0 + $1.sets.count }
        return [workout.day.shortText, count(workout.exercises.count, "exercise"), count(sets, "set")].joined(separator: " · ")
    }

    /// "6:12 PM".
    static func timeText(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    /// "1:42" / "0:05": a rest countdown.
    static func countdown(_ seconds: Int) -> String {
        let clamped = Swift.max(0, seconds)
        return "\(clamped / 60):\(String(format: "%02d", clamped % 60))"
    }

    /// "42 min" / "1 h 12 min": how long a Workout has run or ran.
    static func duration(from start: Date, to end: Date) -> String {
        let minutes = Swift.max(0, Int(end.timeIntervalSince(start) / 60))
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }
}
