import Foundation
@testable import Coar

/// The model stands in behind `FoodEstimator`: a set reply per line, or a failure.
final class FakeFoodEstimator: FoodEstimator {

    var replies: [String: Result<Estimate, Error>] = [:]
    private(set) var sent: [String] = []
    private(set) var libraries: [FoodLibrary] = []
    var photoReply: Result<[Estimate], Error> = .success([])
    private(set) var photosSent: [Data] = []

    func estimate(photo jpeg: Data, library: FoodLibrary) async throws -> [Estimate] {
        photosSent.append(jpeg)
        return try photoReply.get()
    }

    func estimate(_ line: String, library: FoodLibrary) async throws -> Estimate {
        sent.append(line)
        libraries.append(library)
        guard let reply = replies[line] else { throw OpenRouterError.failed("no reply set for \(line)") }
        return try reply.get()
    }
}
