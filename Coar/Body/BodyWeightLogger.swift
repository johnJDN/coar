import Foundation
import os

/// The one way a Body Weight is logged: the value comes in the display unit, is stored in
/// kilograms (ADR 0004) for the Day it was logged on (ADR 0005), and is written to Apple
/// Health. Health is a mirror, never the record: a failed write is logged and the Body
/// Weight stands.
@MainActor
struct BodyWeightLogger {

    private static let logger = Logger(category: "BodyWeight")

    let store: Store
    let healthWriter: BodyWeightWriter

    func log(_ value: Double, in unit: MassUnit, on day: Day = .today()) async throws {
        let kilograms = unit.kilograms(fromDisplayValue: value)
        try store.logBodyWeight(kilograms: kilograms, on: day)
        do {
            try await healthWriter.writeBodyWeight(kilograms: kilograms, on: day)
        } catch {
            Self.logger.error("Failed to write Body Weight to Apple Health: \(error, privacy: .public)")
        }
    }
}
