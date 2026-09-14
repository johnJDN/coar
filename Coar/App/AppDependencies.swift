import Foundation

/// Everything a screen needs from outside itself, handed down from the scene root. Screens
/// see the store façade (ADR 0002), device preferences, and Apple Health access; never a
/// managed object context, `UserDefaults`, or `HKHealthStore`.
struct AppDependencies {
    let store: Store
    let preferences: Preferences
    let health: HealthAccess
}
