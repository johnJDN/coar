import Foundation

/// What Home's `DotMatrix` draws for one macro (DESIGN.md §7, §8): one dot per unit of the
/// Target in force, filled by what was eaten. Grams come in 5 g dots and calories in 50 kcal
/// dots, stepping up to a coarser unit when the Target would need more than two rows. With
/// no Target (or a zero one) there is no matrix: the card shows the number with a `— target`
/// caption instead, never dots against an implied 0 (`.scratch/data-model/issues/02`). A
/// pure rule: values in, values out.
struct MacroDots: Hashable {

    /// The most dots a row holds before the matrix wraps to a second row.
    static let maxPerRow = 24
    /// The most dots a matrix holds: two full rows.
    static let maxDots = 2 * maxPerRow

    private static let gramUnits: [Double] = [5, 10, 25, 50, 100]
    private static let kilocalorieUnits: [Double] = [50, 100, 250, 500, 1_000]

    /// How much of the macro one dot stands for, in its unit.
    let unit: Double
    let total: Int
    /// Filled by what was eaten, to the nearest dot; every dot once past the Target.
    let filled: Int

    init?(macro: Macro, consumed: Double, target: Double?) {
        guard let target, target > 0 else { return nil }
        let ladder = macro == .calories ? Self.kilocalorieUnits : Self.gramUnits
        let unit = ladder.first { Int((target / $0).rounded(.up)) <= Self.maxDots } ?? ladder.last!
        let total = max(1, Int((target / unit).rounded(.up)))
        self.unit = unit
        self.total = total
        filled = min(total, max(0, Int((consumed / unit).rounded())))
    }

    /// The rows the dots wrap into, evened out so a second row is never a stray dot.
    var rows: Int { Int((Double(total) / Double(Self.maxPerRow)).rounded(.up)) }

    var columns: Int { Int((Double(total) / Double(rows)).rounded(.up)) }
}
