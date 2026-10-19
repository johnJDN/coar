import SwiftUI

/// The Settings sheet's content (ADR 0001: SwiftUI leaf, values in, closures out): macro
/// Targets, About me, the weight unit, Apple Health access, the journal folder, and the
/// OpenRouter key (ADR 0007). No iCloud toggle, no name field. There is no Save button for the Targets:
/// every edit reports the draft, and the host saves it when the sheet closes, as iOS
/// Settings does. The key has its own Save, because it is checked with OpenRouter first.
struct SettingsForm: View {

    struct Model: Equatable {
        /// The Target in force today; nil when none has been set yet.
        var target: Macros?
        var massUnit: MassUnit
        /// Nil while the status is being read.
        var healthStatus: HealthAccessStatus?
        var aiKey: AIKey = .missing(problem: nil)
        var aboutMe = AboutMe()
        /// Nil where there's no journal import (tests).
        var journal: JournalImporter.Status?
        /// Nil where there's no reminder (tests).
        var reminder: Reminder?
    }

    /// The nightly reminder's rows.
    struct Reminder: Equatable {
        var isOn: Bool
        /// Minutes after midnight.
        var minute: Int
        /// iOS has Coar's notifications turned off.
        var blocked: Bool
    }

    /// The OpenRouter key's rows. The key itself never reaches the form after it is typed.
    enum AIKey: Equatable {
        /// No key is saved; `problem` says why the last one typed was not.
        case missing(problem: String?)
        /// A typed key is being checked with OpenRouter before it is saved.
        case checking
        /// A key is saved: its last four characters, then its spending once read, or why it
        /// could not be.
        case saved(lastFour: String, spend: String?, problem: String?)
    }

    let model: Model
    let onTargetsChanged: (Macros?) -> Void
    let onChangeMassUnit: (MassUnit) -> Void
    let onConnectHealth: () -> Void
    let onSaveKey: (String) -> Void
    let onRemoveKey: () -> Void
    var onAboutMeChanged: (AboutMe) -> Void = { _ in }
    var onFillAboutMe: () -> Void = {}
    var onChooseJournalFolder: () -> Void = {}
    var onReadJournal: () -> Void = {}
    var onReminderToggled: (Bool) -> Void = { _ in }
    var onReminderTime: (Int) -> Void = { _ in }

    /// The key as it is being pasted; cleared once it is sent to be checked.
    @State private var typedKey = ""
    /// The Targets fields as typed; nil where a field is empty.
    @State private var fields: [Macro: Double?]

    init(
        model: Model,
        onTargetsChanged: @escaping (Macros?) -> Void,
        onChangeMassUnit: @escaping (MassUnit) -> Void,
        onConnectHealth: @escaping () -> Void,
        onSaveKey: @escaping (String) -> Void = { _ in },
        onRemoveKey: @escaping () -> Void = {}
    ) {
        self.model = model
        self.onTargetsChanged = onTargetsChanged
        self.onChangeMassUnit = onChangeMassUnit
        self.onConnectHealth = onConnectHealth
        self.onSaveKey = onSaveKey
        self.onRemoveKey = onRemoveKey
        _fields = State(initialValue: Dictionary(uniqueKeysWithValues: Macro.allCases.map { ($0, model.target?[$0]) }))
    }

    /// The four fields as a Target: an empty field is 0, which the Food tab shows as no
    /// target for that macro (`—`). Nil while every field is empty or any is negative.
    static func draft(from fields: [Macro: Double?]) -> Macros? {
        let values = Macro.allCases.map { fields[$0] ?? nil }
        guard values.contains(where: { $0 != nil }), !values.contains(where: { ($0 ?? 0) < 0 }) else { return nil }
        var macros = Macros(calories: 0, protein: 0, fat: 0, carbs: 0)
        for (macro, value) in zip(Macro.allCases, values) {
            macros[macro] = value ?? 0
        }
        return macros
    }

