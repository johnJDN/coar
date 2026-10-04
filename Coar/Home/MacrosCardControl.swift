import SwiftUI
import UIKit

/// Home's macros card (DESIGN.md §8, §11), the first card: a `StatRing` of today's calories
/// against the Target in force with what is left (or over) as the card's one hero number,
/// and beside it a thin bar per gram macro in its fixed accent. With no Target the ring is a
/// bare track around what was eaten, the bars are empty with `g` captions, and a Set targets
/// action opens Settings (`.scratch/data-model/issues/02`). Tapping the card opens Food on
/// today.
final class MacrosCardControl: CardControl {

    var onSetTargets: (() -> Void)?

    private let summary: UIView & UIContentView
    /// The Set targets row, shown only while no Target is in force.
    private let actions = UIStackView()

    init() {
        summary = Self.configuration(HomeSnapshot.placeholder.macros).makeContentView()
        super.init(card: CardView(), interactiveContent: true)

        card.contentStack.addArrangedSubview(summary)
        let setTargets = UIButton.inCardAction(title: "Set targets", systemImage: "target") { [weak self] in self?.onSetTargets?() }
        actions.axis = .horizontal
        actions.addArrangedSubview(setTargets)
        actions.addArrangedSubview(UIView())
        card.contentStack.addArrangedSubview(actions)
        isAccessibilityElement = true
        render(HomeSnapshot.placeholder.macros)
    }

    func render(_ macros: HomeSnapshot.Macros) {
        summary.configuration = Self.configuration(macros)
        actions.isHidden = macros.hasTarget
        accessibilityLabel = MacroRingSummary.accessibilityText(macros)
        accessibilityHint = "Opens Food"
        accessibilityCustomActions = macros.hasTarget ? [] : [UIAccessibilityCustomAction(name: "Set targets") { [weak self] _ in self?.onSetTargets?(); return true }]
    }

    private static func configuration(_ macros: HomeSnapshot.Macros) -> UIHostingConfiguration<MacroRingSummary, EmptyView> {
        UIHostingConfiguration { MacroRingSummary(macros: macros) }.margins(.all, 0)
    }
}

/// The card's content: the calorie ring, then protein, fat, and carbs as labelled bars.
/// Always the same height whatever the values, so the UIKit host never needs re-measuring.
struct MacroRingSummary: View {

    let macros: HomeSnapshot.Macros

    var body: some View {
        HStack(spacing: Metrics.spaceInner) {
            StatRing(progress: macros.calorieProgress, accent: Macro.calories.accent) {
                VStack(spacing: 0) {
                    Text(macros.calories)
                        .font(Font.heroNumber)
                        .monospacedDigit()
                        .foregroundStyle(macros.calories == "—" ? Color.textTertiary : Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                    Text(macros.caloriesCaption)
                        .font(Font.label)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(width: 116, height: 116)

            VStack(spacing: 12) {
                ForEach(macros.bars, id: \.macro) { bar in
                    MacroBarView(bar: bar)
                }
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0), value: macros)
        .accessibilityHidden(true)
    }

    static func accessibilityText(_ macros: HomeSnapshot.Macros) -> String {
        let calories = "Calories, \(macros.calories) \(macros.caloriesCaption)"
        let bars = macros.bars.map { "\($0.macro.title), \($0.consumed) \($0.progress == nil ? "\($0.macro.unit), no target" : "of \($0.target.dropFirst())")" }
        return ([calories] + bars).joined(separator: ". ")
    }
}

/// `Protein  32/180g` over a 6pt bar in the macro's accent with bloom, on a `surfaceSunken`
/// track; an empty track without a Target.
private struct MacroBarView: View {

    let bar: HomeSnapshot.MacroBar

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(bar.macro.title)
                    .foregroundStyle(bar.macro.accent)
                Spacer(minLength: Metrics.spaceTight)
                Text(bar.consumed)
                    .foregroundStyle(Color.textPrimary)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(bar.target)
                    .foregroundStyle(bar.progress == nil ? Color.textTertiary : Color.textSecondary)
                    .monospacedDigit()
            }
            .font(Font.label)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            GeometryReader { geometry in
                Capsule()
                    .fill(Color.surfaceSunken)
                    .overlay(alignment: .leading) {
                        if let progress = bar.progress, progress > 0 {
                            Capsule()
                                .fill(bar.macro.accent)
                                .frame(width: max(6, geometry.size.width * progress))
                                .shadow(color: bar.macro.accent.opacity(Elevation.bloomOpacity(for: colorScheme == .dark ? .dark : .light)), radius: 4)
                        }
                    }
            }
            .frame(height: 6)
        }
    }
}

#Preview {
    MacroRingSummary(macros: HomeSnapshot.Macros(
        calories: "1,420", caloriesCaption: "kcal left", calorieProgress: 0.32,
        bars: [
            .init(macro: .protein, consumed: "32", target: "/180g", progress: 0.18),
            .init(macro: .fat, consumed: "20", target: "/60g", progress: 0.33),
            .init(macro: .carbs, consumed: "88", target: "/210g", progress: 0.42),
        ],
        hasTarget: true
    ))
    .padding()
    .background(Color.surface)
}
