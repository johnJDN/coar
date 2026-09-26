import SwiftUI

/// The Exercise sheet's content (ADR 0001: SwiftUI leaf, values in, closures out): the name,
/// the primary Muscle Group and any secondary ones from the fixed list, optional equipment
/// from a menu (or Other, typed), and an optional rest default.
/// Every edit reports the whole draft so the host can enable Save.
struct ExerciseForm: View {

    /// The equipment menu's choice: nothing, a named piece, or Other with typed text.
    enum EquipmentChoice: Hashable {
        case none
        case named(Equipment)
        case other
    }

    struct Draft: Equatable {
        var name = ""
        var muscleGroup: MuscleGroup = .chest
        /// Also works, in the order picked; never the primary group.
        var secondaryMuscleGroups: [MuscleGroup] = []
        var equipmentChoice: EquipmentChoice = .none
        /// Under Other: what it is.
        var otherEquipment = ""
        /// As typed; nil while empty.
        var restSeconds: Int?

        init() {}

        init(_ exercise: ExerciseRecord) {
            name = exercise.name
            muscleGroup = exercise.muscleGroup
            secondaryMuscleGroups = exercise.secondaryMuscleGroups
            switch Equipment.choice(for: exercise.equipment) {
            case nil: equipmentChoice = .none
            case .some(nil): equipmentChoice = .other; otherEquipment = exercise.equipment ?? ""
            case .some(.some(let named)): equipmentChoice = .named(named)
            }
            restSeconds = exercise.restSeconds
        }

        var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

        /// The equipment as stored: the named piece's title, Other's text, or nil.
        var equipment: String? {
            switch equipmentChoice {
            case .none: return nil
            case .named(let named): return named.rawValue
            case .other:
                let typed = otherEquipment.trimmingCharacters(in: .whitespacesAndNewlines)
                return typed.isEmpty ? nil : typed
            }
        }

        /// The secondary groups as saved: the primary one is never also secondary.
        var secondaryGroups: [MuscleGroup] {
            secondaryMuscleGroups.filter { $0 != muscleGroup }
        }

        /// Saveable: a name, and a rest of at least a second when one is given.
        var isComplete: Bool {
            !trimmedName.isEmpty && (restSeconds.map { $0 > 0 } ?? true)
        }

        mutating func toggleSecondary(_ group: MuscleGroup) {
            if let index = secondaryMuscleGroups.firstIndex(of: group) {
                secondaryMuscleGroups.remove(at: index)
            } else {
                secondaryMuscleGroups.append(group)
            }
        }
    }

    /// Whether the Archive action is offered (an existing Exercise).
    let canArchive: Bool
    let onChange: (Draft) -> Void
    let onArchive: () -> Void

    @State private var draft: Draft
    @FocusState private var nameFocused: Bool

    init(draft: Draft, canArchive: Bool, onChange: @escaping (Draft) -> Void, onArchive: @escaping () -> Void) {
        self.canArchive = canArchive
        self.onChange = onChange
        self.onArchive = onArchive
        _draft = State(initialValue: draft)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $draft.name, prompt: Text("Incline dumbbell press"))
                    .font(Font.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .formRow()
                Picker("Muscle group", selection: $draft.muscleGroup) {
                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        Text(group.title).tag(group)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(Color.textPrimary)
                .tint(Color.textSecondary)
                .formRow()
                HStack(spacing: Metrics.spaceInner) {
                    Text("Also works").foregroundStyle(Color.textPrimary)
                    Spacer()
                    Menu {
                        ForEach(MuscleGroup.allCases.filter { $0 != draft.muscleGroup }, id: \.self) { group in
                            Toggle(group.title, isOn: Binding(
                                get: { draft.secondaryMuscleGroups.contains(group) },
                                set: { _ in draft.toggleSecondary(group) }
                            ))
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(draft.secondaryGroups.isEmpty ? "None" : draft.secondaryGroups.map(\.title).joined(separator: ", "))
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "chevron.up.chevron.down").imageScale(.small)
                        }
                        .foregroundStyle(Color.textSecondary)
                    }
                    .menuActionDismissBehavior(.disabled)
                }
                .formRow()
            } footer: {
                Text("Pick the muscle it works most, then any others it also works: dips are Chest, also Triceps and Shoulders.")
            }

            Section {
                Picker("Equipment", selection: $draft.equipmentChoice) {
                    Text("None").tag(EquipmentChoice.none)
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Text(equipment.rawValue).tag(EquipmentChoice.named(equipment))
                    }
                    Text("Other").tag(EquipmentChoice.other)
                }
                .pickerStyle(.menu)
                .foregroundStyle(Color.textPrimary)
                .tint(Color.textSecondary)
                .formRow()
                if draft.equipmentChoice == .other {
                    TextField("Equipment name", text: $draft.otherEquipment, prompt: Text("Landmine, trap bar"))
                        .foregroundStyle(Color.textPrimary)
                        .submitLabel(.done)
                        .formRow()
                }
                HStack(spacing: Metrics.spaceInner) {
                    Text("Rest").foregroundStyle(Color.textPrimary)
                    Spacer()
                    TextField("—", value: $draft.restSeconds, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(Font.metricNumber)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityLabel("Rest in seconds")
                    Text("s").foregroundStyle(Color.textSecondary)
                }
                .formRow()
            } footer: {
                Text("Both optional. The rest timer uses 120 s when an exercise has no default.")
            }

            if canArchive {
                Section {
                    Button("Archive exercise", action: onArchive)
                        .foregroundStyle(Color.accentCoral)
                        .formRow()
                } footer: {
                    Text("Archived exercises can't be added to plans. Plans and workouts that already use them keep them.")
                }
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
        .background(Color.background)
        .onChange(of: draft) { _, draft in onChange(draft) }
        .onAppear { nameFocused = draft.name.isEmpty }
    }
}

#Preview {
    ExerciseForm(draft: .init(), canArchive: true, onChange: { _ in }, onArchive: {})
}