    var body: some View {
        Form {
            Section {
                ForEach(Macro.allCases, id: \.self) { macro in
                    macroRow(macro)
                }
            } header: {
                Text("Targets")
            } footer: {
                Text("Saved when you close Settings. Changes apply from today; past days keep the targets that applied then. Leave a macro empty for no target.")
            }

            aboutMeSection

            if let reminder = model.reminder {
                reminderSection(reminder)
            }

            Section("Units") {
                HStack(spacing: Metrics.spaceInner) {
                    IconTile(systemImage: "scalemass.fill", tint: Color.accentTeal)
                    Text("Weight").foregroundStyle(Color.textPrimary)
                    Spacer()
                    Picker("Weight unit", selection: Binding(get: { model.massUnit }, set: onChangeMassUnit)) {
                        ForEach(MassUnit.allCases, id: \.self) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                .formRow()
            }

            Section {
                HStack(spacing: Metrics.spaceInner) {
                    IconTile(systemImage: "heart.fill", tint: Color.accentGreen)
                    Text("Apple Health").foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(healthStatusText)
                        .foregroundStyle(model.healthStatus == nil ? Color.textTertiary : Color.textSecondary)
                }
                .formRow()
                if model.healthStatus == .notRequested {
                    Button("Connect Apple Health", action: onConnectHealth)
                        .formRow()
                }
            } header: {
                Text("Apple Health")
            } footer: {
                Text("Coar reads sleep, steps, workouts, overnight heart readings, and About me, and writes Body Weight. Change access any time in the Health app.")
            }

            if let journal = model.journal {
                journalSection(journal)
            }

            Section {
                aiKeyRows
            } header: {
                Text("AI")
            } footer: {
                Text("Estimates food from what you type or photograph. The key stays on this iPhone and is never shown again. Make one at openrouter.ai.")
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
        .background(Color.background)
        .onChange(of: fields) { _, fields in onTargetsChanged(Self.draft(from: fields)) }
    }

    // MARK: - Reminder

    private func reminderSection(_ reminder: Reminder) -> some View {
        Section {
            HStack(spacing: Metrics.spaceInner) {
                IconTile(systemImage: "bell.fill", tint: Color.accentAmber)
                Toggle("Evening reminder", isOn: Binding(get: { reminder.isOn }, set: onReminderToggled))
                    .foregroundStyle(Color.textPrimary)
                    .tint(Color.accentGreen)
            }
            .formRow()
            if reminder.isOn {
                DatePicker("Time", selection: Binding(
                    get: { Calendar.current.date(bySettingHour: reminder.minute / 60, minute: reminder.minute % 60, second: 0, of: Date())! },
                    set: { date in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                        onReminderTime((parts.hour ?? 21) * 60 + (parts.minute ?? 0))
                    }
                ), displayedComponents: .hourAndMinute)
                .foregroundStyle(Color.textPrimary)
                .formRow()
            }
            if reminder.isOn, reminder.blocked {
                problemRow("Notifications are off for Coar. Turn them on in the iPhone's Settings → Notifications → Coar.")
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("A nudge to log the day. It's skipped on days you've already logged food and set mood and energy. Tapping it opens the Day page.")
        }
    }

    // MARK: - Journal

    private func journalSection(_ journal: JournalImporter.Status) -> some View {
        Section {
            HStack(spacing: Metrics.spaceInner) {
                IconTile(systemImage: "book.closed.fill", tint: Color.accentLavender)
                Text("Export folder").foregroundStyle(Color.textPrimary)
                Spacer()
                Text(journal.folderName ?? "Not chosen")
                    .foregroundStyle(journal.folderName == nil ? Color.textTertiary : Color.textSecondary)
            }
            .formRow()
            if journal.folderName != nil {
                Text(Self.journalSummary(journal))
                    .font(Font.label)
                    .foregroundStyle(Color.textSecondary)
                    .formRow()
            }
            if let problem = journal.problem {
                problemRow(problem)
            }
            Button(journal.folderName == nil ? "Choose export folder" : "Choose another folder", action: onChooseJournalFolder)
                .formRow()
            if journal.folderName != nil {
                Button("Read now", action: onReadJournal)
                    .formRow()
            }
        } header: {
            Text("Journal")
        } footer: {
            Text("Export from Journal on your Mac (File → Export) into this iCloud Drive folder whenever you like; each export can replace the last. Coar reads entries from the last \(JournalImporter.days) days on this iPhone, with Apple Intelligence, and keeps only the events for the Day page, not what you wrote.")
        }
    }

    static func journalSummary(_ status: JournalImporter.Status) -> String {
        var parts = ["\(status.read) \(status.read == 1 ? "entry" : "entries") read from the last \(JournalImporter.days) days"]
        if status.waiting > 0 { parts.append("\(status.waiting) waiting") }
        if let checked = status.lastChecked { parts.append("checked \(checked.formatted(.relative(presentation: .named)))") }
        return parts.joined(separator: " · ")
    }

    // MARK: - About me

    private var aboutMeSection: some View {
        Section {
            HStack(spacing: Metrics.spaceInner) {
                IconTile(systemImage: "person.fill", tint: Color.accentBlue)
                if let birth = model.aboutMe.birthDate {
                    DatePicker("Birthday", selection: Binding(get: { birth }, set: { change { $0.birthDate = $1 }($0) }), in: ...Date(), displayedComponents: .date)
                        .foregroundStyle(Color.textPrimary)
                } else {
                    Text("Birthday").foregroundStyle(Color.textPrimary)
                    Spacer()
                    Button("Add") { change { me, _ in me.birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) }(()) }
                }
            }
            .formRow()
            HStack(spacing: Metrics.spaceInner) {
                IconTile(systemImage: "figure.stand", tint: Color.accentBlue)
                Picker("Sex", selection: Binding(get: { model.aboutMe.sex }, set: { change { $0.sex = $1 }($0) })) {
                    Text("Not set").tag(AboutMe.Sex?.none)
                    ForEach(AboutMe.Sex.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                .foregroundStyle(Color.textPrimary)
            }
            .formRow()
            HStack(spacing: Metrics.spaceInner) {
                IconTile(systemImage: "ruler.fill", tint: Color.accentBlue)
                Text("Height").foregroundStyle(Color.textPrimary)
                Spacer()
                heightFields
            }
            .formRow()
            Button("Fill from Apple Health", action: onFillAboutMe)
                .formRow()
        } header: {
            Text("About me")
        } footer: {
            Text(aboutMeFooter)
        }
    }

    private var aboutMeFooter: String {
        let age = model.aboutMe.age().map { "\($0) years old. " } ?? ""
        return age + "Used to estimate what you burn, for the coach and for maintenance calories. Filling from Apple Health only adds what's missing."
    }

    /// Feet and inches with pounds, centimetres with kilograms.
    @ViewBuilder private var heightFields: some View {
        let centimetres = model.aboutMe.heightCentimetres
        if model.massUnit == .pounds {
            let inchesTotal = centimetres.map { $0 / 2.54 }
            let feet = inchesTotal.map { Double(Int($0 / 12)) }
            let inches = inchesTotal.map { ($0 - (feet ?? 0) * 12).rounded() }
            HStack(spacing: 4) {
                numberField("ft", value: feet) { newFeet in change { me, _ in me.heightCentimetres = ((newFeet ?? 0) * 12 + (inches ?? 0)) * 2.54 }(()) }
                Text("ft").foregroundStyle(Color.textSecondary).fixedSize()
                numberField("in", value: inches) { newInches in change { me, _ in me.heightCentimetres = ((feet ?? 0) * 12 + (newInches ?? 0)) * 2.54 }(()) }
                Text("in").foregroundStyle(Color.textSecondary).fixedSize()
            }
        } else {
            HStack(spacing: 4) {
                numberField("cm", value: centimetres.map { $0.rounded() }) { value in change { me, _ in me.heightCentimetres = value }(()) }
                Text("cm").foregroundStyle(Color.textSecondary).fixedSize()
            }
        }
    }

    private func numberField(_ placeholder: String, value: Double?, set: @escaping (Double?) -> Void) -> some View {
        TextField("—", value: Binding(get: { value }, set: set), format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .font(Font.metricNumber)
            .foregroundStyle(Color.accentBlue)
            .frame(minWidth: 28)
            .fixedSize()
            .accessibilityLabel(placeholder)
    }

    /// Applies one change to About me and reports the whole of it.
    private func change<Value>(_ apply: @escaping (inout AboutMe, Value) -> Void) -> (Value) -> Void {
        { value in
            var me = model.aboutMe
            apply(&me, value)
            onAboutMeChanged(me)
        }
    }

    private var healthStatusText: String {
        switch model.healthStatus {
        case nil: return "—"
        case .unavailable: return "Not available"
        case .notRequested: return "Not connected"
        case .connected: return "Connected"
        case .limited: return "Body Weight sharing off"
        }
    }

    @ViewBuilder private var aiKeyRows: some View {
        let tile = IconTile(systemImage: "sparkles", tint: Color.accentLavender)
        switch model.aiKey {
        case .missing(let problem):
            HStack(spacing: Metrics.spaceInner) {
                tile
                SecureField("Paste your OpenRouter key", text: $typedKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit(saveKey)
            }
            .formRow()
            if let problem {
                problemRow(problem)
            }
            Button("Save key", action: saveKey)
                .disabled(trimmedKey.isEmpty)
                .formRow()
        case .checking:
            HStack(spacing: Metrics.spaceInner) {
                tile
                Text("Checking the key…").foregroundStyle(Color.textSecondary)
                Spacer()
                ProgressView()
            }
            .formRow()
        case .saved(let lastFour, let spend, let problem):
            HStack(spacing: Metrics.spaceInner) {
                tile
                Text("OpenRouter key").foregroundStyle(Color.textPrimary)
                Spacer()
                Text("•••• \(lastFour)")
                    .monospaced()
                    .foregroundStyle(Color.textSecondary)
            }
            .formRow()
            HStack {
                Text("Spent").foregroundStyle(Color.textPrimary)
                Spacer()
                Text(spend ?? "—")
                    .foregroundStyle(spend == nil ? Color.textTertiary : Color.textSecondary)
            }
            .formRow()
            if let problem {
                problemRow(problem)
            }
            Button("Remove key", role: .destructive, action: onRemoveKey)
                .formRow()
        }
    }

    private var trimmedKey: String {
        typedKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveKey() {
        guard !trimmedKey.isEmpty else { return }
        onSaveKey(trimmedKey)
        typedKey = ""
    }

    /// A coral warning symbol and caption on the row it is about (DESIGN.md `WarningCard`:
    /// lists flag the item itself).
    private func problemRow(_ problem: String) -> some View {
        Label {
            Text(problem).foregroundStyle(Color.textPrimary)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.accentCoral)
        }
        .font(Font.label)
        .formRow()
    }

    private func macroRow(_ macro: Macro) -> some View {
        HStack(spacing: Metrics.spaceInner) {
            IconTile(systemImage: macro.systemImage, tint: macro.accent)
            Text(macro.title).foregroundStyle(Color.textPrimary)
            Spacer()
            TextField("—", value: Binding(get: { fields[macro] ?? nil }, set: { fields[macro] = $0 }), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(Font.metricNumber)
                .foregroundStyle(macro.accent)
                .accessibilityLabel("\(macro.title) target")
            Text(macro.unit)
                .font(Font.label)
                .foregroundStyle(Color.textSecondary)
        }
        .formRow()
    }
}

#Preview {
    SettingsForm(
        model: .init(
            target: Macros(calories: 2_400, protein: 180, fat: 70, carbs: 260),
            massUnit: .pounds,
            healthStatus: .notRequested,
            aiKey: .saved(lastFour: "a1b2", spend: "$0.14 of $2 this week", problem: nil)
        ),
        onTargetsChanged: { _ in },
        onChangeMassUnit: { _ in },
        onConnectHealth: {}
    )
}
