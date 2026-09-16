import SwiftUI

/// The Exercise sheet's content (ADR 0001: SwiftUI leaf, values in, closures out): the name,
/// the Muscle Group from the fixed list, optional equipment, and an optional rest default.
/// Every edit reports the whole draft so the host can enable Save.
struct ExerciseForm: View {

    struct Draft: Equatable {
        var name = ""
        var muscleGroup: MuscleGroup = .chest
        var equipment = ""
        /// As typed; nil while empty.
        var restSeconds: Int?

        init() {}

        init(_ exercise: ExerciseRecord) {
            name = exercise.name
            muscleGroup = exercise.muscleGroup
            equipment = exercise.equipment ?? ""
            restSeconds = exercise.restSeconds
        }

        var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

        /// Saveable: a name, and a rest of at least a second when one is given.
        var isComplete: Bool {
            !trimmedName.isEmpty && (restSeconds.map { $0 > 0 } ?? true)
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
            } footer: {
                Text("Volume is counted by muscle group.")
            }

            Section {
                TextField("Equipment", text: $draft.equipment, prompt: Text("Barbell, dumbbells, cable"))
                    .foregroundStyle(Color.textPrimary)
                    .submitLabel(.done)
                    .formRow()
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
                    Text("Archived exercises leave the picker. Plans and workouts that use them keep them.")
                }
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .onChange(of: draft) { _, draft in onChange(draft) }
        .onAppear { nameFocused = draft.name.isEmpty }
    }
}

#Preview {
    ExerciseForm(draft: .init(), canArchive: true, onChange: { _ in }, onArchive: {})
}
