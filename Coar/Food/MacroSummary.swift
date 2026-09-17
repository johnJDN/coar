import Foundation

/// What the Food tab's summary row shows for a Day (DESIGN.md §8: a thin bar per macro):
/// consumed / target per macro, derived once per render from the Day's Entries and the
/// Target in force on it. With no Target the target slot is `—` and the bar has no fill;
/// nothing is judged against an implied 0 (`.scratch/data-model/issues/02`).
struct MacroSummary: Hashable {

    struct Bar: Hashable {
        let macro: Macro
        /// "1,240": whole numbers with grouping.
        let consumed: String
        /// "2,100", or `—` without a Target.
        let target: String
        /// The share of the target eaten, clamped to 1; nil without a Target.
        let fraction: Double?
    }

    let bars: [Bar]

    init(consumed: Macros, target: Macros?) {
        bars = Macro.allCases.map { macro in
            let eaten = consumed[macro]
            let goal = target.map { $0[macro] }.flatMap { $0 > 0 ? $0 : nil }
            return Bar(
                macro: macro,
                consumed: Self.amountText(eaten),
                target: goal.map(Self.amountText) ?? "—",
                fraction: goal.map { min(max(eaten / $0, 0), 1) }
            )
        }
    }

    /// "1,240": a macro amount as every summary shows it, whole with grouping.
    static func amountText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}
