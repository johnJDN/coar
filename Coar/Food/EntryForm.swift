import SwiftUI

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
                Text("This entry's own record. Editing it never changes the food item it came from.")
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
