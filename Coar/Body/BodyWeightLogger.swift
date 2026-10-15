import Foundation
import os

/// The one way a Body Weight is logged or removed: the value comes in the display unit, is
/// stored in kilograms (ADR 0004) for the Day it was logged on (ADR 0005), and is written to
/// Apple Health. Health is a mirror, never the record: a failed write is logged and the Body
/// Weight stands (or stays gone).
@MainActor
struct BodyWeightLogger {

    private static let logger = Logger(category: "BodyWeight")

    let store: Store
    let healthWriter: BodyWeightWriter

    /// `stored` runs once the record is saved, before Apple Health is written: the first
    /// write may wait on the Health prompt, and a screen shouldn't wait with it.
    func log(_ value: Double, in unit: MassUnit, on day: Day = .today(), stored: () -> Void = {}) async throws {
        let kilograms = unit.kilograms(fromDisplayValue: value)
        try store.logBodyWeight(kilograms: kilograms, on: day)
        stored()
        do {
            try await healthWriter.writeBodyWeight(kilograms: kilograms, on: day)
        } catch {
            Self.logger.error("Failed to write Body Weight to Apple Health: \(error, privacy: .public)")
        }
    }

    func delete(on day: Day) async throws {
        try store.deleteBodyWeight(on: day)
        do {
            try await healthWriter.deleteBodyWeight(on: day)
        } catch {
            Self.logger.error("Failed to remove Body Weight from Apple Health: \(error, privacy: .public)")
        }
    }
}
