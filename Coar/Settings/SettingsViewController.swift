import SwiftUI
import UIKit
import os

/// Settings, presented as a sheet from Home's avatar button. Hosts `SettingsForm` per
/// ADR 0001: this controller reads and writes through the façade and preferences, and
/// re-renders the form with fresh values after every action. Targets as typed are kept
/// and saved when the sheet closes, however it closes (Done or a swipe down); `onClose`
/// then lets the presenter refresh.
final class SettingsViewController: UIHostingController<SettingsForm> {

    private static let logger = Logger(category: "Settings")

    private let dependencies: AppDependencies
    private var model: SettingsForm.Model
    private let onClose: () -> Void
    /// The Targets as typed; nil while nothing valid has been typed.
    private var pendingTargets: Macros?

    init(dependencies: AppDependencies, onClose: @escaping () -> Void = {}) {
        self.dependencies = dependencies
        self.onClose = onClose
        self.model = SettingsForm.Model(
            target: Self.targetToday(in: dependencies.store),
            massUnit: dependencies.preferences.massUnit,
            healthStatus: nil,
            aiKey: dependencies.openRouter.keys.lastFour.map { .saved(lastFour: $0, spend: nil, problem: nil) } ?? .missing(problem: nil)
        )
        super.init(rootView: SettingsForm(model: model, onTargetsChanged: { _ in }, onChangeMassUnit: { _ in }, onConnectHealth: {}))
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
        refreshKeySpending()
    }

    /// The sheet Home presents.
    static func sheet(dependencies: AppDependencies, onClose: @escaping () -> Void = {}) -> UIViewController {
        SettingsViewController(dependencies: dependencies, onClose: onClose).inSheet(detents: [.large()])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isBeingDismissed || navigationController?.isBeingDismissed == true else { return }
        view.endEditing(true)
        saveTargets()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed || navigationController?.isBeingDismissed == true else { return }
        onClose()
    }

    // MARK: - Actions

    /// Saves the Targets as typed, if they changed. Setting the same Day again replaces
    /// that Day's Target rather than adding one (ADR 0003).
    func saveTargets() {
        guard let pendingTargets, pendingTargets != model.target else { return }
        do {
            try dependencies.store.setTarget(pendingTargets)
            model.target = Self.targetToday(in: dependencies.store)
        } catch {
            Self.logger.error("Failed to save Target: \(error, privacy: .public)")
        }
    }

    private func changeMassUnit(_ unit: MassUnit) {
        dependencies.preferences.massUnit = unit
        model.massUnit = unit
        render()
    }

    private func connectHealth() {
        Task {
            await dependencies.health.connect()
            refreshHealthStatus()
        }
    }

    /// Checks a pasted key with OpenRouter, then keeps it in the Keychain. Only a key
    /// OpenRouter refuses is not kept: with no connection, or a spent limit, it is saved and
    /// the problem shown, since the key itself is fine.
    private func saveKey(_ key: String) {
        model.aiKey = .checking
        render()
        Task {
            var spend: String?
            var problem: String?
            do {
                spend = try await dependencies.openRouter.keyStatus(of: key).spendText
            } catch {
                let error = OpenRouterError.from(error)
                if error == .keyRejected {
                    model.aiKey = .missing(problem: error.message)
                    render()
                    return
                }
                problem = error == .offline ? "Couldn't check the key: no connection." : error.message
            }
            do {
                try dependencies.openRouter.keys.save(key)
                model.aiKey = .saved(lastFour: String(key.suffix(4)), spend: spend, problem: problem)
            } catch {
                Self.logger.error("Failed to save the OpenRouter key: \(error, privacy: .public)")
                model.aiKey = .missing(problem: "Couldn't save the key on this iPhone (\(error)).")
            }
            render()
        }
    }

    private func removeKey() {
        do {
            try dependencies.openRouter.keys.delete()
            model.aiKey = .missing(problem: nil)
        } catch {
            Self.logger.error("Failed to remove the OpenRouter key: \(error, privacy: .public)")
        }
        render()
    }

    /// Reads the saved key's spending, if there is a key.
    private func refreshKeySpending() {
        guard case .saved(let lastFour, _, _) = model.aiKey else { return }
        Task {
            do {
                let status = try await dependencies.openRouter.keyStatus()
                model.aiKey = .saved(lastFour: lastFour, spend: status.spendText, problem: nil)
            } catch {
                let error = OpenRouterError.from(error)
                model.aiKey = .saved(lastFour: lastFour, spend: nil, problem: error == .offline ? "Couldn't check spending: no connection." : error.message)
            }
            render()
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
            onTargetsChanged: { [weak self] in self?.pendingTargets = $0 },
            onChangeMassUnit: { [weak self] in self?.changeMassUnit($0) },
            onConnectHealth: { [weak self] in self?.connectHealth() },
            onSaveKey: { [weak self] in self?.saveKey($0) },
            onRemoveKey: { [weak self] in self?.removeKey() }
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
