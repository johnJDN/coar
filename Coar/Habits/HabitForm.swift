import SwiftUI
import UIKit

/// The new-habit sheet's content (ADR 0001: SwiftUI leaf, values in, closures out). Emoji,
/// name, kind, Period, target amount, and a checklist's Items. Every edit reports the whole
/// draft so the host can enable Save.
struct HabitForm: View {

    struct Draft: Equatable {
        /// The emoji a Habit gets when the slot is left untouched; the slot shows it.
        static let defaultEmoji = "🙂"

        var emoji = ""
        var name = ""
        var target = HabitTargetDraft()
        /// A checklist's Items as typed; one empty row to start.
        var items = [HabitItemDraft()]

        /// The Items to save: the named ones.
        var namedItems: [HabitItemDraft] { items.filter { !$0.trimmedName.isEmpty } }

        var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

        /// The emoji to save: the one typed, or the default the slot shows (a tracked Habit's
        /// metric has its own).
        var resolvedEmoji: String {
            guard emoji.isEmpty else { return emoji }
            return target.kind == .tracked ? target.metric.emoji : Self.defaultEmoji
        }

        /// The name to save: the one typed, or, for a tracked Habit, one made from its goal.
        var resolvedName: String {
            guard trimmedName.isEmpty, target.kind == .tracked, let amount = target.amount else { return trimmedName }
            return target.tracking.defaultName(amount: amount, period: target.period)
        }

        /// Saveable: a name (a tracked Habit can make its own) and a valid target, plus a
        /// checklist's named Item. The emoji always has a value.
        var isComplete: Bool {
            !resolvedName.isEmpty && target.amount != nil && (target.kind != .checklist || !namedItems.isEmpty)
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
                    EmojiField(emoji: $draft.emoji, placeholder: draft.target.kind == .tracked ? draft.target.metric.emoji : Draft.defaultEmoji)
                        .focused($focus, equals: .emoji)
                        .frame(width: 56, height: 56)
                        .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.radiusInner, style: .continuous))
                        .accessibilityLabel("Emoji")
                    TextField(draft.target.kind == .tracked ? (draft.resolvedName.isEmpty ? "Name" : draft.resolvedName) : "Name", text: $draft.name)
                        .focused($focus, equals: .name)
                        .font(Font.cardTitle)
                        .foregroundStyle(Color.textPrimary)
                        .submitLabel(.done)
                }
                .formRow()
            } footer: {
                Text("The emoji is the habit's icon everywhere it appears.")
            }

            HabitTargetSection(draft: $draft.target)

            if draft.target.kind == .checklist {
                HabitItemsSection(items: $draft.items)
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
        .background(Color.background)
        .onChange(of: draft.items) { _, _ in draft.target.itemCount = draft.namedItems.count }
        // A checklist's goal starts as every Item (the empty field); a tracked Habit starts
        // at its metric's usual goal; the other kinds start at 1.
        .onChange(of: draft.target.kind) { old, new in
            if new == .checklist {
                draft.target.typedAmount = nil
            } else if new == .tracked {
                applyDefaults(for: draft.target.metric)
            } else if old == .checklist || old == .tracked {
                draft.target.typedAmount = 1
            }
        }
        .onChange(of: draft.target.metric) { _, metric in applyDefaults(for: metric) }
        .onChange(of: draft) { _, draft in onChange(draft) }
        .onAppear { focus = .name }
    }

    private func applyDefaults(for metric: TrackedMetric) {
        let defaults = metric.defaults
        draft.target.comparison = defaults.comparison
        draft.target.period = defaults.period
        draft.target.typedAmount = defaults.amount
    }
}

/// A checklist's Items as an editable list (ADR 0001: SwiftUI leaf): a row per Item, Add
/// item below, swipe to delete, drag to reorder. Shared by the new-habit sheet and the
/// Edit items sheet.
struct HabitItemsSection: View {

    @Binding var items: [HabitItemDraft]
    /// An extra line under the footer, e.g. how an edit applies.
    var note: String?
    @FocusState private var focused: HabitItemDraft.ID?

    var body: some View {
        Section {
            ForEach($items) { $item in
                TextField("Item", text: $item.name)
                    .focused($focused, equals: item.id)
                    .foregroundStyle(Color.textPrimary)
                    .submitLabel(.next)
                    .onSubmit { addItem(after: item.id) }
                    .formRow()
            }
            .onDelete { items.remove(atOffsets: $0) }
            .onMove { items.move(fromOffsets: $0, toOffset: $1) }
            Button {
                addItem(after: items.last?.id)
            } label: {
                Label("Add item", systemImage: "plus")
            }
            .formRow()
        } header: {
            Text("Items")
        } footer: {
            Text(["Each one is ticked off on its own, for example a friend to text or a supplement to take. Swipe to delete; hold and drag to reorder.", note].compactMap { $0 }.joined(separator: " "))
        }
    }

    /// Adds an empty row after `id` (at the end without one) and moves the cursor into it.
    private func addItem(after id: HabitItemDraft.ID?) {
        let item = HabitItemDraft()
        let index = id.flatMap { id in items.firstIndex { $0.id == id } }.map { $0 + 1 } ?? items.endIndex
        items.insert(item, at: index)
        focused = item.id
    }
}

/// A single-emoji field that opens the system emoji keyboard (ADR 0001: UIKit owns text
/// input). Keeps only the last character typed, so the slot always holds one icon.
private struct EmojiField: UIViewRepresentable {

    @Binding var emoji: String
    var placeholder = HabitForm.Draft.defaultEmoji

    func makeUIView(context: Context) -> EmojiTextField {
        let field = EmojiTextField()
        field.font = UIFont.preferredFont(forTextStyle: .title1)
        field.textAlignment = .center
        field.tintColor = .clear
        field.placeholder = placeholder
        field.adjustsFontForContentSizeCategory = true
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed), for: .editingChanged)
        field.setContentHuggingPriority(.required, for: .horizontal)
        return field
    }

    func updateUIView(_ field: EmojiTextField, context: Context) {
        if field.text != emoji { field.text = emoji }
        if field.placeholder != placeholder { field.placeholder = placeholder }
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

extension HabitForm.Draft {
    /// A new one of `kind`; a tracked one starts at its metric's usual goal.
    init(kind: HabitKind) {
        target.kind = kind
        if kind == .tracked {
            let defaults = target.metric.defaults
            target.comparison = defaults.comparison
            target.period = defaults.period
            target.typedAmount = defaults.amount
        } else if kind == .checklist {
            target.typedAmount = nil
        }
    }
}

#Preview {
    HabitForm(draft: .init(emoji: "📵", name: "No phone on waking")) { _ in }
}
