import HealthKit

/// What the user has let Coar do with Apple Health. HealthKit never reveals whether a read
/// was granted, only whether the prompt has been shown, so "connected" is the most the app
/// can know about sleep and steps; Body Weight sharing is the one permission it can see.
enum HealthAccessStatus: Equatable {
    /// HealthKit is not on this device (iPad, Mac).
    case unavailable
    /// The system prompt has not been shown yet.
    case notRequested
    /// The prompt has been shown and Body Weight sharing is on.
    case connected
    /// The prompt has been shown but Body Weight sharing was turned off in Health.
    case limited
}

/// The one authorisation flow every HealthKit feature shares: sleep and steps reads
/// (ticket 13) and the Body Weight write (ticket 03). Faked in tests.
protocol HealthAccess: AnyObject {
    func status() async -> HealthAccessStatus
    /// Shows the system prompt. HealthKit shows it once; later calls return at once.
    func requestAccess() async throws
}

final class HealthKitAccess: HealthAccess {

    static let readTypes: Set<HKObjectType> = [
        HKCategoryType(.sleepAnalysis),
        HKQuantityType(.stepCount),
    ]
    static let shareTypes: Set<HKSampleType> = [
        HKQuantityType(.bodyMass),
    ]

    private let healthStore = HKHealthStore()

    func status() async -> HealthAccessStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let request = try? await healthStore.statusForAuthorizationRequest(toShare: Self.shareTypes, read: Self.readTypes)
        guard request == .unnecessary else { return .notRequested }
        let sharing = healthStore.authorizationStatus(for: HKQuantityType(.bodyMass))
        return sharing == .sharingDenied ? .limited : .connected
    }

    func requestAccess() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await healthStore.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
    }
}
