import SwiftUI

/// The log page's content (ADR 0001: SwiftUI leaf, values in, closures out): which Serving,
/// how many, and when; the macros the Entry will carry, shown as a preview. Every edit
/// reports the whole draft so the host can enable Add.
struct LogFoodItemForm: View {

    struct Draft: Equatable {
        var servingID: ServingRecord.ID
        /// As typed; nil while empty.
        var typedQuantity: Double? = 1
        var loggedAt: Date

        /// The valid quantity, or nil while the field is empty or not positive.
        var quantity: Double? {
            FoodText.quantity(typed: typedQuantity)
        }
    }

    let servings: [ServingRecord]
    let onChange: (Draft) -> Void

    @State private var draft: Draft
    @FocusState private var quantityFocused: Bool

    init(servings: [ServingRecord], draft: Draft, onChange: @escaping (Draft) -> Void) {
        self.servings = servings
        self.onChange = onChange
        _draft = State(initialValue: draft)
    }

    private var serving: ServingRecord? {
        servings.first { $0.id == draft.servingID }
    }

    /// What the Entry will carry: the Serving's macros for the quantity; nil until both exist.
    private var preview: Macros? {
        guard let serving, let quantity = draft.quantity else { return nil }
        return serving.macros.scaled(by: quantity)
    }

    var body: some View {
        Form {
            Section("Serving") {
                Picker("Serving", selection: $draft.servingID) {
                    ForEach(servings) { serving in
                        HStack {
                            Text(serving.name).foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(FoodText.calories(serving.macros)).foregroundStyle(Color.textSecondary)
                        }
                        .tag(serving.id)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .formRow()
            }

            Section {
                HStack(spacing: Metrics.spaceInner) {
                    Text("Quantity").foregroundStyle(Color.textPrimary)
                    Spacer()
                    TextField("—", value: $draft.typedQuantity, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(Font.metricNumber)
                        .foregroundStyle(Color.accentGreen)
                        .focused($quantityFocused)
                        .accessibilityLabel("Quantity")
                    if let serving {
                        Text("× \(serving.name)").foregroundStyle(Color.textSecondary)
                    }
                }
                .formRow()
                DatePicker("Time", selection: $draft.loggedAt, displayedComponents: .hourAndMinute)
                    .foregroundStyle(Color.textPrimary)
                    .formRow()
            }

            Section {
                ForEach(Macro.allCases, id: \.self) { macro in
                    MacroPreviewRow(macro: macro, value: preview?[macro])
                        .formRow()
                }
            } header: {
                Text("This entry")
            } footer: {
                Text("Kept with the entry as logged. Editing the food item later never changes it.")
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .onChange(of: draft) { _, draft in onChange(draft) }
        .onChange(of: servings) { _, servings in
            // The Food Item was edited underneath: a Serving that is gone falls back to the default.
            guard !servings.contains(where: { $0.id == draft.servingID }), let fallback = servings.first(where: \.isDefault) ?? servings.first else { return }
            draft.servingID = fallback.id
        }
        .onAppear { quantityFocused = true }
    }
}

/// A macro's row: tile, name, and the value in its accent, or `—` while there is none
/// (DESIGN.md §1.5).
struct MacroPreviewRow: View {
    let macro: Macro
    let value: Double?

    var body: some View {
        HStack(spacing: Metrics.spaceInner) {
            IconTile(systemImage: macro.systemImage, tint: macro.accent)
            Text(macro.title).foregroundStyle(Color.textPrimary)
            Spacer()
            Text(value.map { "\(FoodText.amount($0)) \(macro.unit)" } ?? "—")
                .font(Font.metricNumber)
                .monospacedDigit()
                .foregroundStyle(value == nil ? Color.textTertiary : macro.accent)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let servings = [
        ServingRecord(id: UUID(), name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), grams: 50, isDefault: true),
        ServingRecord(id: UUID(), name: "100 g", macros: Macros(calories: 140, protein: 12, fat: 10, carbs: 1), grams: 100, isDefault: false),
    ]
    LogFoodItemForm(servings: servings, draft: .init(servingID: servings[0].id, loggedAt: Date())) { _ in }
}
