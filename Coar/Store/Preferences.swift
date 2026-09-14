import Foundation

/// Device preferences that are not records: today only the mass unit (ADR 0004). Backed by
/// `UserDefaults`; the unit is display-only, so it need not sync. Screens that show a mass
/// observe `massUnitDidChange` and re-render, so a toggle in Settings reaches every
/// displayed weight at once.
final class Preferences {

    /// Posted synchronously from the setter, with the `Preferences` instance as the object.
    static let massUnitDidChange = Notification.Name("Preferences.massUnitDidChange")

    private static let massUnitKey = "massUnit"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var massUnit: MassUnit {
        get {
            defaults.string(forKey: Self.massUnitKey).flatMap(MassUnit.init(rawValue:)) ?? .pounds
        }
        set {
            guard newValue != massUnit else { return }
            defaults.set(newValue.rawValue, forKey: Self.massUnitKey)
            NotificationCenter.default.post(name: Self.massUnitDidChange, object: self)
        }
    }
}
