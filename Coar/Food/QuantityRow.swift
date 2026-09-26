import SwiftUI

/// The "Quantity" row every log and line form shares: the number in `accentGreen` as the
/// metric, "× 1 egg" beside it. Empty while the field is cleared; the host reads the typed
/// value through the binding.
struct QuantityRow: View {
    @Binding var quantity: Double?
    /// "1 egg" / "meal"; omitted while there is nothing to count.
    let unitName: String?
    var body: some View {
        HStack(spacing: Metrics.spaceInner) {
            Text("Quantity").foregroundStyle(Color.textPrimary)
            Spacer()
            TextField("—", value: $quantity, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(Font.metricNumber)
                .foregroundStyle(Color.accentGreen)
                .accessibilityLabel("Quantity")
            if let unitName {
                Text("× \(unitName)").foregroundStyle(Color.textSecondary)
            }
        }
    }
}
