import SwiftUI
import UIKit

/// `MacroStrip`: the four macros of one thing (a meal, a line of it) as a compact visual
/// rather than a line of text. Four columns side by side, each a number in its macro's
/// accent over a small grey label, and under them a thin bar split by where the calories
/// come from (protein and carbs 4 kcal/g, fat 9). ADR 0001: a SwiftUI leaf, values in.
/// `nil` shows `—` in every slot and an empty bar (DESIGN.md §1.5).
struct MacroStrip: View {

    let macros: Macros?

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spaceTight) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ForEach(Macro.allCases, id: \.self) { macro in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(macros.map { FoodText.amount($0[macro].rounded()) } ?? "—")
                            .font(Font.metricNumber)
                            .monospacedDigit()
                            .foregroundStyle(macros == nil ? Color.textTertiary : macro.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(macro == .calories ? "kcal" : macro.title)
                            .font(Font.label)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            EnergySplitBar(macros: macros)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A 6pt capsule split into protein, fat, and carbs by their share of calories, each in its
/// accent; a `fill` track when there is nothing to split.
struct EnergySplitBar: View {

    let macros: Macros?

    private var shares: [(Macro, Double)] {
        guard let macros else { return [] }
        let energy: [(Macro, Double)] = [(.protein, macros.protein * 4), (.fat, macros.fat * 9), (.carbs, macros.carbs * 4)]
        let total = energy.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return [] }
        return energy.filter { $0.1 > 0 }.map { ($0.0, $0.1 / total) }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(shares, id: \.0) { macro, share in
                    Capsule().fill(macro.accent).frame(width: max(0, geometry.size.width * share - 2))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Capsule().fill(Color.fill))
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

extension FoodText {

    /// "140 kcal · P 12 · F 10 · C 0" with each gram macro, letter and number, in its accent,
    /// so the three read apart at a glance. The one styled form of a macro line; plain
    /// `macroLine` stays for accessibility labels.
    static func styledMacroLine(_ macros: Macros, leading: String? = nil, includesCalories: Bool = true) -> AttributedString {
        var line = AttributedString([leading, includesCalories ? calories(macros) : nil].compactMap { $0 }.joined(separator: " · "))
        for macro in [Macro.protein, .fat, .carbs] {
            if !line.characters.isEmpty { line += AttributedString(" · ") }
            var part = AttributedString("\(macro.abbreviation) \(amount(macros[macro]))")
            // Both scopes: SwiftUI `Text` reads one, UIKit labels the other.
            part.swiftUI.foregroundColor = macro.accent
            part.uiKit.foregroundColor = macro.uiAccent
            line += part
        }
        return line
    }

    /// `styledMacroLine` for UIKit list content.
    static func styledMacroLineUIKit(_ macros: Macros, leading: String? = nil, includesCalories: Bool = true) -> NSAttributedString {
        (try? NSAttributedString(styledMacroLine(macros, leading: leading, includesCalories: includesCalories), including: \.uiKit))
            ?? NSAttributedString(string: macroLine(macros))
    }
}

#Preview {
    VStack(spacing: 24) {
        MacroStrip(macros: Macros(calories: 480, protein: 6, fat: 44, carbs: 24))
        MacroStrip(macros: nil)
    }
    .padding()
    .background(Color.surface)
}
