import SwiftUI

/// The Log past workout sheet's content (ADR 0001: SwiftUI leaf, values in, closures out),
/// also used to edit an Activity or move a past Workout: what it was (a Plan, an empty
/// strength Workout, or an Activity with a name, distance, and notes) and when (start and
/// duration). Every edit reports the whole draft.
struct PastWorkoutForm: View {

    enum Kind: Hashable {
        case strength, activity
    }

    struct Draft: Equatable {
        var kind: Kind = .strength
        /// The Plan to copy; nil for an empty strength Workout.
        var planID: PlanRecord.ID?
        var activityName = ""
        /// In the display unit; nil when empty.
        var distance: Double?
        var notes = ""
        var startedAt: Date
        var minutes = 60

        var trimmedActivityName: String { activityName.trimmingCharacters(in: .whitespacesAndNewlines) }

        /// Saveable: an Activity needs a name; distance, when typed, is not negative.
        var isComplete: Bool {
            switch kind {
            case .strength: return true
            case .activity: return !trimmedActivityName.isEmpty && (distance ?? 0) >= 0
            }
        }
    }

    struct PlanOption: Hashable, Identifiable {
        let id: PlanRecord.ID
        let name: String
    }

    /// Which parts show: creating shows everything; editing an Activity hides the kind;
    /// moving a strength Workout shows only when.
    enum Mode: Equatable {
        case create, editActivity, editTime
    }

    let mode: Mode
    let plans: [PlanOption]
    let activityNames: [String]
    let distanceSymbol: String
    let onChange: (Draft) -> Void

    @State private var draft: Draft

    init(draft: Draft, mode: Mode, plans: [PlanOption] = [], activityNames: [String] = [], distanceSymbol: String, onChange: @escaping (Draft) -> Void) {
        self.mode = mode
        self.plans = plans
        self.activityNames = activityNames
        self.distanceSymbol = distanceSymbol
        self.onChange = onChange
        _draft = State(initialValue: draft)
    }

    var body: some View {
        Form {
            if mode == .create {
                Section {
                    Picker("Kind", selection: $draft.kind) {
                        Text("Strength").tag(Kind.strength)
                        Text("Activity").tag(Kind.activity)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .formRow()
                }
            }
            if mode != .editTime {
                switch draft.kind {
                case .strength: strengthSection
                case .activity: activitySection
                }
            }
            whenSection
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
        .background(Color.background)
        .onChange(of: draft) { _, draft in onChange(draft) }
    }

    private var strengthSection: some View {
        Section {
            Picker("Plan", selection: $draft.planID) {
                Text("Empty workout").tag(PlanRecord.ID?.none)
                ForEach(plans) { plan in
                    Text(plan.name).tag(PlanRecord.ID?.some(plan.id))
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(Color.textPrimary)
            .formRow()
        } footer: {
            Text("Its sets come already ticked. On the next screen, fix any numbers that differ and remove what you skipped.")
        }
    }

    private var activitySection: some View {
        Section {
            TextField("Pickleball, run, basketball…", text: $draft.activityName)
                .font(Font.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .formRow()
            if !activityNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Metrics.spaceTight) {
                        ForEach(activityNames, id: \.self) { name in
                            Button(name) { draft.activityName = name }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(draft.trimmedActivityName == name ? Color.accentGreen : Color.textSecondary)
                        }
                    }
                }
                .formRow()
            }
            HStack(spacing: Metrics.spaceInner) {
                Text("Distance").foregroundStyle(Color.textPrimary)
                Spacer()
                TextField("—", value: $draft.distance, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(Font.metricNumber)
                    .accessibilityLabel("Distance in \(distanceSymbol)")
                Text(distanceSymbol).foregroundStyle(Color.textSecondary)
            }
            .formRow()
            TextField("Notes", text: $draft.notes, axis: .vertical)
                .lineLimit(1...5)
                .foregroundStyle(Color.textPrimary)
                .formRow()
        } header: {
            Text("Activity")
        } footer: {
            Text("Counts as a workout day. Distance and notes are optional.")
        }
    }

    private var whenSection: some View {
        Section("When") {
            DatePicker("Start", selection: $draft.startedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .foregroundStyle(Color.textPrimary)
                .formRow()
            Stepper(value: $draft.minutes, in: 5...600, step: 5) {
                HStack {
                    Text("Duration").foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(TrainText.duration(minutes: draft.minutes))
                        .font(Font.metricNumber)
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .formRow()
        }
    }
}

#Preview {
    PastWorkoutForm(
        draft: .init(kind: .activity, activityName: "Pickleball", startedAt: Date()),
        mode: .create,
        plans: [.init(id: UUID(), name: "Push")],
        activityNames: ["Pickleball", "Run"],
        distanceSymbol: "mi"
    ) { _ in }
}
