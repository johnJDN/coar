import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// The single store façade for the process. Loaded once at launch so CloudKit mirroring
    /// starts before any screen asks for data. The unit-test host gets an in-memory store so
    /// tests never touch CloudKit or the on-device database.
    let store = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        ? Store.live()
        : Store.inMemory()

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
