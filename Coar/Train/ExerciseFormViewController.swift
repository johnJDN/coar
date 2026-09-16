import SwiftUI
import UIKit
import os

/// The Exercise sheet, presented from the catalogue and from the Plan editor's picker.
/// Hosts `ExerciseForm` per ADR 0001; Save creates or updates the Exercise through the
/// façade, and Archive (existing Exercises only) hides it from the picker.
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
    private let saveItem = UIBarButtonItem(systemItem: .save)

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
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
        saveItem.isEnabled = draft.isComplete
        navigationItem.rightBarButtonItem = saveItem
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    /// The sheet the catalogue and the picker present.
    static func sheet(dependencies: AppDependencies, mode: Mode, onSaved: @escaping (ExerciseRecord) -> Void) -> UIViewController {
        ExerciseFormViewController(dependencies: dependencies, mode: mode, onSaved: onSaved).inSheet(detents: [.large()])
    }

    private func draftChanged(_ draft: ExerciseForm.Draft) {
        self.draft = draft
        saveItem.isEnabled = draft.isComplete
    }

    private func save() {
        guard draft.isComplete else { return }
        do {
            let saved: ExerciseRecord
            switch mode {
            case .create:
                saved = try dependencies.store.createExercise(
                    name: draft.trimmedName, muscleGroup: draft.muscleGroup, equipment: draft.equipment, restSeconds: draft.restSeconds
                )
            case .edit(let exercise):
                try dependencies.store.updateExercise(
                    exercise.id, name: draft.trimmedName, muscleGroup: draft.muscleGroup, equipment: draft.equipment, restSeconds: draft.restSeconds
                )
                guard let read = try dependencies.store.exercise(exercise.id) else { return }
                saved = read
            }
            finish(with: saved)
        } catch {
            Self.logger.error("Failed to save Exercise: \(error, privacy: .public)")
        }
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
        let onSaved = onSaved
        presentingViewController?.dismiss(animated: true) { onSaved(exercise) }
    }
}
