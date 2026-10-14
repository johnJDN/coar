import SwiftUI

/// The rows for the Extras an Entry or a Describe line holds (DESIGN.md §7; CONTEXT.md
/// "Extra"): a neutral `IconTile`, the name, an editable number in `textPrimary` (not an
/// accent: these are not macros), and the unit. Only the Extras it is given, so an Entry
/// without any shows no section. A SwiftUI leaf: values in, edits out through the bindings.
struct ExtraRows: View {

    let extras: [Extra]
    let value: (Extra) -> Binding<Double?>

    var body: some View {
        ForEach(extras, id: \.self) { extra in
            HStack(spacing: Metrics.spaceInner) {
                IconTile(systemImage: extra.systemImage, tint: Color.textSecondary)
                Text(extra.title).foregroundStyle(Color.textPrimary)
                Spacer()
                TextField("—", value: value(extra), format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(Font.metricNumber)
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityLabel(extra.title)
                Text(extra.unit).foregroundStyle(Color.textSecondary)
            }
            .formRow()
        }
    }
}
