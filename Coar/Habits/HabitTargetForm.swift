import SwiftUI

/// The target fields as typed on the new-habit and change-target sheets: kind, Period, and
/// the amount that makes a Period count. A daily yes/no Habit needs no amount (one Check-in
/// is the day).
struct HabitTargetDraft: Equatable {
    var kind: HabitKind = .yesNo
    var period: HabitPeriod = .day
    /// As typed; nil while empty.
    var typedAmount: Double? = 1

    init(kind: HabitKind = .yesNo, period: HabitPeriod = .day, typedAmount: Double? = 1) {
        self.kind = kind
        self.period = period
        self.typedAmount = typedAmount
    }

    /// Whether the amount field applies.
    var needsAmount: Bool { !(kind == .yesNo && period == .day) }

    /// The valid target amount, or nil while the field is empty or out of range: positive, a
    /// whole number of days for a weekly yes/no Habit and at most 7 of them.
    var amount: Double? {
        guard needsAmount else { return 1 }
        guard let typedAmount, typedAmount > 0, typedAmount.isFinite else { return nil }
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
        }
    }

    var footer: String {
        switch (kind, period) {
        case (.yesNo, .day): return "Check in once a day. Every day with a check-in counts."
        case (.yesNo, .week): return "The week counts once you have checked in on this many days."
        case (.quantitative, .day): return "Enter a total each day. The day counts once it reaches this amount."
        case (.quantitative, .week): return "Enter a total each day. The week counts once its days add up to this amount."
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
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                .formRow()
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
                    TextField("—", value: $draft.typedAmount, format: .number)
                        .keyboardType(draft.kind == .yesNo ? .numberPad : .decimalPad)
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
            Text([draft.footer, note].compactMap { $0 }.joined(separator: " "))
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
        .background(Color.background)
        .onChange(of: draft) { _, draft in onChange(draft) }
    }
}

#Preview {
    HabitTargetForm(draft: .init(kind: .quantitative, period: .day, typedAmount: 20)) { _ in }
}
