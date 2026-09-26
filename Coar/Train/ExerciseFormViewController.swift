import SwiftUI
import UIKit
import os

/// The Exercise sheet, presented from the catalogue and from the Plan editor's list. Hosts
/// `ExerciseForm` per ADR 0001. A new Exercise has Cancel and Save (and asks before a
/// half-filled one is discarded); an existing one saves as it changes and has Done
/// (`EditorSaving`). Archive (existing Exercises only) hides it from what Plans can add.
final class ExerciseFormViewController: UIHostingController<ExerciseForm> {

    enum Mode {
        case create(name: String)
        case edit(ExerciseRecord)
    }

    private static let logger = Logger(category: "Train")

    private let dependencies: AppDependencies
    private let mode: Mode
    private let onSaved: (ExerciseRecord) -> Void
    private var draft: ExerciseForm.Draft
    private let initial: ExerciseForm.Draft
    private let saveItem = UIBarButtonItem(systemItem: .save)
    private lazy var autosaver = Autosaver { [weak self] in self?.autosave() }
    private var discardGuard: SheetDiscardGuard?
    /// Set once `onSaved` has been reported, so a swipe down reports only if nothing did.
    private var hasReported = false

    /// `onSaved` runs once the sheet is down, with the Exercise as it now stands (archived,
    /// after Archive).
    init(dependencies: AppDependencies, mode: Mode, onSaved: @escaping (ExerciseRecord) -> Void) {
        self.dependencies = dependencies
        self.mode = mode
        self.onSaved = onSaved
        let canArchive: Bool
        switch mode {
        case .create(let name):
            var draft = ExerciseForm.Draft()
            draft.name = name
            self.draft = draft
            canArchive = false
        case .edit(let exercise):
            draft = ExerciseForm.Draft(exercise)
            canArchive = true
        }
        initial = draft
        super.init(rootView: ExerciseForm(draft: draft, canArchive: canArchive, onChange: { _ in }, onArchive: {}))
        rootView = ExerciseForm(
            draft: draft,
            canArchive: canArchive,
            onChange: { [weak self] in self?.draftChanged($0) },
            onArchive: { [weak self] in self?.archive() }
        )
        switch mode {
        case .create: title = "New Exercise"
        case .edit: title = "Edit Exercise"
        }
        switch mode {
        case .create:
            navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
                self?.discardGuard?.cancel()
            })
            saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
            saveItem.isEnabled = draft.isComplete
            navigationItem.rightBarButtonItem = saveItem
            discardGuard = SheetDiscardGuard(controller: self, title: "Discard this exercise?") { [weak self] in
                guard let self else { return false }
                return draft != initial
            }
        case .edit:
            navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.done() })
        }
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        discardGuard?.refresh()
    }

    /// A swipe down closes an existing Exercise's sheet too: whatever was typed is kept.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        autosaver.flush()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard case .edit(let exercise) = mode, !hasReported, navigationController?.isBeingDismissed ?? isBeingDismissed,
              let stored = try? dependencies.store.exercise(exercise.id) else { return }
        hasReported = true
        onSaved(stored)
    }

    /// The sheet the catalogue and the picker present.
    static func sheet(dependencies: AppDependencies, mode: Mode, onSaved: @escaping (ExerciseRecord) -> Void) -> UIViewController {
        ExerciseFormViewController(dependencies: dependencies, mode: mode, onSaved: onSaved).inSheet(detents: [.large()])
    }

    private func draftChanged(_ draft: ExerciseForm.Draft) {
        self.draft = draft
        switch mode {
        case .create:
            saveItem.isEnabled = draft.isComplete
            discardGuard?.refresh()
        case .edit:
            if draft.isComplete { autosaver.schedule() }
        }
    }

    /// A new Exercise's Save.
    private func save() {
        guard case .create = mode, draft.isComplete else { return }
        do {
            let created = try dependencies.store.createExercise(
                name: draft.trimmedName, muscleGroup: draft.muscleGroup, secondaryMuscleGroups: draft.secondaryGroups,
                equipment: draft.equipment, restSeconds: draft.restSeconds
            )
            finish(with: created)
        } catch {
            Self.logger.error("Failed to save Exercise: \(error, privacy: .public)")
        }
    }

    /// An existing Exercise saves whenever the draft is complete; an incomplete one (no
    /// name) is left as it was saved.
    private func autosave() {
        guard case .edit(let exercise) = mode, draft.isComplete else { return }
        do {
            try dependencies.store.updateExercise(
                exercise.id, name: draft.trimmedName, muscleGroup: draft.muscleGroup, secondaryMuscleGroups: draft.secondaryGroups,
                equipment: draft.equipment, restSeconds: draft.restSeconds
            )
        } catch {
            Self.logger.error("Failed to save Exercise: \(error, privacy: .public)")
        }
    }

    /// An existing Exercise's Done: saved already.
    private func done() {
        guard case .edit(let exercise) = mode else { return }
        autosaver.flush()
        if let stored = try? dependencies.store.exercise(exercise.id) { finish(with: stored) }
    }

    private func archive() {
        guard case .edit(let exercise) = mode else { return }
        do {
            try dependencies.store.archiveExercise(exercise.id)
            guard let read = try dependencies.store.exercise(exercise.id) else { return }
            finish(with: read)
        } catch {
            Self.logger.error("Failed to archive Exercise: \(error, privacy: .public)")
        }
    }

    /// Reports once the sheet is down, so a caller that navigates on the result never does
    /// so under a dismissing sheet.
    private func finish(with exercise: ExerciseRecord) {
        hasReported = true
        let onSaved = onSaved
        presentingViewController?.dismiss(animated: true) { onSaved(exercise) }
    }
}
