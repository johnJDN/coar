import Foundation

/// Everything a screen needs from outside itself, handed down from the scene root. Screens
/// see the store façade (ADR 0002), device preferences, Apple Health access, and the rest
/// timer; never a managed object context, `UserDefaults`, or `HKHealthStore`.
struct AppDependencies {
    let store: Store
    let preferences: Preferences
    let health: HealthAccess
    let bodyWeightWriter: BodyWeightWriter
    /// The one rest timer, shared by the logger that starts it and the shell that shows it.
    let restTimer: RestTimer
}
