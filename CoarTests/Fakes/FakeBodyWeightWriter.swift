import Foundation
@testable import Coar

/// Apple Health stands in behind its writer protocol: records what would have been written,
/// or fails on demand.
final class FakeBodyWeightWriter: BodyWeightWriter {

    struct Sample: Equatable {
        let kilograms: Double
        let day: Day
    }

    private(set) var samples: [Sample] = []
    var failure: Error?

    func writeBodyWeight(kilograms: Double, on day: Day) async throws {
        if let failure { throw failure }
        samples.append(Sample(kilograms: kilograms, day: day))
    }
}
