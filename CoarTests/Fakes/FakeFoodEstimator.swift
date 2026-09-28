import Foundation
@testable import Coar

/// The model stands in behind `FoodEstimator`: a set reply per line, or a failure.
final class FakeFoodEstimator: FoodEstimator {

    var replies: [String: Result<Estimate, Error>] = [:]
    private(set) var sent: [String] = []

    func estimate(_ line: String) async throws -> Estimate {
        sent.append(line)
        guard let reply = replies[line] else { throw OpenRouterError.failed("no reply set for \(line)") }
        return try reply.get()
    }
}
