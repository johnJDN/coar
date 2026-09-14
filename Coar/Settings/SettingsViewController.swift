import SwiftUI
import UIKit
import os

/// Settings, presented as a sheet from Home's avatar button. Hosts `SettingsForm` per
/// ADR 0001: this controller reads and writes through the façade and preferences, and
/// re-renders the form with fresh values after every action.
final class SettingsViewController: UIHostingController<SettingsForm> {

    private static let logger = Logger(subsystem: "com.johnnguyen.coar", category: "Settings")

    private let dependencies: AppDependencies
    private var model: SettingsForm.Model

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.model = SettingsForm.Model(
            target: Self.targetToday(in: dependencies.store),
            massUnit: dependencies.preferences.massUnit,
            healthStatus: nil
        )
        super.init(rootView: SettingsForm(model: model, onSaveTargets: { _ in }, onChangeMassUnit: { _ in }, onConnectHealth: {}))
        title = "Settings"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        render()
        refreshHealthStatus()
    }

    /// Wraps the controller in the navigation bar and grabber sheet Home presents.
    static func sheet(dependencies: AppDependencies) -> UIViewController {
        let navigation = UINavigationController(rootViewController: SettingsViewController(dependencies: dependencies))
        navigation.navigationBar.prefersLargeTitles = false
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        return navigation
    }

    // MARK: - Actions

    private func saveTargets(_ macros: Macros) {
        do {
            try dependencies.store.setTarget(macros)
            model.target = Self.targetToday(in: dependencies.store)
        } catch {
            Self.logger.error("Failed to save Target: \(error, privacy: .public)")
        }
        render()
    }

    private func changeMassUnit(_ unit: MassUnit) {
        dependencies.preferences.massUnit = unit
        model.massUnit = unit
        render()
    }

    private func connectHealth() {
        Task {
            do {
                try await dependencies.health.requestAccess()
            } catch {
                Self.logger.error("HealthKit authorisation failed: \(error, privacy: .public)")
            }
            refreshHealthStatus()
        }
    }

    private func refreshHealthStatus() {
        Task {
            model.healthStatus = await dependencies.health.status()
            render()
        }
    }

    // MARK: - Rendering

    private func render() {
        rootView = SettingsForm(
            model: model,
            onSaveTargets: { [weak self] in self?.saveTargets($0) },
            onChangeMassUnit: { [weak self] in self?.changeMassUnit($0) },
            onConnectHealth: { [weak self] in self?.connectHealth() }
        )
    }

    private static func targetToday(in store: Store) -> Macros? {
        do {
            return try store.target(inForceOn: .today())?.macros
        } catch {
            logger.error("Failed to read Target: \(error, privacy: .public)")
            return nil
        }
    }
}
