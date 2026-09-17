import UIKit
import os

/// Home. Holds the Sleep | Steps squares (read live from Apple Health, never stored) until
/// ticket 14 builds the full layout around them. The avatar button opens Settings as a
/// sheet.
final class HomeViewController: ScreenViewController {

    private static let logger = Logger(category: "Home")

    private let dependencies: AppDependencies
    private let sleepSquare = HealthSquareControl(metric: .sleep)
    private let stepsSquare = HealthSquareControl(metric: .steps)
    private var loadTask: Task<Void, Never>?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(title: "Home")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let avatar = UIBarButtonItem(
            image: UIImage(systemName: "person.crop.circle"),
            primaryAction: UIAction { [weak self] _ in self?.presentSettings() }
        )
        avatar.accessibilityLabel = "Settings"
        navigationItem.rightBarButtonItem = avatar

        for square in [sleepSquare, stepsSquare] {
            square.onConnect = { [weak self] in self?.connectHealth() }
            square.addAction(UIAction { [weak self] _ in self?.showDetail(square.metric) }, for: .touchUpInside)
        }
        let grid = UIStackView(arrangedSubviews: [sleepSquare, stepsSquare])
        grid.axis = .horizontal
        grid.distribution = .fillEqually
        grid.spacing = Metrics.spaceCard
        contentStack.addArrangedSubview(grid)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    // MARK: - Apple Health

    private func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let today = Day.today()
            let status = await dependencies.health.status()
            let sleep = await read(.sleep, on: today)
            let steps = await read(.steps, on: today)
            guard !Task.isCancelled else { return }
            let canConnect = status == .notRequested
            sleepSquare.render(.init(value: sleep, canConnect: canConnect))
            stepsSquare.render(.init(value: steps, canConnect: canConnect))
        }
    }

    private func read(_ metric: HealthMetric, on day: Day) async -> Double? {
        do {
            return try await metric.read([day], from: dependencies.healthReader)[day]
        } catch {
            Self.logger.error("Failed to read \(metric.title, privacy: .public) from Apple Health: \(error, privacy: .public)")
            return nil
        }
    }

    private func connectHealth() {
        Task {
            do {
                try await dependencies.health.requestAccess()
            } catch {
                Self.logger.error("HealthKit authorisation failed: \(error, privacy: .public)")
            }
            load()
        }
    }

    // MARK: - Navigation

    private func showDetail(_ metric: HealthMetric) {
        navigationController?.pushViewController(HealthDetailViewController(dependencies: dependencies, metric: metric), animated: true)
    }

    private func presentSettings() {
        present(SettingsViewController.sheet(dependencies: dependencies), animated: true)
    }
}
