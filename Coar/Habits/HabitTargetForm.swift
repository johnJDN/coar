import SwiftUI

/// The target fields as typed on the new-habit and change-target sheets: kind, Period, and
/// the amount that makes a Period count. A daily yes/no Habit needs no amount (one Check-in
/// is the day); a checklist's amount is how many of its Items, all of them when left empty.
struct HabitTargetDraft: Equatable {
    var kind: HabitKind = .yesNo
    var period: HabitPeriod = .day
    /// As typed; nil while empty.
    var typedAmount: Double? = 1
    /// A checklist's number of Items, which caps its amount; set by the form.
    var itemCount = 0
    /// A tracked Habit's metric and direction; chosen when creating, fixed afterwards.
    var metric: TrackedMetric = .sleep
    var comparison: HabitComparison = .atLeast

    var tracking: HabitTracking { HabitTracking(metric: metric, comparison: comparison) }

    init(kind: HabitKind = .yesNo, period: HabitPeriod = .day, typedAmount: Double? = 1, itemCount: Int = 0) {
        self.kind = kind
        self.period = period
        self.typedAmount = typedAmount
        self.itemCount = itemCount
    }

    /// Whether the amount field applies.
    var needsAmount: Bool {
        switch kind {
        case .yesNo: return period != .day
        case .tracked: return !(metric.isDayCount && period == .day)
        case .quantitative, .checklist: return true
        }
    }

    /// The valid target amount, or nil while the field is empty or out of range: positive, a
    /// whole number of days for a weekly yes/no Habit and at most 7 of them.
    var amount: Double? {
        guard needsAmount else { return 1 }
        if kind == .checklist {
            guard itemCount > 0 else { return nil }
            guard let typedAmount else { return Double(itemCount) }
            guard typedAmount >= 1, typedAmount.rounded() == typedAmount, typedAmount <= Double(itemCount) else { return nil }
            return typedAmount
        }
        guard let typedAmount, typedAmount > 0, typedAmount.isFinite else { return nil }
        if kind == .tracked {
            switch metric {
            case .workouts, .foodLogged, .weighIns:
                guard typedAmount.rounded() == typedAmount, typedAmount <= 7 else { return nil }
            case .sleep:
                guard typedAmount <= 24 else { return nil }
            case .calories, .protein, .fat, .carbs:
                guard typedAmount <= 500 else { return nil }
            case .steps:
                break
            }
            return typedAmount
        }
        if kind == .yesNo {
            guard typedAmount.rounded() == typedAmount, typedAmount <= 7 else { return nil }
        }
        return typedAmount
    }

    var amountLabel: String {
        switch (kind, period) {
        case (.yesNo, _): return "Days a week"
        case (.quantitative, .day): return "Amount a day"
        case (.quantitative, .week): return "Amount a week"
        case (.checklist, _): return "Items to tick"
        case (.tracked, _):
            switch (metric, period) {
            case (.sleep, .day): return "Hours a night"
            case (.sleep, .week): return "Average hours a night"
            case (.steps, .day): return "Steps a day"
            case (.steps, .week): return "Average steps a day"
            case (.workouts, _), (.foodLogged, _), (.weighIns, _): return "Days a week"
            case (_, .day): return "% of target"
            case (_, .week): return "Average % of target"
            }
        }
    }

    /// What the empty field stands for: `—`, or all of a checklist's Items.
    var amountPlaceholder: String {
        kind == .checklist ? (itemCount > 0 ? "All \(itemCount)" : "All") : "—"
    }

    var footer: String {
        switch (kind, period) {
        case (.yesNo, .day): return "Check in once a day. Every day with a check-in counts."
        case (.yesNo, .week): return "The week counts once you have checked in on this many days."
        case (.quantitative, .day): return "Enter a total each day. The day counts once it reaches this amount."
        case (.quantitative, .week): return "Enter a total each day. The week counts once its days add up to this amount."
        case (.checklist, .day): return "Tick items off one by one; the list starts fresh each day. The day counts once this many are ticked."
        case (.checklist, .week): return "Tick items off one by one; a tick lasts the whole week. The week counts once this many are ticked."
        case (.tracked, _): return trackedFooter
        }
    }

