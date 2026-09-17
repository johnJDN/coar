import HealthKit
import os

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

extension HealthAccess {
    private static var logger: Logger { Logger(category: "Health") }

    /// Shows the system prompt from a screen: a failure is logged, never surfaced, because
    /// the screen re-reads Health either way and shows what it finds.
    func connect() async {
        do {
            try await requestAccess()
        } catch {
            Self.logger.error("HealthKit authorisation failed: \(error, privacy: .public)")
        }
    }
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

// MARK: - Sleep and steps read

extension HealthKitAccess: HealthReader {

    /// Every sleep sample touching the nights that end on `days`, reduced per wake Day by
    /// `SleepNight`. A read HealthKit has not been allowed simply returns no samples.
    func timeAsleep(wakingOn days: [Day]) async throws -> [Day: TimeInterval] {
        guard HKHealthStore.isHealthDataAvailable(), let first = days.min(), let last = days.max() else { return [:] }
        let calendar = Calendar.current
        let start = SleepNight.window(wakingOn: first, in: calendar).lowerBound
        let end = SleepNight.window(wakingOn: last, in: calendar).upperBound
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: HKQuery.predicateForSamples(withStart: start, end: end))],
            sortDescriptors: []
        )
        let samples = try await descriptor.result(for: healthStore).compactMap(SleepSample.init)
        return SleepNight.timeAsleep(wakingOn: days, from: samples, in: calendar)
    }

    /// The step sum per Day, from HealthKit's own statistics so a watch and a phone that
    /// both counted the same walk are not added twice.
    func steps(on days: [Day]) async throws -> [Day: Int] {
        guard HKHealthStore.isHealthDataAvailable(), let first = days.min(), let last = days.max() else { return [:] }
        let calendar = Calendar.current
        let start = first.start(in: calendar)
        let end = last.advanced(by: 1).start(in: calendar)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: healthStore)
        let wanted = Set(days)
        var result: [Day: Int] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            guard let sum = statistics.sumQuantity() else { return }
            let day = Day(statistics.startDate, in: calendar)
            guard wanted.contains(day) else { return }
            result[day] = Int(sum.doubleValue(for: .count()).rounded())
        }
        return result
    }
}

private extension SleepSample {
    /// A HealthKit sleep-analysis sample as the rule sees it; nil for a value this build
    /// does not know.
    init?(_ sample: HKCategorySample) {
        let stage: Stage
        switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
        case .inBed: stage = .inBed
        case .awake: stage = .awake
        case .asleepUnspecified: stage = .asleepUnspecified
        case .asleepCore: stage = .asleepCore
        case .asleepDeep: stage = .asleepDeep
        case .asleepREM: stage = .asleepREM
        default: return nil
        }
        self.init(start: sample.startDate, end: sample.endDate, stage: stage)
    }
}
