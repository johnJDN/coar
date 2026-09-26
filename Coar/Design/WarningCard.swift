import SwiftUI

/// `WarningCard`: something is wrong and blocks what the screen is for, stated where it
/// cannot be missed rather than in a footer. A coral-tinted `surface` card (DESIGN.md
/// `accentCoral`: destructive-adjacent) with a warning symbol, a title, what to do, and
/// optionally the action that fixes it. ADR 0001: a SwiftUI leaf, values in, actions out.
struct WarningCard: View {

    let title: String
    let message: String
    var actionTitle: String?
    var action: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spaceInner) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(Color.accentCoral)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Metrics.spaceTight) {
                Text(title)
                    .font(Font.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Text(message)
                    .font(Font.label)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle {
                    Button(actionTitle, action: action)
                        .buttonStyle(.glassProminent)
                        .tint(Color.accentCoral)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.spaceInner)
        .background(
            RoundedRectangle(cornerRadius: Metrics.radiusInner, style: .continuous)
                .fill(Color.accentCoral.opacity(0.14))
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    WarningCard(title: "This meal can't be logged", message: "A serving one of its foods used was removed.", actionTitle: "Edit meal")
        .padding()
        .background(Color.background)
}