    /// Where a tracked Habit reads from and how a Period is judged.
    private var trackedFooter: String {
        let side = comparison == .atMost ? "at most" : "at least"
        switch metric {
        case .sleep, .steps:
            let what = metric == .sleep ? "sleep" : "steps"
            return period == .day
                ? "Read from Apple Health. Each day counts when its \(what) is \(side) this."
                : "Read from Apple Health. The week counts when its average is \(side) this, over the days that have data."
        case .workouts, .foodLogged, .weighIns:
            let what = metric == .workouts ? "a workout (activities too)" : metric == .foodLogged ? "food logged" : "a Body Weight"
            return period == .day
                ? "Every day needs \(what); a day without is a miss."
                : "The week counts once this many of its days have \(what)."
        case .calories, .protein, .fat, .carbs:
            let base = "Compared with that day's \(metric.title.lowercased()) target; a day with no food logged is a miss."
            return period == .day
                ? "\(base) Each day counts when it is \(side) this share of the target."
                : "\(base) The week counts when its average is \(side) this share."
        }
    }

    /// A sample Habit of this kind and Period, shown while choosing them.
    var example: String {
        switch (kind, period) {
        case (.yesNo, .day): return "For example, “Meditate every day”."
        case (.yesNo, .week): return "For example, “Go to the gym 3 days a week”."
        case (.quantitative, .day): return "For example, “Read 20 pages a day”."
        case (.quantitative, .week): return "For example, “Run 15 miles a week”."
        case (.checklist, .day): return "For example, “Take my 5 supplements”."
        case (.checklist, .week): return "For example, “Text each of these friends”."
        case (.tracked, _): return "Nothing to check in: Coar keeps the streak from data it already has."
        }
    }
}

/// The Target section shared by both sheets (ADR 0001: SwiftUI leaf). The kind selector
/// shows only when a Habit is being created; kind never changes afterwards.
struct HabitTargetSection: View {

    @Binding var draft: HabitTargetDraft
    var showsKind = true
    /// An extra line under the footer, e.g. how a change applies.
    var note: String?

    var body: some View {
        Section {
            if showsKind {
                HStack(spacing: Metrics.spaceInner) {
                    Text("Kind").foregroundStyle(Color.textPrimary)
                    Spacer()
                    Picker("Kind", selection: $draft.kind) {
                        ForEach(HabitKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .formRow()
                if draft.kind == .tracked {
                    HStack(spacing: Metrics.spaceInner) {
                        Text("Track").foregroundStyle(Color.textPrimary)
                        Spacer()
                        Picker("Track", selection: $draft.metric) {
                            ForEach(TrackedMetric.allCases, id: \.self) { metric in
                                Text("\(metric.emoji) \(metric.title)").tag(metric)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .formRow()
                    if !draft.metric.isDayCount {
                        HStack(spacing: Metrics.spaceInner) {
                            Text("Goal").foregroundStyle(Color.textPrimary)
                            Spacer()
                            Picker("Goal", selection: $draft.comparison) {
                                ForEach(HabitComparison.allCases, id: \.self) { comparison in
                                    Text(comparison.title).tag(comparison)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .fixedSize()
                        }
                        .formRow()
                    }
                }
            }
            HStack(spacing: Metrics.spaceInner) {
                Text("Period").foregroundStyle(Color.textPrimary)
                Spacer()
                Picker("Period", selection: $draft.period) {
                    ForEach(HabitPeriod.allCases, id: \.self) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .formRow()
            if draft.needsAmount {
                HStack(spacing: Metrics.spaceInner) {
                    Text(draft.amountLabel).foregroundStyle(Color.textPrimary)
                    Spacer()
                    TextField(draft.amountPlaceholder, value: $draft.typedAmount, format: .number)
                        .keyboardType(draft.kind == .quantitative || (draft.kind == .tracked && draft.metric == .sleep) ? .decimalPad : .numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(Font.metricNumber)
                        .foregroundStyle(Color.accentGreen)
                        .accessibilityLabel(draft.amountLabel)
                }
                .formRow()
            }
        } header: {
            Text("Target")
        } footer: {
            Text([draft.footer, showsKind ? draft.example : nil, note].compactMap { $0 }.joined(separator: " "))
        }
    }
}

/// The change-target sheet's content: Period and amount for an existing Habit. Every edit
/// reports the whole draft so the host can enable Save.
struct HabitTargetForm: View {

    let onChange: (HabitTargetDraft) -> Void

    @State private var draft: HabitTargetDraft

    init(draft: HabitTargetDraft, onChange: @escaping (HabitTargetDraft) -> Void) {
        self.onChange = onChange
        _draft = State(initialValue: draft)
    }

    var body: some View {
        Form {
            HabitTargetSection(draft: $draft, showsKind: false, note: "Applies from today. Past days keep the target that applied then.")
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
        .background(Color.background)
        .onChange(of: draft) { _, draft in onChange(draft) }
    }
}

#Preview {
    HabitTargetForm(draft: .init(kind: .quantitative, period: .day, typedAmount: 20)) { _ in }
}
