import SwiftUI

/// `IconTile` (DESIGN.md §7): a pastel rounded square with a white SF Symbol, one soft
/// colour per Settings row. The accent is softened by mixing it toward white (§3: "~85%
/// saturation"), so the tile reads the same on light and dark surfaces.
struct IconTile: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(tint.mix(with: .white, by: 0.15), in: RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: Metrics.spaceTight) {
        IconTile(systemImage: "flame.fill", tint: Color.accentAmber)
        IconTile(systemImage: "scalemass.fill", tint: Color.accentTeal)
        IconTile(systemImage: "heart.fill", tint: Color.accentGreen)
    }
    .padding()
    .background(Color.background)
}
