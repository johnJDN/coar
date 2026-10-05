import SwiftUI
import UIKit
import os

/// The Entry detail sheet, presented from the timeline. Hosts `EntryForm`. Corrections save
/// as they are made (`EditorSaving`; its Day never changes, ADR 0005) and Done closes; an
/// incomplete quantity is left as it was saved. Save as food adds it to Foods as it stands
/// now. Delete removes only the Entry.
final class EntryDetailViewController: UIHostingController<EntryForm> {

    private static let logger = Logger(category: "Food")

    private let dependencies: AppDependencies
    private let entryID: EntryRecord.ID
    private let onChange: () -> Void
    private let original: EntryDraft
    private let entry: EntryRecord
    private var saveAsFood: EntryForm.SaveAsFood
    private var draft: EntryDraft
    private var saved: EntryDraft
    private lazy var autosaver = Autosaver { [weak self] in self?.autosave() }

    /// Reads the Entry up front so the form is built once, with the real record (a hosted
    /// view keeps its state across `rootView` swaps). Nil when the Entry is gone.
    init?(dependencies: AppDependencies, entryID: EntryRecord.ID, onChange: @escaping () -> Void) {
        self.dependencies = dependencies
        self.entryID = entryID
        self.onChange = onChange
        let entry: EntryRecord
        do {
            guard let read = try dependencies.store.entry(entryID) else { return nil }
            entry = read
        } catch {
            Self.logger.error("Failed to read Entry: \(error, privacy: .public)")
            return nil
        }
        original = EntryDraft(entry)
        draft = original
        saved = original
        self.entry = entry
        saveAsFood = Self.saveAsFood(for: entry, store: dependencies.store)
        super.init(rootView: EntryForm(draft: original, servingName: entry.servingName, components: entry.components, onChange: { _ in }, onDelete: {}))
        rootView = form()
        title = entry.name
        navigationItem.subtitle = FoodText.when(entry.loggedAt)
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The form as it stands; the hosted view keeps its own draft across swaps.
    private func form() -> EntryForm {
        var form = EntryForm(
            draft: original,
            servingName: entry.servingName,
            components: entry.components,
            onChange: { [weak self] in self?.draftChanged($0) },
            onDelete: { [weak self] in self.map { $0.confirmDelete($0.entry) } }
        )
        form.saveAsFood = saveAsFood
        form.onSaveAsFood = { [weak self] in self?.saveToFoods() }
        return form
    }

    private static func saveAsFood(for entry: EntryRecord, store: Store) -> EntryForm.SaveAsFood {
        guard entry.foodItemID == nil, entry.mealID == nil else { return .notOffered }
        return (try? store.foodItem(named: entry.name)) != nil ? .alreadyInFoods : .offered
    }

    /// The sheet the Food tab presents; nil when the Entry no longer exists.
    static func sheet(dependencies: AppDependencies, entryID: EntryRecord.ID, onChange: @escaping () -> Void) -> UIViewController? {
        EntryDetailViewController(dependencies: dependencies, entryID: entryID, onChange: onChange)?.inSheet(detents: [.large()])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    /// Done or a swipe down: whatever was typed is saved first.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        autosaver.flush()
    }

    private func draftChanged(_ draft: EntryDraft) {
        self.draft = draft
        if draft.isSaveable, draft != saved { autosaver.schedule() }
    }

    // MARK: - Writing

    private func autosave() {
        guard draft != saved, let quantity = draft.quantity, let macros = draft.macros else { return }
        do {
            try dependencies.store.updateEntry(entryID, loggedAt: draft.loggedAt, quantity: quantity, macros: macros)
            saved = draft
            onChange()
        } catch {
            Self.logger.error("Failed to update Entry: \(error, privacy: .public)")
        }
    }

    /// Saves what the Entry holds now, so a correction typed a moment ago goes with it.
    private func saveToFoods() {
        autosaver.flush()
        do {
            saveAsFood = try dependencies.store.saveEntryAsFood(entryID) == nil ? .alreadyInFoods : .saved
            rootView = form()
            onChange()
        } catch {
            Self.logger.error("Failed to save Entry as food: \(error, privacy: .public)")
        }
    }

    private func confirmDelete(_ entry: EntryRecord) {
        let alert = UIAlertController(title: "Delete \(entry.name)?", message: "Only this entry is removed.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Delete entry", style: .destructive) { [weak self] _ in
            guard let self else { return }
            do {
                autosaver.cancelPending()
                try dependencies.store.deleteEntry(entryID)
                onChange()
                dismiss(animated: true)
            } catch {
                Self.logger.error("Failed to delete Entry: \(error, privacy: .public)")
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
