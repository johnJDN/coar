import Foundation

/// Weights, set schemes, and captions as the Train screens show them.
enum TrainText {

    /// "135" / "22.5": a stored weight in the display unit, whole when it is whole (ADR 0004).
    static func weightValue(_ kilograms: Double, in unit: MassUnit) -> String {
        unit.displayValue(fromKilograms: kilograms).formatted(.number.precision(.fractionLength(0...1)))
    }

    /// "135 lbs" / "22.5 kg"; `—` for no weight (a bodyweight movement).
    static func weight(_ kilograms: Double, in unit: MassUnit) -> String {
        guard kilograms > 0 else { return "—" }
        return "\(weightValue(kilograms, in: unit)) \(unit.symbol)"
    }

    /// The scheme of a row's Planned Sets: "3 × 8–12 · 135 lbs" when every set is the same
    /// (the weight left off when there is none), "3 sets" when they differ, "No sets".
    static func sets(_ sets: [PlannedSetDraft], in unit: MassUnit) -> String {
        guard let first = sets.first else { return "No sets" }
        let uniform = sets.allSatisfy { $0.reps == first.reps && $0.targetKilograms == first.targetKilograms }
        guard uniform else { return count(sets.count, "set") }
        let scheme = "\(sets.count) × \(first.reps.text)"
        return first.targetKilograms > 0 ? "\(scheme) · \(weight(first.targetKilograms, in: unit))" : scheme
    }

    /// "Chest · Barbell · Rest 150 s": what the catalogue says under an Exercise's name.
    static func details(of exercise: ExerciseRecord) -> String {
        [exercise.muscleGroup.title, exercise.equipment, exercise.restSeconds.map(rest)].compactMap { $0 }.joined(separator: " · ")
    }

    /// "Rest 150 s".
    static func rest(_ seconds: Int) -> String {
        "Rest \(seconds) s"
    }

    /// "1 exercise" / "3 exercises".
    static func count(_ count: Int, _ noun: String) -> String {
        "\(count) \(count == 1 ? noun : noun + "s")"
    }

    /// The number a field holds, read in the user's locale ("22,5" as well as "22.5"); nil
    /// when the text is not a finite number.
    static func number(typed text: String) -> Double? {
        let value = parser.number(from: text)?.doubleValue ?? Double(text)
        return value.flatMap { $0.isFinite ? $0 : nil }
    }

    private static let parser: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        return formatter
    }()
}
