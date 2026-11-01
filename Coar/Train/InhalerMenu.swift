import UIKit
import os

/// "Used inhaler before" in a Workout's `…` menu, ticked while it is set: a record for the
/// user, kept on the Workout (CONTEXT.md "Workout note"). Read afresh each time the menu
/// opens, so it never shows a stale tick.
enum InhalerMenu {

    private static let logger = Logger(category: "Train")

    static func item(store: Store, workoutID: WorkoutRecord.ID, onChange: @escaping () -> Void) -> UIMenuElement {
        UIDeferredMenuElement.uncached { completion in
            let used = (try? store.workout(workoutID))?.usedInhaler ?? false
            let action = UIAction(title: "Used inhaler before", image: UIImage(systemName: "lungs.fill"), state: used ? .on : .off) { _ in
                do {
                    try store.setUsedInhaler(!used, on: workoutID)
                } catch {
                    logger.error("Failed to save inhaler: \(error, privacy: .public)")
                    return
                }
                onChange()
            }
            completion([action])
        }
    }

    /// "Inhaler", for joining onto a Workout's subtitle; nil when it wasn't used.
    static func text(_ workout: WorkoutRecord) -> String? {
        workout.usedInhaler ? "Inhaler" : nil
    }
}
