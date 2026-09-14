import SwiftUI

/// The Settings sheet's content (ADR 0001: SwiftUI leaf, values in, closures out). Exactly
/// three things: macro Targets, the weight unit, and Apple Health access. No iCloud toggle,
/// no name field.
struct SettingsForm: View {

    struct Model: Equatable {
        /// The Target in force today; nil when none has been set yet.
        var target: Macros?
        var massUnit: MassUnit
        /// Nil while the status is being read.
        var healthStatus: HealthAccessStatus?
    }

    let model: Model
    let onSaveTargets: (Macros) -> Void
    let onChangeMassUnit: (MassUnit) -> Void
    let onConnectHealth: () -> Void

    /// The Targets fields as typed; nil where a field is empty.
    @State private var fields: [Macro: Double?]

    init(
        model: Model,
        onSaveTargets: @escaping (Macros) -> Void,
        onChangeMassUnit: @escaping (MassUnit) -> Void,
        onConnectHealth: @escaping () -> Void
    ) {
        self.model = model
        self.onSaveTargets = onSaveTargets
        self.onChangeMassUnit = onChangeMassUnit
        self.onConnectHealth = onConnectHealth
        _fields = State(initialValue: Dictionary(uniqueKeysWithValues: Macro.allCases.map { ($0, model.target?[$0]) }))
    }

    /// The four fields as a Target, or nil while any is empty or negative.
    private var draft: Macros? {
        var macros = Macros(calories: 0, protein: 0, fat: 0, carbs: 0)
        for macro in Macro.allCases {
            guard let value = fields[macro] ?? nil, value >= 0 else { return nil }
            macros[macro] = value
        }
        return macros
    }

    var body: some View {
        Form {
            Section {
                ForEach(Macro.allCases, id: \.self) { macro in
                    macroRow(macro)
                }
                Button("Save targets") {
                    if let draft { onSaveTargets(draft) }
                }
                .disabled(draft == nil || draft == model.target)
                .formRow()
            } header: {
                Text("Targets")
            } footer: {
                Text("Changes apply from today. Past days keep the targets that applied then.")
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
                Text("Coar reads sleep and steps and writes Body Weight. Change access any time in the Health app.")
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .background(Color.background)
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
            healthStatus: .notRequested
        ),
        onSaveTargets: { _ in },
        onChangeMassUnit: { _ in },
        onConnectHealth: {}
    )
}
