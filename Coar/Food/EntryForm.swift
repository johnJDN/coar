import SwiftUI

/// The Entry detail's content (ADR 0001: SwiftUI leaf, values in, closures out): the name,
/// the quantity and its unit (a Meal Entry's stays "meal"), the time, and the four
/// snapshotted macros, all editable; a Meal Entry's breakdown,
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

    var saveAsFood: SaveAsFood = .notOffered
    var onSaveAsFood: () -> Void = {}
    /// A Meal Entry's lines for one of the Meal; empty for a Food Item Entry.
    let components: [EntryComponentRecord]
    let onChange: (EntryDraft) -> Void
    let onDelete: () -> Void

    @State private var draft: EntryDraft

    init(draft: EntryDraft, components: [EntryComponentRecord], onChange: @escaping (EntryDraft) -> Void, onDelete: @escaping () -> Void) {
        self.components = components
        self.onChange = onChange
        self.onDelete = onDelete
        _draft = State(initialValue: draft)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: Metrics.spaceInner) {
                    Text("Name").foregroundStyle(Color.textPrimary)
                    TextField("Name", text: $draft.name)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Color.textPrimary)
                }
                .formRow()
                QuantityRow(quantity: Binding(get: { draft.typedQuantity }, set: { draft.setQuantity($0) }), unitName: draft.isMeal ? draft.unit : nil)
                    .formRow()
                if !draft.isMeal {
                    HStack(spacing: Metrics.spaceInner) {
                        Text("Unit").foregroundStyle(Color.textPrimary)
                        TextField("serving", text: Binding(get: { draft.unit }, set: { draft.setUnit($0) }))
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Color.textSecondary)
                            .textInputAutocapitalization(.never)
                            // Short words and abbreviations ("g", "cup") that autocorrect mangles.
                            .autocorrectionDisabled()
                    }
                    .formRow()
                }
                DatePicker("Time", selection: $draft.loggedAt, displayedComponents: .hourAndMinute)
                    .foregroundStyle(Color.textPrimary)
                    .formRow()
            } footer: {
                if draft.unitNeedsNumbers {
                    Text("The macros below are still for \(draft.numbersPortion). Change them if \(FoodText.portion(draft.quantity ?? 1, of: draft.servingName ?? draft.unit)) is different.")
                } else if draft.isMeal {
                    Text("Changing the quantity scales the macros below.")
                } else {
                    Text("Changing the quantity scales the macros below. Switching the unit to g or oz converts by weight when it's known.")
                }
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
                        TextField("0", value: Binding(get: { draft.typedMacros[macro] ?? nil }, set: { draft.setMacro(macro, $0) }), format: .number.precision(.fractionLength(0...1)))
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
                Text("This entry's own record. Editing it, its name or its unit never changes the food item it came from.")
            }

            if !draft.shownExtras.isEmpty {
                Section {
                    ExtraRows(extras: draft.shownExtras) { extra in
                        Binding(get: { draft.typedExtras[extra] ?? nil }, set: { draft.typedExtras[extra] = $0 })
                    }
                } header: {
                    Text("Also recorded")
                } footer: {
                    Text("What the food had beyond the macros. Only what is known is shown; a blank is not a zero.")
                }
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
