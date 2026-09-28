import SwiftUI

/// A Describe line's page (ADR 0001: SwiftUI leaf, values in, closures out; DESIGN.md §7a "a
/// page inside an editor": every edit writes back into the line, with no Save). The name and
/// portion, a `MacroStrip` over the four macro fields, where the numbers came from, and Save
/// as food. A line that failed or is waiting says why, with Try again.
struct DescribeLineForm: View {

    /// Why the line has no Estimate, when it has none.
    let problem: String?
    let onChange: (DescribeLineEdit) -> Void
    let onTryAgain: () -> Void

    @State private var edit: DescribeLineEdit

    init(edit: DescribeLineEdit, problem: String?, onChange: @escaping (DescribeLineEdit) -> Void, onTryAgain: @escaping () -> Void) {
        self.problem = problem
        self.onChange = onChange
        self.onTryAgain = onTryAgain
        _edit = State(initialValue: edit)
    }

    var body: some View {
        Form {
            if let problem {
                Section {
                    Label {
                        Text(problem).foregroundStyle(Color.textPrimary)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.accentCoral)
                    }
                    .formRow()
                    Button("Try again", action: onTryAgain)
                        .formRow()
                } footer: {
                    Text("Or type the macros below and add it as it is.")
                }
            }

            Section {
                HStack(spacing: Metrics.spaceInner) {
                    Text("Name").foregroundStyle(Color.textPrimary)
                    TextField("Name", text: $edit.name)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Color.textPrimary)
                }
                .formRow()
                QuantityRow(quantity: Binding(get: { edit.typedQuantity }, set: { edit.setQuantity($0) }), unitName: nil)
                    .formRow()
                HStack(spacing: Metrics.spaceInner) {
                    Text("Unit").foregroundStyle(Color.textPrimary)
                    TextField("serving", text: $edit.unit)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Color.textSecondary)
                        .textInputAutocapitalization(.never)
                }
                .formRow()
            } footer: {
                Text("Changing the quantity scales the macros below.")
            }

            Section {
                MacroStrip(macros: Macros(typed: Dictionary(uniqueKeysWithValues: Macro.allCases.map { ($0, edit.typed($0)) })))
                    .formRow()
                ForEach(Macro.allCases, id: \.self) { macro in
                    HStack(spacing: Metrics.spaceInner) {
                        IconTile(systemImage: macro.systemImage, tint: macro.accent)
                        Text(macro.title).foregroundStyle(Color.textPrimary)
                        Spacer()
                        TextField("—", value: Binding(get: { edit.typed(macro) }, set: { edit.setMacro(macro, $0) }), format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(Font.metricNumber)
                            .foregroundStyle(macro.accent)
                            .accessibilityLabel(macro.title)
                        Text(macro.unit).foregroundStyle(Color.textSecondary)
                    }
                    .formRow()
                }
            } header: {
                Text("Macros")
            } footer: {
                Text(sourceNote)
            }

            if edit.offersSaveAsFood {
                Section {
                    Toggle("Save as food", isOn: $edit.saveAsFood)
                        .foregroundStyle(Color.textPrimary)
                        .tint(Color.accentGreen)
                        .formRow()
                } footer: {
                    Text("Adding it also puts it in Foods with this portion as its serving, so next time it's one tap.")
                }
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
        .background(Color.background)
        .onChange(of: edit) { _, edit in onChange(edit) }
    }

    /// Where the numbers came from, and what was assumed.
    private var sourceNote: String {
        guard let estimate = edit.estimate else { return "Type the macros for the whole portion." }
        switch estimate.source {
        case .typed: return "Typed by you."
        case .food, .meal: return "From your saved \(estimate.source == .meal ? "meal" : "food"). Changing the macros makes this line your own."
        case .estimated, .lookedUp, .photo, .label:
            return [estimate.source.title + ".", estimate.assumption].filter { !$0.isEmpty }.joined(separator: " ")
        }
    }
}

/// Hosts `DescribeLineForm`, pushed from the Describe tab; the tab owns the line.
final class DescribeLineViewController: UIHostingController<DescribeLineForm> {

    init(line: DescribeLine, problem: String?, onChange: @escaping (DescribeLineEdit) -> Void, onTryAgain: @escaping () -> Void) {
        super.init(rootView: DescribeLineForm(edit: DescribeLineEdit(line), problem: problem, onChange: onChange, onTryAgain: onTryAgain))
        title = line.trimmedText
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }
}
