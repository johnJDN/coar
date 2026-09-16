import SwiftUI
import UIKit
import os

/// The Serving sheet's content (ADR 0001: SwiftUI leaf, values in, closures out): the
/// Serving's name, its weight in grams when known, the macros for one of it, and whether it
/// is the default. Every edit reports the whole draft so the host can enable Save.
struct ServingForm: View {

    struct Draft: Equatable {
        let id: ServingDraft.ID
        var name = ""
        /// As typed; nil while empty.
        var grams: Double?
        /// As typed; an empty field counts as 0.
        var macros: [Macro: Double?] = [:]
        var isDefault = false

        init(_ serving: ServingDraft?) {
            id = serving?.id ?? UUID()
            guard let serving else { return }
            name = serving.name
            grams = serving.grams
            macros = Dictionary(uniqueKeysWithValues: Macro.allCases.map { ($0, serving.macros[$0]) })
            isDefault = serving.isDefault
        }

        /// The Serving as it will be saved, or nil while the name is empty or a number is
        /// out of range.
        var serving: ServingDraft? {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if let grams, !(grams > 0 && grams.isFinite) { return nil }
            var values = Macros.zero
            for macro in Macro.allCases {
                let value = (macros[macro] ?? nil) ?? 0
                guard value >= 0, value.isFinite else { return nil }
                values[macro] = value
            }
            return ServingDraft(id: id, name: trimmed, macros: values, grams: grams, isDefault: isDefault)
        }
    }

    let onChange: (Draft) -> Void

    @State private var draft: Draft
    @FocusState private var nameFocused: Bool

    init(draft: Draft, onChange: @escaping (Draft) -> Void) {
        self.onChange = onChange
        _draft = State(initialValue: draft)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $draft.name, prompt: Text("1 egg, 100 g, 1 cup"))
                    .font(Font.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .formRow()
                HStack(spacing: Metrics.spaceInner) {
                    Text("Weight").foregroundStyle(Color.textPrimary)
                    Spacer()
                    TextField("—", value: $draft.grams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(Font.metricNumber)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityLabel("Weight in grams")
                    Text("g").foregroundStyle(Color.textSecondary)
                }
                .formRow()
            } footer: {
                Text("The weight is optional.")
            }

            Section {
                ForEach(Macro.allCases, id: \.self) { macro in
                    HStack(spacing: Metrics.spaceInner) {
                        IconTile(systemImage: macro.systemImage, tint: macro.accent)
                        Text(macro.title).foregroundStyle(Color.textPrimary)
                        Spacer()
                        TextField("0", value: Binding(get: { draft.macros[macro] ?? nil }, set: { draft.macros[macro] = $0 }), format: .number)
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
                Text("For one serving")
            } footer: {
                Text("Leave a field empty for 0.")
            }

            Section {
                Toggle("Default serving", isOn: $draft.isDefault)
                    .tint(Color.accentGreen)
                    .foregroundStyle(Color.textPrimary)
                    .formRow()
            } footer: {
                Text("The serving logged by the row's + button.")
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .onChange(of: draft) { _, draft in onChange(draft) }
        .onAppear { nameFocused = draft.name.isEmpty }
    }
}

/// The Serving sheet, pushed from the Food Item editor. Hosts `ServingForm`; Save hands the
/// Serving back to the editor's draft (nothing is written until the Food Item is saved).
final class ServingFormViewController: UIHostingController<ServingForm> {

    private var draft: ServingForm.Draft
    private let onSave: (ServingDraft) -> Void
    private let saveItem = UIBarButtonItem(systemItem: .save)

    /// `isFirst`: the Food Item has no Serving yet, so this one is the default.
    init(serving: ServingDraft?, isFirst: Bool, onSave: @escaping (ServingDraft) -> Void) {
        var draft = ServingForm.Draft(serving)
        if isFirst { draft.isDefault = true }
        self.draft = draft
        self.onSave = onSave
        super.init(rootView: ServingForm(draft: draft) { _ in })
        rootView = ServingForm(draft: draft) { [weak self] in self?.draftChanged($0) }
        title = serving == nil ? "New Serving" : "Serving"
        saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
        saveItem.isEnabled = draft.serving != nil
        navigationItem.rightBarButtonItem = saveItem
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    private func draftChanged(_ draft: ServingForm.Draft) {
        self.draft = draft
        saveItem.isEnabled = draft.serving != nil
    }

    private func save() {
        guard let serving = draft.serving else { return }
        onSave(serving)
        navigationController?.popViewController(animated: true)
    }
}

#Preview {
    ServingForm(draft: .init(ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), grams: 50, isDefault: true))) { _ in }
}
