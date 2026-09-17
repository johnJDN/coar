import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// The process's single store façade, preferences, and Health access. The store loads
    /// once at launch so CloudKit mirroring starts before any screen asks for data. The
    /// unit-test host gets an in-memory store so tests never touch CloudKit or the on-device
    /// database.
    let dependencies: AppDependencies = {
        let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let health = HealthKitAccess()
        return AppDependencies(
            store: isTestHost ? Store.inMemory() : Store.live(),
            preferences: Preferences(),
            health: health,
            bodyWeightWriter: health,
            restTimer: RestTimer()
        )
    }()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
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
