import Foundation

/// Everything a screen needs from outside itself, handed down from the scene root. Screens
/// see the store façade (ADR 0002), device preferences, Apple Health access, and the rest
/// timer, and OpenRouter; never a managed object context, `UserDefaults`, `HKHealthStore`,
/// or the Keychain.
struct AppDependencies {
    let store: Store
    let preferences: Preferences
    let health: HealthAccess
    let healthReader: HealthReader
    let bodyWeightWriter: BodyWeightWriter
    /// The one rest timer, shared by the logger that starts it and the shell that shows it.
    let restTimer: RestTimer
    /// AI requests and the key they use (ADR 0007).
    let openRouter: OpenRouterClient
}
