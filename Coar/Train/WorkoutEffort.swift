import UIKit

/// A linked Workout's effort as the lists show it (CONTEXT.md "Effort"): "320 cal · 118 bpm",
/// read live from Apple Health for the Health Workouts the visible Workouts are linked to,
/// in one query. A Workout with no link, or whose Health Workout Health no longer holds or
/// may not be read, has none.
enum WorkoutEffort {

    static func texts(for workouts: [WorkoutRecord], reader: HealthWorkoutReader) async -> [WorkoutRecord.ID: String] {
        let links = workouts.compactMap { workout in workout.healthWorkoutID.map { (workout.id, $0) } }
        guard !links.isEmpty, let found = try? await reader.healthWorkouts(withIDs: links.map(\.1)) else { return [:] }
        return Dictionary(links.compactMap { id, link in found[link]?.effortText.map { (id, $0) } }, uniquingKeysWith: { first, _ in first })
    }

    /// The effort as one line: a flame in the calories amber, then the numbers.
    static func line(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if let flame = UIImage(systemName: "flame.fill", withConfiguration: UIImage.SymbolConfiguration(font: UIFont.label))?
            .withTintColor(UIColor.accentAmber, renderingMode: .alwaysOriginal) {
            result.append(NSAttributedString(attachment: NSTextAttachment(image: flame)))
            result.append(NSAttributedString(string: " "))
        }
        result.append(NSAttributedString(string: text, attributes: [.font: UIFont.label, .foregroundColor: UIColor.textSecondary]))
        return result
    }
}
