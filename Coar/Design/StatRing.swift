import SwiftUI

/// `StatRing` (DESIGN.md §7): a circular gauge with a `surfaceSunken` track, an arc in the
/// metric's accent with rounded caps and bloom, and the owner's content in the centre. A nil
/// progress draws the track alone (no target to fill against, §1.5). A SwiftUI leaf: values
/// in, nothing out (ADR 0001).
struct StatRing<Center: View>: View {

    let progress: Double?
    let accent: Color
    var lineWidth: CGFloat = 10
    @ViewBuilder let center: () -> Center

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.surfaceSunken, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress ?? 0)))
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: accent.opacity(Elevation.bloomOpacity(for: colorScheme == .dark ? .dark : .light)), radius: 5)
                .opacity((progress ?? 0) > 0 ? 1 : 0)
            center()
                .padding(lineWidth + 4)
        }
        .padding(lineWidth / 2)
        .animation(.spring(duration: 0.5, bounce: 0), value: progress)
    }
}

#Preview {
    HStack(spacing: 24) {
        StatRing(progress: 0.32, accent: Color.accentAmber) {
            Text("1,420").font(Font.heroNumber).minimumScaleFactor(0.4)
        }
        StatRing(progress: nil, accent: Color.accentAmber) {
            Text("680").font(Font.heroNumber).minimumScaleFactor(0.4)
        }
    }
    .frame(height: 110)
    .padding()
    .background(Color.surface)
}
