import SwiftUI

/// `DotMatrix` (DESIGN.md §7): a grid of dots, one per unit, filled in the metric's accent
/// with bloom (§1.3, §6) and unfilled in `surfaceSunken`. The dots keep a fixed size and
/// spread evenly across the width; a second row keeps the first row's columns. A SwiftUI
/// leaf: values in, nothing out (ADR 0001); the header (icon, value) is the owner's.
struct DotMatrix: View {

    struct Model: Equatable {
        var total: Int
        var filled: Int
        var columns: Int
        var accent: Color
    }

    let model: Model

    @Environment(\.colorScheme) private var colorScheme

    static let dotSize: CGFloat = 9
    private static let rowSpacing: CGFloat = 7

    private var rows: Int {
        Self.rowCount(of: model)
    }

    static func rowCount(of model: Model) -> Int {
        Int((Double(model.total) / Double(max(1, model.columns))).rounded(.up))
    }

    /// The grid's height, for a UIKit host to pin: a hosted SwiftUI view in a stack view
    /// is not re-measured when its configuration changes, so a grid that grows a row would
    /// otherwise draw over the content above it.
    static func height(of model: Model) -> CGFloat {
        let rows = rowCount(of: model)
        return rows == 0 ? 0 : CGFloat(rows) * dotSize + CGFloat(rows - 1) * rowSpacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<model.columns, id: \.self) { column in
                        let index = row * model.columns + column
                        Group {
                            if index < model.total {
                                dot(filled: index < model.filled)
                            } else {
                                Color.clear.frame(width: Self.dotSize, height: Self.dotSize)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .animation(.easeIn(duration: Elevation.bloomFade), value: model)
        .accessibilityHidden(true)
    }

    private func dot(filled: Bool) -> some View {
        Circle()
            .fill(filled ? model.accent : Color.surfaceSunken)
            .frame(width: Self.dotSize, height: Self.dotSize)
            .shadow(
                color: filled ? model.accent.opacity(Elevation.bloomOpacity(for: colorScheme == .dark ? .dark : .light)) : .clear,
                radius: 4
            )
    }
}

#Preview("Protein") {
    DotMatrix(model: .init(total: 36, filled: 28, columns: 18, accent: Color.accentBlue))
        .padding()
        .background(Color.surface)
}

#Preview("Fat") {
    DotMatrix(model: .init(total: 12, filled: 8, columns: 12, accent: Color.accentPink))
        .padding()
        .background(Color.surface)
}
