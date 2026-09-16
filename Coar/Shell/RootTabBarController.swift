import UIKit
import os

/// The four Liquid Glass tabs. Each tab owns a `UINavigationController` with large titles
/// (DESIGN.md §2). Screens receive their dependencies; they never see a managed object context.
/// Also owns the bottom accessory: while a Workout is active and the user is away from the
/// logger (another tab, or Train without the logger in its stack), the `ActiveWorkoutBar`
/// sits above the tab bar and taps back into the logger. On the first
/// appearance, an Active Workout older than `WorkoutRecord.staleAfter` is offered Finish or
/// Discard rather than carried on.
final class RootTabBarController: UITabBarController {

    private static let logger = Logger(category: "Shell")
    private static let trainTabIdentifier = "train"

    let dependencies: AppDependencies

    /// Set by the logger as it enters and leaves the Train tab's stack.
    var loggerIsInTrainStack = false {
        didSet { refreshAccessory() }
    }

    private let activeBar = ActiveWorkoutBar()
    private var activeObserver: NSObjectProtocol?
    private var hasCheckedStaleWorkout = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)

        tabs = [
            UITab(title: "Home", image: UIImage(systemName: "house.fill"), identifier: "home") { [dependencies] _ in
                Self.navigation(root: HomeViewController(dependencies: dependencies))
            },
            UITab(title: "Habits", image: UIImage(systemName: "checkmark.circle.fill"), identifier: "habits") { [dependencies] _ in
                Self.navigation(root: HabitsViewController(dependencies: dependencies))
            },
            UITab(title: "Food", image: UIImage(systemName: "fork.knife"), identifier: "food") { [dependencies] _ in
                Self.navigation(root: FoodViewController(dependencies: dependencies))
            },
            UITab(title: "Train", image: UIImage(systemName: "dumbbell.fill"), identifier: Self.trainTabIdentifier) { [dependencies] _ in
                Self.navigation(root: TrainViewController(dependencies: dependencies))
            },
        ]
        tabBarMinimizeBehavior = .onScrollDown
        delegate = self

        activeBar.onTap = { [weak self] in self?.showActiveWorkout() }
        activeObserver = NotificationCenter.default.addObserver(
            forName: Store.activeWorkoutDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccessory() }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshAccessory()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasCheckedStaleWorkout else { return }
        hasCheckedStaleWorkout = true
        checkStaleWorkout()
    }

    private static func navigation(root: UIViewController) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: root)
        navigation.navigationBar.prefersLargeTitles = true
        return navigation
    }

    // MARK: - Active Workout

    private func activeWorkout() -> WorkoutRecord? {
        do {
            return try dependencies.store.activeWorkout()
        } catch {
            Self.logger.error("Failed to read the Active Workout: \(error, privacy: .public)")
            return nil
        }
    }

    private var isOnTrainTab: Bool {
        selectedTab?.identifier == Self.trainTabIdentifier
    }

    private func refreshAccessory() {
        guard isViewLoaded else { return }
        if let active = activeWorkout(), !(isOnTrainTab && loggerIsInTrainStack) {
            activeBar.configure(with: active)
            if bottomAccessory == nil {
                setBottomAccessory(UITabAccessory(contentView: activeBar), animated: true)
            }
        } else if bottomAccessory != nil {
            activeBar.stop()
            setBottomAccessory(nil, animated: true)
        }
    }

    /// Switches to Train and returns to the logger: back to the one already in the stack,
    /// or a fresh push when there is none.
    private func showActiveWorkout() {
        guard let active = activeWorkout() else { return refreshAccessory() }
        selectedTab = tabs.first { $0.identifier == Self.trainTabIdentifier }
        guard let navigation = selectedViewController as? UINavigationController else { return }
        if let logger = navigation.viewControllers.first(where: { $0 is WorkoutLoggerViewController }) {
            navigation.popToViewController(logger, animated: true)
        } else {
            navigation.pushViewController(WorkoutLoggerViewController(dependencies: dependencies, workoutID: active.id), animated: true)
        }
        refreshAccessory()
    }

    /// An Active Workout left twelve hours or more: the app never guesses the numbers, so
    /// it asks. Finish keeps the sets that were completed; Discard deletes the Workout. With
    /// nothing completed there is nothing to keep, so only Discard (or leaving it) is offered,
    /// as the logger's own Finish does.
    private func checkStaleWorkout() {
        guard let active = activeWorkout(), active.isStale(at: Date()) else { return }
        let started = "started \(TrainText.dayText(active.day)) at \(TrainText.timeText(active.startedAt))"
        let hasCompletedSets = active.completedSetCount > 0
        let alert = UIAlertController(
            title: "Still working out?",
            message: hasCompletedSets
                ? "\(active.title), \(started), is still active. Finish keeps the sets you completed; Discard deletes it."
                : "\(active.title), \(started), is still active and no set was completed. Discard it, or keep it active?",
            preferredStyle: .alert
        )
        if hasCompletedSets {
            alert.addAction(UIAlertAction(title: "Finish", style: .default) { [weak self] _ in
                guard let self else { return }
                do {
                    try dependencies.store.finishWorkout(active.id)
                } catch {
                    Self.logger.error("Failed to finish the stale Workout: \(error, privacy: .public)")
                }
            })
        } else {
            alert.addAction(UIAlertAction(title: "Keep active", style: .cancel))
        }
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            guard let self else { return }
            do {
                try dependencies.store.discardWorkout(active.id)
            } catch {
                Self.logger.error("Failed to discard the stale Workout: \(error, privacy: .public)")
            }
        })
        present(alert, animated: true)
    }
}

extension RootTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?) {
        refreshAccessory()
    }
}
