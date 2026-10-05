import SwiftUI

/// The Entry detail's content (ADR 0001: SwiftUI leaf, values in, closures out): the time,
/// the quantity, and the four snapshotted macros, all editable; a Meal Entry's breakdown,
/// read-only, scaled by the quantity; Save as food for an Entry that isn't from a Food Item or
/// Meal; Delete at the bottom. Every edit reports the whole draft so the host can save it.
struct EntryForm: View {

    /// Where the Entry stands with Foods, for its Save as food row.
    enum SaveAsFood: Equatable {
        /// From a Food Item or a Meal already: no row.
        case notOffered
        case offered
        /// A Food Item with the Entry's name is already in Foods.
        case alreadyInFoods
        case saved
    }

    let servingName: String
    var saveAsFood: SaveAsFood = .notOffered
    var onSaveAsFood: () -> Void = {}
    /// A Meal Entry's lines for one of the Meal; empty for a Food Item Entry.
    let components: [EntryComponentRecord]
    let onChange: (EntryDraft) -> Void
    let onDelete: () -> Void

    @State private var draft: EntryDraft

    init(draft: EntryDraft, servingName: String, components: [EntryComponentRecord], onChange: @escaping (EntryDraft) -> Void, onDelete: @escaping () -> Void) {
        self.servingName = servingName
        self.components = components
        self.onChange = onChange
        self.onDelete = onDelete
        _draft = State(initialValue: draft)
    }

    var body: some View {
        Form {
            Section {
                QuantityRow(quantity: Binding(get: { draft.typedQuantity }, set: { draft.setQuantity($0) }), unitName: servingName)
                    .formRow()
                DatePicker("Time", selection: $draft.loggedAt, displayedComponents: .hourAndMinute)
                    .foregroundStyle(Color.textPrimary)
                    .formRow()
            } footer: {
                Text("Changing the quantity scales the macros below.")
            }

            if !components.isEmpty {
                Section {
                    ForEach(Array(components.enumerated()), id: \.offset) { _, line in
                        BreakdownRow(line: line, multiplier: draft.quantity ?? 1)
                            .formRow()
                    }
                } header: {
                    Text("Made of")
                } footer: {
                    Text("The meal as it was when logged.")
                }
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

            if saveAsFood != .notOffered {
                Section {
                    Button(action: onSaveAsFood) {
                        Label(saveAsFood == .offered ? "Save as food" : saveAsFood == .saved ? "Saved to Foods" : "Already in Foods",
                              systemImage: saveAsFood == .offered ? "tray.and.arrow.down" : "checkmark.circle.fill")
                    }
                    .disabled(saveAsFood != .offered)
                    .foregroundStyle(saveAsFood == .offered ? Color.accentGreen : Color.textSecondary)
                    .formRow()
                } footer: {
                    switch saveAsFood {
                    case .alreadyInFoods: Text("A food with this name is in Foods. Log it from there next time.")
                    case .saved: Text("It's in Foods now: next time it's one tap, and typing its name uses these numbers.")
                    default: Text("Adds it to Foods with this portion, so next time it's one tap, and typing its name uses these numbers.")
                    }
                }
            }

            Section {
                Button("Delete entry", role: .destructive, action: onDelete)
                    .foregroundStyle(Color.accentCoral)
                    .formRow()
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
        .background(Color.background)
        .onChange(of: draft) { _, draft in onChange(draft) }
    }
}
