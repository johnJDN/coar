import SwiftUI
import UIKit
import os

/// The Entry detail sheet, presented from the timeline. Hosts `EntryForm`; Save corrects the
/// Entry through the façade (its Day never changes, ADR 0005); Delete removes only the Entry.
final class EntryDetailViewController: UIHostingController<EntryForm> {

    private static let logger = Logger(category: "Food")

    private let dependencies: AppDependencies
    private let entryID: EntryRecord.ID
    private let onChange: () -> Void
    private let original: EntryDraft
    private var draft: EntryDraft
    private let saveItem = UIBarButtonItem(systemItem: .save)

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
        super.init(rootView: EntryForm(draft: original, servingName: entry.servingName, components: entry.components, onChange: { _ in }, onDelete: {}))
        rootView = EntryForm(
            draft: original,
            servingName: entry.servingName,
            components: entry.components,
            onChange: { [weak self] in self?.draftChanged($0) },
            onDelete: { [weak self] in self?.confirmDelete(entry) }
        )
        title = entry.name
        navigationItem.subtitle = FoodText.when(entry.loggedAt)
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
        saveItem.isEnabled = false
        navigationItem.rightBarButtonItem = saveItem
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The sheet the Food tab presents; nil when the Entry no longer exists.
    static func sheet(dependencies: AppDependencies, entryID: EntryRecord.ID, onChange: @escaping () -> Void) -> UIViewController? {
        EntryDetailViewController(dependencies: dependencies, entryID: entryID, onChange: onChange)?.inSheet(detents: [.large()])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    private func draftChanged(_ draft: EntryDraft) {
        self.draft = draft
        saveItem.isEnabled = draft.isSaveable && draft != original
    }

    // MARK: - Writing

    private func save() {
        guard let quantity = draft.quantity, let macros = draft.macros else { return }
        do {
            try dependencies.store.updateEntry(entryID, loggedAt: draft.loggedAt, quantity: quantity, macros: macros)
            onChange()
            dismiss(animated: true)
        } catch {
            Self.logger.error("Failed to update Entry: \(error, privacy: .public)")
        }
    }

    private func confirmDelete(_ entry: EntryRecord) {
        let alert = UIAlertController(title: "Delete \(entry.name)?", message: "Only this entry is removed.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Delete entry", style: .destructive) { [weak self] _ in
            guard let self else { return }
            do {
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
