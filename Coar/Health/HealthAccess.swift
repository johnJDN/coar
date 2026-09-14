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

// MARK: - Body Weight write

/// The one Apple Health writer: a Body Weight as a body-mass sample. Write-only in v1;
/// nothing is read back (ADR 0002). Faked in tests.
protocol BodyWeightWriter: AnyObject {
    func writeBodyWeight(kilograms: Double, on day: Day) async throws
}

extension HealthKitAccess: BodyWeightWriter {

    /// Replaces whatever Coar wrote for that Day, so Health agrees with "one Body Weight
    /// per Day". A Body Weight logged today is stamped now; an earlier Day gets noon. Shows
    /// the system prompt first if it has never been shown.
    func writeBodyWeight(kilograms: Double, on day: Day) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if try await healthStore.statusForAuthorizationRequest(toShare: Self.shareTypes, read: Self.readTypes) == .shouldRequest {
            try await requestAccess()
        }

        let type = HKQuantityType(.bodyMass)
        let calendar = Calendar.current
        let start = day.start(in: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let thatDay = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        _ = try await healthStore.deleteObjects(of: type, predicate: thatDay)

        let now = Date()
        let instant = (start..<end).contains(now) ? now : calendar.date(bySettingHour: 12, minute: 0, second: 0, of: start)!
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms)
        try await healthStore.save(HKQuantitySample(type: type, quantity: quantity, start: instant, end: instant))
    }
}
