import SwiftUI
import UIKit
import os

/// The Edit items sheet for a checklist Habit, from its detail. Editing something that
/// exists saves as it changes (DESIGN.md §7a): each edit is written through `setHabitItems`
/// shortly after typing stops and when the sheet closes. A list with no named Item is never
/// written, so the last good list stands.
final class HabitItemsViewController: UIHostingController<HabitItemsForm> {

    private static let logger = Logger(category: "Habits")

    private let dependencies: AppDependencies
    private let habitID: HabitRecord.ID
    private let onChange: () -> Void
    private var items: [HabitItemDraft]
    private var saved: [HabitItemDraft]
    private lazy var autosaver = Autosaver { [weak self] in self?.save() }

    init(dependencies: AppDependencies, habit: HabitRecord, onChange: @escaping () -> Void) {
        self.dependencies = dependencies
        habitID = habit.id
        self.onChange = onChange
        let drafts = habit.items.map { HabitItemDraft(id: $0.id, name: $0.name) }
        items = drafts
        saved = drafts
        super.init(rootView: HabitItemsForm(items: drafts) { _ in })
        rootView = HabitItemsForm(items: drafts) { [weak self] in self?.itemsChanged($0) }
        title = "Edit Items"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        autosaver.flush()
    }

    static func sheet(dependencies: AppDependencies, habit: HabitRecord, onChange: @escaping () -> Void) -> UIViewController {
        HabitItemsViewController(dependencies: dependencies, habit: habit, onChange: onChange).inSheet(detents: [.large()])
    }

    private func itemsChanged(_ items: [HabitItemDraft]) {
        self.items = items
        autosaver.schedule()
    }

    private func save() {
        let named = items.filter { !$0.trimmedName.isEmpty }
        guard !named.isEmpty, named.map(\.trimmedName) != saved.map(\.trimmedName) || named.map(\.id) != saved.map(\.id) else { return }
        do {
            try dependencies.store.setHabitItems(habitID, items: named)
            saved = named
            onChange()
        } catch {
            Self.logger.error("Failed to save Items: \(error, privacy: .public)")
        }
    }
}

/// The Edit items sheet's content (ADR 0001: SwiftUI leaf): the shared Items section.
struct HabitItemsForm: View {

    let onChange: ([HabitItemDraft]) -> Void
    @State private var items: [HabitItemDraft]

    init(items: [HabitItemDraft], onChange: @escaping ([HabitItemDraft]) -> Void) {
        self.onChange = onChange
        _items = State(initialValue: items)
    }

    var body: some View {
        Form {
            HabitItemsSection(items: $items, note: "Changes apply from today; past days keep what was ticked. If the goal was every item, it follows the list.")
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.background)
        .onChange(of: items) { _, items in onChange(items) }
    }
}
