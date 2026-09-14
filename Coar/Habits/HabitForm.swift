import SwiftUI
import UIKit

/// The new-habit sheet's content (ADR 0001: SwiftUI leaf, values in, closures out). Emoji,
/// name, target amount, and Period; the kind is yes/no until the quantitative ticket adds a
/// selector. Every edit reports the whole draft so the host can enable Save.
struct HabitForm: View {

    struct Draft: Equatable {
        var emoji = ""
        var name = ""
        var targetAmount: Double? = 1
        var period: HabitPeriod = .day

        var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

        /// Saveable: an emoji, a name, and a positive whole target.
        var isComplete: Bool {
            guard let targetAmount else { return false }
            return !emoji.isEmpty && !trimmedName.isEmpty && targetAmount > 0 && targetAmount.rounded() == targetAmount
        }
    }

    let onChange: (Draft) -> Void

    @State private var draft: Draft
    @FocusState private var focus: Field?

    private enum Field {
        case emoji, name
    }

    init(draft: Draft = Draft(), onChange: @escaping (Draft) -> Void) {
        self.onChange = onChange
        _draft = State(initialValue: draft)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: Metrics.spaceInner) {
                    EmojiField(emoji: $draft.emoji)
                        .focused($focus, equals: .emoji)
                        .frame(width: 56, height: 56)
                        .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.radiusInner, style: .continuous))
                        .accessibilityLabel("Emoji")
                    TextField("Name", text: $draft.name)
                        .focused($focus, equals: .name)
                        .font(Font.cardTitle)
                        .foregroundStyle(Color.textPrimary)
                        .submitLabel(.done)
                }
                .formRow()
            } footer: {
                Text("The emoji is the habit's icon everywhere it appears.")
            }

            Section {
                HStack(spacing: Metrics.spaceInner) {
                    Text("Amount").foregroundStyle(Color.textPrimary)
                    Spacer()
                    TextField("1", value: $draft.targetAmount, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(Font.metricNumber)
                        .foregroundStyle(Color.accentGreen)
                        .accessibilityLabel("Target amount")
                }
                .formRow()
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
            } header: {
                Text("Target")
            } footer: {
                Text("A yes/no habit checks in once a day. The target is how many check-ins make a period count.")
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .onChange(of: draft) { _, draft in onChange(draft) }
        .onAppear { focus = draft.emoji.isEmpty ? .emoji : .name }
    }
}

/// A single-emoji field that opens the system emoji keyboard (ADR 0001: UIKit owns text
/// input). Keeps only the last character typed, so the slot always holds one icon.
private struct EmojiField: UIViewRepresentable {

    @Binding var emoji: String

    func makeUIView(context: Context) -> EmojiTextField {
        let field = EmojiTextField()
        field.font = UIFont.preferredFont(forTextStyle: .title1)
        field.textAlignment = .center
        field.tintColor = .clear
        field.placeholder = "🙂"
        field.adjustsFontForContentSizeCategory = true
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed), for: .editingChanged)
        field.setContentHuggingPriority(.required, for: .horizontal)
        return field
    }

    func updateUIView(_ field: EmojiTextField, context: Context) {
        if field.text != emoji { field.text = emoji }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        private let parent: EmojiField
        init(_ parent: EmojiField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            let last = field.text?.last.map(String.init) ?? ""
            if field.text != last { field.text = last }
            parent.emoji = last
        }
    }
}

final class EmojiTextField: UITextField {

    /// Prefers the emoji keyboard when the device has one.
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
    }

    /// An empty identifier stops the keyboard remembering the last language for this field,
    /// so `textInputMode` wins every time.
    override var textInputContextIdentifier: String? { "" }
}

#Preview {
    HabitForm(draft: .init(emoji: "📵", name: "No phone on waking")) { _ in }
}
