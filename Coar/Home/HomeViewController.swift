import UIKit
import os

/// Home (DESIGN.md §11): today's date as the title with a greeting under it, then the
/// macros card, the habits card, and a row of four small tiles: Sleep, Steps, Weight, and
/// Training. Everything is one `HomeSnapshot` read through the façade and Apple Health on
/// every appearance, after every check-in from here, and when the unit changes; nothing is
/// stored. Home is a launcher: the macros card opens Food on today, the habits card opens
/// the Habits tab, Sleep and Steps push their details here, Weight switches to Train and
/// pushes Body Weight, and Training switches to Train. The avatar button opens Settings as a
/// sheet.
final class HomeViewController: ScreenViewController {

    private static let logger = Logger(category: "Home")

    private let dependencies: AppDependencies
    private let habitsCard = HabitsCardControl()
    private let macrosCard = MacrosCardControl()
    private let sleepTile = HomeTileControl(name: HealthMetric.sleep.title, systemImage: "moon.fill", accent: HealthMetric.sleep.uiAccent)
    private let stepsTile = HomeTileControl(name: HealthMetric.steps.title, systemImage: HealthMetric.steps.systemImage, accent: HealthMetric.steps.uiAccent)
    private let bodyWeightTile = HomeTileControl(name: "Weight", systemImage: "scalemass.fill", accent: UIColor.accentTeal)
    private let trainingTile = HomeTileControl(name: "Workouts", systemImage: "dumbbell.fill", accent: UIColor.accentGreen)
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
        for (tile, metric) in [(sleepTile, HealthMetric.sleep), (stepsTile, .steps)] {
            tile.addAction(UIAction { [weak self, weak tile] _ in
                if tile?.connects == true { self?.connectHealth() } else { self?.showDetail(metric) }
            }, for: .touchUpInside)
        }
        bodyWeightTile.addAction(UIAction { [weak self] _ in self?.openBodyWeight() }, for: .touchUpInside)
        trainingTile.addAction(UIAction { [weak self] _ in self?.openTrain() }, for: .touchUpInside)

        contentStack.addArrangedSubview(macrosCard)
        contentStack.addArrangedSubview(habitsCard)
        contentStack.addArrangedSubview(Self.tileRow([sleepTile, stepsTile, bodyWeightTile, trainingTile]))

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

    private static func tileRow(_ tiles: [UIView]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: tiles)
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = Metrics.spaceTight
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
        habitsCard.render(snapshot.habits)
        macrosCard.render(snapshot.macros)
        sleepTile.render(snapshot.sleep)
        stepsTile.render(snapshot.steps)
        bodyWeightTile.render(snapshot.bodyWeight)
        trainingTile.render(snapshot.training)
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

    private func openTrain() {
        root?.select(.train)?.popToRootViewController(animated: false)
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
