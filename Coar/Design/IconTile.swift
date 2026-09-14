import SwiftUI

/// `IconTile` (DESIGN.md §7): a pastel rounded square with a white SF Symbol, one soft
/// colour per Settings row.
struct IconTile: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(tint.opacity(0.85), in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: Metrics.spaceTight) {
        IconTile(systemImage: "flame.fill", tint: Color.accentAmber)
        IconTile(systemImage: "scalemass.fill", tint: Color.accentTeal)
        IconTile(systemImage: "heart.fill", tint: Color.accentCoral)
    }
    .padding()
    .background(Color.background)
}
