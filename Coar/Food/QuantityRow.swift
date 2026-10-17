import SwiftUI

/// The "Quantity" row every log and line form shares: the number in `accentGreen` as the
/// metric, typed as a decimal or a fraction ("1/3", "1 1/2", "½"), with "× 1 egg" beside it,
/// and quick amounts (¼ ½ ¾ 1 1½ 2) under it. Where the portion's weight is known, a
/// servings | g switch lets the amount be given in grams (`inGrams`; the owner converts).
/// Empty while the field is cleared; the host reads the typed value through the binding.
struct QuantityRow: View {
    @Binding var quantity: Double?
    /// "1 egg" / "meal"; omitted while there is nothing to count.
    let unitName: String?
    /// Whether the amount is in grams; nil hides the switch.
    var inGrams: Binding<Bool>? = nil
    var showsQuickAmounts = true

    @State private var text = ""
    @FocusState private var focused: Bool

    private static let quickAmounts: [(String, Double)] = [("¼", 0.25), ("½", 0.5), ("¾", 0.75), ("1", 1), ("1½", 1.5), ("2", 2)]

    private var grams: Bool { inGrams?.wrappedValue ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spaceTight) {
            HStack(spacing: Metrics.spaceInner) {
                Text("Quantity").foregroundStyle(Color.textPrimary)
                Spacer()
                TextField("—", text: $text)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .font(Font.metricNumber)
                    .foregroundStyle(Color.accentGreen)
                    .focused($focused)
                    .accessibilityLabel(grams ? "Grams" : "Quantity")
                    .onChange(of: text) { _, typed in
                        guard focused else { return }
                        quantity = typed.trimmingCharacters(in: .whitespaces).isEmpty ? nil : FoodText.parseAmount(typed)
                    }
                if let inGrams {
                    Picker("Unit", selection: inGrams) {
                        Text(unitName.map(Self.shortUnit) ?? "servings").tag(false)
                        Text("g").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                } else if let unitName {
                    Text("× \(unitName)").foregroundStyle(Color.textSecondary)
                }
            }
            if showsQuickAmounts, !grams {
                HStack(spacing: Metrics.spaceTight) {
                    ForEach(Self.quickAmounts, id: \.0) { label, value in
                        Button {
                            focused = false
                            quantity = value
                            text = FoodText.amount(value)
                        } label: {
                            Text(label)
                                .font(Font.label.weight(.semibold))
                                .foregroundStyle(quantity == value ? Color.background : Color.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .background(quantity == value ? Color.accentGreen : Color.surfaceSunken, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(label) \(unitName ?? "")")
                    }
                }
            }
        }
        .onAppear { text = quantity.map(FoodText.amount) ?? "" }
        // A change from elsewhere (a unit switch, a quick amount) shows unless being typed.
        .onChange(of: quantity) { _, value in
            guard !focused else { return }
            text = value.map(FoodText.amount) ?? ""
        }
    }

    /// "serving (28 g)" reads "serving" on the switch; short units stay as they are.
    static func shortUnit(_ unit: String) -> String {
        let base = unit.components(separatedBy: " (").first ?? unit
        return base.count > 10 ? "servings" : base
    }
}
