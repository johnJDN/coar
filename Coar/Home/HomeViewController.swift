import UIKit
import os

/// Home (DESIGN.md §11): today's date as the title with a greeting under it, then the
/// habits card, the macros card, and a 2-column grid of squares, Sleep | Steps over Body
/// Weight | Last Workout. Everything is one `HomeSnapshot` read through the façade and
/// Apple Health on every appearance, after every check-in from here, and when the unit
/// changes; nothing is stored. Home is a launcher: the habits card opens the Habits tab,
/// the macros card opens Food on today, Sleep and Steps push their details here, and Body
/// Weight and Last Workout switch to Train and push their screens. The avatar button opens
/// Settings as a sheet.
final class HomeViewController: ScreenViewController {

    private static let logger = Logger(category: "Home")

    private let dependencies: AppDependencies
    private let habitsCard = HabitsCardControl()
    private let macrosCard = MacrosCardControl()
    private let sleepSquare = HomeSquareControl(metric: .sleep)
    private let stepsSquare = HomeSquareControl(metric: .steps)
    private let bodyWeightSquare = HomeSquareControl(title: "Body Weight", systemImage: "scalemass.fill", iconTint: UIColor.accentTeal)
    private let lastWorkoutSquare = HomeSquareControl(title: "Last Workout", systemImage: "dumbbell.fill", iconTint: UIColor.accentGreen)
    private var snapshot = HomeSnapshot.placeholder
    private var loadTask: Task<Void, Never>?
    private var unitObservation: MassUnitObservation?
    private var timeObserver: NSObjectProtocol?
    private var remoteObserver: NSObjectProtocol?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(title: HomeText.title(for: .today()))
    }

    deinit {
        for observer in [timeObserver, remoteObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let avatar = UIBarButtonItem(
            image: UIImage(systemName: "person.crop.circle"),
            primaryAction: UIAction { [weak self] _ in self?.presentSettings() }
        )
        avatar.accessibilityLabel = "Settings"
        navigationItem.rightBarButtonItem = avatar

        habitsCard.onToggle = { [weak self] id, done in self?.setCheckedIn(id, done: done) }
        habitsCard.onAmountTap = { [weak self] id in self?.presentAmount(id) }
        habitsCard.addAction(UIAction { [weak self] _ in self?.openHabits() }, for: .touchUpInside)
        macrosCard.onSetTargets = { [weak self] in self?.presentSettings() }
        macrosCard.addAction(UIAction { [weak self] _ in self?.openFood() }, for: .touchUpInside)
        for square in [sleepSquare, stepsSquare] {
            square.onTapEmpty = { [weak self] in self?.connectHealth() }
        }
        sleepSquare.addAction(UIAction { [weak self] _ in self?.showDetail(.sleep) }, for: .touchUpInside)
        stepsSquare.addAction(UIAction { [weak self] _ in self?.showDetail(.steps) }, for: .touchUpInside)
        bodyWeightSquare.addAction(UIAction { [weak self] _ in self?.openBodyWeight() }, for: .touchUpInside)
        lastWorkoutSquare.addAction(UIAction { [weak self] _ in self?.openLastWorkout() }, for: .touchUpInside)

        contentStack.addArrangedSubview(habitsCard)
        contentStack.addArrangedSubview(macrosCard)
        contentStack.addArrangedSubview(Self.gridRow(sleepSquare, stepsSquare))
        contentStack.addArrangedSubview(Self.gridRow(bodyWeightSquare, lastWorkoutSquare))

        unitObservation = dependencies.preferences.observeMassUnit { [weak self] in self?.load() }
        timeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateTitle()
                self?.load()
            }
        }
        remoteObserver = observeRemoteChanges { [weak self] in self?.load() }
        updateTitle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTitle()
        load()
    }

    private static func gridRow(_ leading: UIView, _ trailing: UIView) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [leading, trailing])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = Metrics.spaceCard
        return row
    }

    // MARK: - Rendering

    private func updateTitle() {
        title = HomeText.title(for: .today())
        navigationItem.subtitle = HomeText.greeting(at: Date())
    }

    private func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let status = await dependencies.health.status()
            let snapshot: HomeSnapshot
            do {
                snapshot = try await HomeSnapshot.load(
                    store: dependencies.store,
                    health: dependencies.healthReader,
                    healthStatus: status,
                    unit: dependencies.preferences.massUnit,
                    today: .today()
                )
            } catch {
                Self.logger.error("Failed to read Home: \(error, privacy: .public)")
                return
            }
            guard !Task.isCancelled else { return }
            render(snapshot)
        }
    }

    private func render(_ snapshot: HomeSnapshot) {
        self.snapshot = snapshot
        habitsCard.render(snapshot.habits)
        macrosCard.render(snapshot.macros)
        sleepSquare.render(snapshot.sleep)
        stepsSquare.render(snapshot.steps)
        bodyWeightSquare.render(snapshot.bodyWeight)
        lastWorkoutSquare.render(snapshot.lastWorkout)
    }

    // MARK: - Check-ins

    private func setCheckedIn(_ id: HabitRecord.ID, done: Bool) {
        do {
            try dependencies.store.setCheckedIn(id, on: .today(), done: done)
        } catch {
            Self.logger.error("Failed to write Check-in: \(error, privacy: .public)")
        }
        load()
    }

    private func presentAmount(_ id: HabitRecord.ID) {
        guard let sheet = HabitCheckInSheet.sheet(habitID: id, dependencies: dependencies, day: .today(), onChange: { [weak self] in self?.load() }) else { return }
        present(sheet, animated: true)
    }

    // MARK: - Apple Health

    private func connectHealth() {
        Task {
            await dependencies.health.connect()
            load()
        }
    }

    // MARK: - Navigation

    private var root: RootTabBarController? {
        tabBarController as? RootTabBarController
    }

    private func openHabits() {
        root?.select(.habits)?.popToRootViewController(animated: false)
    }

    private func openFood() {
        guard let navigation = root?.select(.food) else { return }
        navigation.popToRootViewController(animated: false)
        (navigation.viewControllers.first as? FoodViewController)?.showToday()
    }

    private func openBodyWeight() {
        openInTrain(BodyWeightViewController(dependencies: dependencies))
    }

    private func openLastWorkout() {
        guard let id = snapshot.lastWorkoutID else { return }
        do {
            guard let workout = try dependencies.store.workout(id) else { return load() }
            openInTrain(WorkoutScreens.screen(for: workout, dependencies: dependencies))
        } catch {
            Self.logger.error("Failed to read the last Workout: \(error, privacy: .public)")
        }
    }

    /// Switches to Train and pushes the screen over its root.
    private func openInTrain(_ screen: UIViewController) {
        guard let navigation = root?.select(.train) else { return }
        navigation.popToRootViewController(animated: false)
        navigation.pushViewController(screen, animated: true)
    }

    private func showDetail(_ metric: HealthMetric) {
        navigationController?.pushViewController(HealthDetailViewController(dependencies: dependencies, metric: metric), animated: true)
    }

    private func presentSettings() {
        // A page sheet leaves Home on screen, so Home reloads itself once Settings closes.
        present(SettingsViewController.sheet(dependencies: dependencies) { [weak self] in self?.load() }, animated: true)
    }
}
