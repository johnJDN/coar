import SwiftUI
import UIKit
import os

/// The Entry detail's content (ADR 0001: SwiftUI leaf, values in, closures out): the time,
/// the quantity, and the four snapshotted macros, all editable; Delete at the bottom. Every
/// edit reports the whole draft so the host can enable Save.
struct EntryForm: View {

    let servingName: String
    let onChange: (EntryDraft) -> Void
    let onDelete: () -> Void

    @State private var draft: EntryDraft

    init(draft: EntryDraft, servingName: String, onChange: @escaping (EntryDraft) -> Void, onDelete: @escaping () -> Void) {
        self.servingName = servingName
        self.onChange = onChange
        self.onDelete = onDelete
        _draft = State(initialValue: draft)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: Metrics.spaceInner) {
                    Text("Quantity").foregroundStyle(Color.textPrimary)
                    Spacer()
                    TextField("—", value: Binding(get: { draft.typedQuantity }, set: { draft.setQuantity($0) }), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(Font.metricNumber)
                        .foregroundStyle(Color.accentGreen)
                        .accessibilityLabel("Quantity")
                    Text("× \(servingName)").foregroundStyle(Color.textSecondary)
                }
                .formRow()
                DatePicker("Time", selection: $draft.loggedAt, displayedComponents: .hourAndMinute)
                    .foregroundStyle(Color.textPrimary)
                    .formRow()
            } footer: {
                Text("Changing the quantity scales the macros below.")
            }

            Section {
                ForEach(Macro.allCases, id: \.self) { macro in
                    HStack(spacing: Metrics.spaceInner) {
                        IconTile(systemImage: macro.systemImage, tint: macro.accent)
                        Text(macro.title).foregroundStyle(Color.textPrimary)
                        Spacer()
                        TextField("0", value: Binding(get: { draft.typedMacros[macro] ?? nil }, set: { draft.typedMacros[macro] = $0 }), format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(Font.metricNumber)
                            .foregroundStyle(macro.accent)
                            .accessibilityLabel(macro.title)
                        Text(macro.unit).foregroundStyle(Color.textSecondary)
                    }
                    .formRow()
                }
            } header: {
                Text("As logged")
            } footer: {
                Text("This entry's own record. Editing it never changes the food it came from.")
            }

            Section {
                Button("Delete entry", role: .destructive, action: onDelete)
                    .foregroundStyle(Color.accentCoral)
                    .formRow()
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .onChange(of: draft) { _, draft in onChange(draft) }
    }
}

/// The Entry detail sheet, presented from the timeline. Hosts `EntryForm`; Save corrects the
/// Entry through the façade (its Day never changes, ADR 0005); Delete removes only the Entry.
final class EntryDetailViewController: UIHostingController<EntryForm> {

    private static let logger = Logger(category: "Food")

    private let dependencies: AppDependencies
    private let entryID: EntryRecord.ID
    private let onChange: () -> Void
    private var original: EntryDraft?
    private var draft: EntryDraft?
    private let saveItem = UIBarButtonItem(systemItem: .save)

    init(dependencies: AppDependencies, entryID: EntryRecord.ID, onChange: @escaping () -> Void) {
        self.dependencies = dependencies
        self.entryID = entryID
        self.onChange = onChange
        let placeholder = EntryRecord(
            id: entryID, loggedAt: Date(), day: .today(), name: "", servingName: "", quantity: 1, macros: .zero, foodItemID: nil, modifiedAt: Date()
        )
        super.init(rootView: EntryForm(draft: EntryDraft(placeholder), servingName: "", onChange: { _ in }, onDelete: {}))
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
        saveItem.isEnabled = false
        navigationItem.rightBarButtonItem = saveItem
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The sheet the Food tab presents.
    static func sheet(dependencies: AppDependencies, entryID: EntryRecord.ID, onChange: @escaping () -> Void) -> UIViewController {
        EntryDetailViewController(dependencies: dependencies, entryID: entryID, onChange: onChange).inSheet(detents: [.large()])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        load()
    }

    // MARK: - Reading

    private func load() {
        do {
            guard let entry = try dependencies.store.entry(entryID) else { return dismiss(animated: true) }
            title = entry.name
            navigationItem.subtitle = AddEntryViewController.subtitle(for: entry.loggedAt)
            let draft = EntryDraft(entry)
            original = draft
            self.draft = draft
            rootView = EntryForm(
                draft: draft,
                servingName: entry.servingName,
                onChange: { [weak self] in self?.draftChanged($0) },
                onDelete: { [weak self] in self?.confirmDelete(entry) }
            )
        } catch {
            Self.logger.error("Failed to read Entry: \(error, privacy: .public)")
        }
    }

    private func draftChanged(_ draft: EntryDraft) {
        self.draft = draft
        saveItem.isEnabled = draft.isSaveable && draft != original
    }

    // MARK: - Writing

    private func save() {
        guard let draft, let quantity = draft.quantity, let macros = draft.macros else { return }
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
