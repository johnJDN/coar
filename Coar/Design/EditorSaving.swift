import UIKit

/// When an editor saves, one rule for the whole app:
///
/// - **Creating** something (a Plan, Food Item, Meal, Exercise, Habit) has an explicit Save:
///   it can be abandoned, and leaving with changes asks before discarding.
/// - **Editing** something that exists saves as it changes: no Save button, and back means
///   done. A state that cannot be saved (a Plan with no name) is never written; leaving it
///   asks whether to keep editing or go back to what was saved.
/// - **A page inside an editor** (Planned Sets, a Serving, a Meal line) writes into its
///   parent as it changes and has no Save of its own, so nothing is lost between levels.
///
/// `Autosaver` does the saving for the editing case; `BackGuard` guards leaving.

/// Saves shortly after the last change, so typing is one write rather than one per key,
/// and at once on `flush()` (the page is leaving).
@MainActor
final class Autosaver {

    private let delay: Duration
    private let save: () -> Void
    private var pending: Task<Void, Never>?

    init(delay: Duration = .milliseconds(500), save: @escaping () -> Void) {
        self.delay = delay
        self.save = save
    }

    func schedule() {
        pending?.cancel()
        pending = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    func flush() {
        pending?.cancel()
        pending = nil
        save()
    }

    /// Drops a scheduled save (the thing is being deleted).
    func cancelPending() {
        pending?.cancel()
        pending = nil
    }
}

/// Stands between a pushed page and its back button (and the swipe back): `verdict` says
/// whether it can leave now, or what to ask first. Asking offers "Keep editing" and a
/// destructive button that leaves anyway and runs `onDiscard`.
@MainActor
final class BackGuard {

    enum Verdict {
        case leave
        case ask(title: String, message: String?, discard: String)
    }

    private weak var controller: UIViewController?
    private let verdict: () -> Verdict
    private let onDiscard: () -> Void

    init(controller: UIViewController, verdict: @escaping () -> Verdict, onDiscard: @escaping () -> Void = {}) {
        self.controller = controller
        self.verdict = verdict
        self.onDiscard = onDiscard
        controller.navigationItem.backAction = UIAction { [weak self] _ in self?.back() }
    }

    /// Call after every change: while the page cannot simply leave, the swipe back (which
    /// cannot be asked about) is off and only the back button, which asks, remains.
    func refresh() {
        guard let navigation = controller?.navigationController, navigation.topViewController === controller else { return }
        let canLeave = if case .leave = verdict() { true } else { false }
        navigation.interactivePopGestureRecognizer?.isEnabled = canLeave
        navigation.interactiveContentPopGestureRecognizer?.isEnabled = canLeave
    }

    /// Call from `viewWillDisappear`: the swipe back works again for the next page.
    func release() {
        controller?.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        controller?.navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = true
    }

    private func back() {
        guard let controller else { return }
        switch verdict() {
        case .leave:
            controller.navigationController?.popViewController(animated: true)
        case .ask(let title, let message, let discard):
            controller.view.endEditing(true)
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel))
            alert.addAction(UIAlertAction(title: discard, style: .destructive) { [weak self, weak controller] _ in
                self?.onDiscard()
                controller?.navigationController?.popViewController(animated: true)
            })
            controller.present(alert, animated: true)
        }
    }
}

/// `BackGuard` for a sheet that creates something: while `hasChanges`, a swipe down or
/// Cancel asks before discarding rather than closing at once.
@MainActor
final class SheetDiscardGuard: NSObject, UIAdaptivePresentationControllerDelegate {

    private weak var controller: UIViewController?
    private let title: String
    private let hasChanges: () -> Bool

    init(controller: UIViewController, title: String, hasChanges: @escaping () -> Bool) {
        self.controller = controller
        self.title = title
        self.hasChanges = hasChanges
        super.init()
    }

    /// Call from `viewDidAppear` (the presentation exists by then) and after every change.
    func refresh() {
        guard let controller else { return }
        let sheet = controller.navigationController ?? controller
        sheet.presentationController?.delegate = self
        sheet.isModalInPresentation = hasChanges()
    }

    /// Cancel: closes, asking first when there is something to lose.
    func cancel() {
        hasChanges() ? ask() : close()
    }

    nonisolated func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        MainActor.assumeIsolated { ask() }
    }

    private func ask() {
        guard let controller else { return }
        controller.view.endEditing(true)
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in self?.close() })
        alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel))
        controller.present(alert, animated: true)
    }

    private func close() {
        controller?.dismiss(animated: true)
    }
}
