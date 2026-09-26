import SwiftUI

/// The log page's content for a Meal (ADR 0001: SwiftUI leaf, values in, closures out): how
/// many of the Meal and when; the macros the Entry will carry and the lines it is made of,
/// both scaled by the multiplier, as a preview. Every edit reports the whole draft so the
/// host can enable Add.
struct LogMealForm: View {

    struct Draft: Equatable {
        /// As typed; nil while empty.
        var typedQuantity: Double? = 1
        var loggedAt: Date

        /// The valid multiplier, or nil while the field is empty or not positive.
        var quantity: Double? {
            FoodText.quantity(typed: typedQuantity)
        }
    }

    let meal: MealRecord
    let onChange: (Draft) -> Void
    /// The warning card's "Edit meal", for a Meal that cannot be logged.
    var onEditMeal: () -> Void = {}

    @State private var draft: Draft

    init(meal: MealRecord, draft: Draft, onEditMeal: @escaping () -> Void = {}, onChange: @escaping (Draft) -> Void) {
        self.meal = meal
        self.onEditMeal = onEditMeal
        self.onChange = onChange
        _draft = State(initialValue: draft)
    }

    /// What the Entry will carry: the Meal's macros for the multiplier; nil until it is set.
    private var preview: Macros? {
        draft.quantity.map(meal.macros.scaled(by:))
    }

    var body: some View {
        Form {
            if !meal.isLoggable {
                Section {
                    WarningCard(
                        title: "This meal can't be logged",
                        message: "A serving one of its foods used was removed, so its macros would be wrong. Pick another serving for that line.",
                        actionTitle: "Edit meal",
                        action: onEditMeal
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                QuantityRow(quantity: $draft.typedQuantity, unitName: EntryRecord.mealServingName)
                    .formRow()
                DatePicker("Time", selection: $draft.loggedAt, displayedComponents: .hourAndMinute)
                    .foregroundStyle(Color.textPrimary)
                    .formRow()
            } footer: {
                Text("Half the meal is 0.5.")
            }

            Section {
                ForEach(Macro.allCases, id: \.self) { macro in
                    MacroPreviewRow(macro: macro, value: preview?[macro])
                        .formRow()
                }
            } header: {
                Text("This entry")
            }

            Section {
                ForEach(Array(meal.components.enumerated()), id: \.offset) { _, line in
                    BreakdownRow(line: EntryComponentRecord(line), multiplier: draft.quantity ?? 1)
                        .formRow()
                }
            } header: {
                Text("Made of")
            } footer: {
                Text("Kept with the entry as logged. Editing the meal or its foods later never changes it.")
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

/// One line of a Meal's breakdown, scaled by the Entry's multiplier: the Food Item's name,
/// "2 × 1 egg", and the calories as the trailing value (DESIGN.md §1.2). A line whose
/// Serving is gone reads `—` in the slot (§1.5).
struct BreakdownRow: View {
    /// The line for one of the Meal.
    let line: EntryComponentRecord
    let multiplier: Double

    var body: some View {
        HStack(spacing: Metrics.spaceInner) {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.name).font(Font.cardTitle).foregroundStyle(Color.textPrimary)
                Text(line.servingName.isEmpty ? "—" : FoodText.quantity(line.quantity * multiplier, of: line.servingName))
                    .font(Font.label)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Text(FoodText.calories(line.macros.scaled(by: multiplier)))
                .font(Font.metricNumber)
                .monospacedDigit()
                .foregroundStyle(Color.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let meal = MealRecord(id: UUID(), name: "Egg bowl", isArchived: false, components: [
        MealComponentRecord(id: UUID(), foodItemID: UUID(), servingID: UUID(), name: "Eggs", servingName: "1 egg", quantity: 2, servingMacros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0)),
        MealComponentRecord(id: UUID(), foodItemID: UUID(), servingID: UUID(), name: "Rice", servingName: "1 cup", quantity: 1, servingMacros: Macros(calories: 200, protein: 4, fat: 0, carbs: 44)),
    ], modifiedAt: Date())
    LogMealForm(meal: meal, draft: .init(loggedAt: Date())) { _ in }
}
