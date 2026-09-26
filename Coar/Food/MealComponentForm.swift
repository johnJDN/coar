import SwiftUI

/// A Meal line's content (ADR 0001: SwiftUI leaf, values in, closures out): which Serving of
/// the Food Item and how many of it. Every edit reports the whole draft so the host can
/// enable Save.
struct MealComponentForm: View {

    struct Draft: Equatable {
        let id: MealComponentDraft.ID
        let foodItemID: FoodItemRecord.ID
        var servingID: ServingRecord.ID?
        /// As typed; nil while empty.
        var typedQuantity: Double?

        /// The valid quantity, or nil while the field is empty or not positive.
        var quantity: Double? {
            FoodText.quantity(typed: typedQuantity)
        }

        /// The line as it will be saved, or nil until a Serving and a quantity are set.
        func component(among servings: [ServingRecord]) -> MealComponentDraft? {
            guard let servingID, servings.contains(where: { $0.id == servingID }), let quantity else { return nil }
            return MealComponentDraft(id: id, foodItemID: foodItemID, servingID: servingID, quantity: quantity)
        }
    }

    let servings: [ServingRecord]
    let onChange: (Draft) -> Void

    @State private var draft: Draft

    init(servings: [ServingRecord], draft: Draft, onChange: @escaping (Draft) -> Void) {
        self.servings = servings
        self.onChange = onChange
        _draft = State(initialValue: draft)
    }

    private var serving: ServingRecord? {
        servings.first { $0.id == draft.servingID }
    }

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
                        .tag(Optional(serving.id))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .formRow()
            }

            Section {
                QuantityRow(quantity: $draft.typedQuantity, unitName: serving?.name)
                    .formRow()
            }

            Section("In the meal") {
                MacroStrip(macros: preview)
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

#Preview {
    let servings = [
        ServingRecord(id: UUID(), name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), grams: 50, isDefault: true),
        ServingRecord(id: UUID(), name: "100 g", macros: Macros(calories: 140, protein: 12, fat: 10, carbs: 1), grams: 100, isDefault: false),
    ]
    MealComponentForm(servings: servings, draft: .init(id: UUID(), foodItemID: UUID(), servingID: servings[0].id, typedQuantity: 2)) { _ in }
}
