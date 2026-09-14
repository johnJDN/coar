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

    @State private var calories: Double?
    @State private var protein: Double?
    @State private var fat: Double?
    @State private var carbs: Double?

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
        _calories = State(initialValue: model.target?.calories)
        _protein = State(initialValue: model.target?.protein)
        _fat = State(initialValue: model.target?.fat)
        _carbs = State(initialValue: model.target?.carbs)
    }

    /// The four fields as a Target, or nil while any is empty or negative.
    private var draft: Macros? {
        guard let calories, let protein, let fat, let carbs,
              [calories, protein, fat, carbs].allSatisfy({ $0 >= 0 })
        else { return nil }
        return Macros(calories: calories, protein: protein, fat: fat, carbs: carbs)
    }

    var body: some View {
        Form {
            Section {
                macroRow("Calories", unit: "kcal", systemImage: "flame.fill", tint: Color.accentAmber, value: $calories)
                macroRow("Protein", unit: "g", systemImage: "fish.fill", tint: Color.accentBlue, value: $protein)
                macroRow("Fat", unit: "g", systemImage: "drop.fill", tint: Color.accentPink, value: $fat)
                macroRow("Carbs", unit: "g", systemImage: "leaf.fill", tint: Color.accentOrange, value: $carbs)
                Button("Save targets") {
                    if let draft { onSaveTargets(draft) }
                }
                .disabled(draft == nil || draft == model.target)
                .settingsRow()
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
                .settingsRow()
            }

            Section {
                HStack(spacing: Metrics.spaceInner) {
                    IconTile(systemImage: "heart.fill", tint: Color.accentCoral)
                    Text("Apple Health").foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(healthStatusText)
                        .foregroundStyle(model.healthStatus == nil ? Color.textTertiary : Color.textSecondary)
                }
                .settingsRow()
                if model.healthStatus == .notRequested {
                    Button("Connect Apple Health", action: onConnectHealth)
                        .settingsRow()
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

    private func macroRow(
        _ name: String, unit: String, systemImage: String, tint: Color, value: Binding<Double?>
    ) -> some View {
        HStack(spacing: Metrics.spaceInner) {
            IconTile(systemImage: systemImage, tint: tint)
            Text(name).foregroundStyle(Color.textPrimary)
            Spacer()
            TextField("—", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(Font.metricNumber)
                .foregroundStyle(tint)
                .accessibilityLabel("\(name) target")
            Text(unit)
                .font(Font.label)
                .foregroundStyle(Color.textSecondary)
        }
        .settingsRow()
    }
}

private extension View {
    /// A Settings row: `surface` background, no separator (DESIGN.md §10), label text in
    /// `textPrimary`; buttons keep the tint so they read as tappable.
    func settingsRow() -> some View {
        listRowBackground(Color.surface)
            .listRowSeparator(.hidden)
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
