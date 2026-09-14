import UIKit

/// The four Liquid Glass tabs. Each tab owns a `UINavigationController` with large titles
/// (DESIGN.md §2). Screens receive the store façade; they never see a managed object context.
final class RootTabBarController: UITabBarController {

    let store: Store

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)

        tabs = [
            UITab(title: "Home", image: UIImage(systemName: "house.fill"), identifier: "home") { _ in
                Self.navigation(root: HomeViewController())
            },
            UITab(title: "Habits", image: UIImage(systemName: "checkmark.circle.fill"), identifier: "habits") { _ in
                Self.navigation(root: ScreenViewController(title: "Habits"))
            },
            UITab(title: "Food", image: UIImage(systemName: "fork.knife"), identifier: "food") { _ in
                Self.navigation(root: ScreenViewController(title: "Food"))
            },
            UITab(title: "Train", image: UIImage(systemName: "dumbbell.fill"), identifier: "train") { _ in
                Self.navigation(root: ScreenViewController(title: "Train"))
            },
        ]
        tabBarMinimizeBehavior = .onScrollDown
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static func navigation(root: UIViewController) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: root)
        navigation.navigationBar.prefersLargeTitles = true
        return navigation
    }
}
