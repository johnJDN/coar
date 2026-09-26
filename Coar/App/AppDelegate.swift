import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// The process's single store façade, preferences, and Health access. The store loads
    /// once at launch so CloudKit mirroring starts before any screen asks for data. The
    /// unit-test host gets an in-memory store so tests never touch CloudKit or the on-device
    /// database.
    let dependencies: AppDependencies = {
        let health = HealthKitAccess()
        return AppDependencies(
            store: isTestHost ? Store.inMemory() : AppDelegate.liveStore(),
            preferences: Preferences(),
            health: health,
            healthReader: health,
            bodyWeightWriter: health,
            restTimer: RestTimer()
        )
    }()

    /// Heals the duplicates two devices can make (ticket 15): once at launch, then after
    /// every remote-change import. Not in the unit-test host, whose store never syncs.
    private var syncDedupe: SyncDedupeRunner?

    private static let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// The on-device store, or the sample-data store a debug build was launched with.
    private static func liveStore() -> Store {
        #if DEBUG
        if DebugSeed.isRequested { return DebugSeed.store() }
        #endif
        return Store.live()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NumberFieldBehavior.install()
        if !Self.isTestHost {
            let runner = SyncDedupeRunner(store: dependencies.store)
            runner.start()
            syncDedupe = runner
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
