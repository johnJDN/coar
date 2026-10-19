import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootTabBarController(dependencies: appDelegate.dependencies)
        window.makeKeyAndVisible()
        self.window = window
        appDelegate.dependencies.reminder?.onOpen = { [weak self] in self?.openToday() }
    }

    /// The reminder was tapped: Home, then today's Day page.
    private func openToday() {
        guard let root = window?.rootViewController as? RootTabBarController,
              let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let navigation = root.select(.home) else { return }
        navigation.popToRootViewController(animated: false)
        navigation.pushViewController(DayViewController(dependencies: appDelegate.dependencies, day: .today()), animated: true)
    }

    /// Leaving Coar re-plans the reminders, so tonight's goes once the day is logged.
    func sceneWillResignActive(_ scene: UIScene) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        Task { await appDelegate.dependencies.reminder?.refresh() }
    }

    /// Each time Coar comes forward: today's place (once a Day) and new journal entries.
    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        Task {
            await appDelegate.dependencies.reminder?.refresh()
            await appDelegate.dependencies.places?.recordToday()
            await appDelegate.dependencies.journal?.run()
        }
    }
}
