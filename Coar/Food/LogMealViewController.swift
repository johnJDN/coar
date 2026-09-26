import SwiftUI
import UIKit
import os

/// The Meal log page, pushed from the "+" sheet's Meals segment: set the multiplier, then
/// Add creates one Entry through the façade at the sheet's instant. The `…` menu edits or
/// archives the Meal. Re-reads the Meal on every appearance, so an edit shows at once.
final class LogMealViewController: UIHostingController<LogMealForm> {

    private static let logger = Logger(category: "Food")

    private let dependencies: AppDependencies
    private let mealID: MealRecord.ID
    private let onLogged: () -> Void
    private var draft: LogMealForm.Draft
    private var isLoggable = false
    private let addItem = UIBarButtonItem()

    init(dependencies: AppDependencies, mealID: MealRecord.ID, at instant: Date, onLogged: @escaping () -> Void) {
        self.dependencies = dependencies
        self.mealID = mealID
        self.onLogged = onLogged
        draft = LogMealForm.Draft(loggedAt: instant)
        let placeholder = MealRecord(id: mealID, name: "", isArchived: false, components: [], modifiedAt: Date())
        super.init(rootView: LogMealForm(meal: placeholder, draft: draft) { _ in })

        addItem.primaryAction = UIAction(title: "Add") { [weak self] _ in self?.add() }
        addItem.style = .prominent
        let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { [weak self] _ in self?.pushEditor() }
        let archive = UIAction(title: "Archive", image: UIImage(systemName: "archivebox")) { [weak self] _ in self?.archive() }
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: [edit, archive]))
        more.accessibilityLabel = "More"
        navigationItem.rightBarButtonItems = [addItem, more]
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    // MARK: - Reading

    private func load() {
        do {
            guard let meal = try dependencies.store.meal(mealID) else {
                navigationController?.popViewController(animated: true)
                return
            }
            title = meal.name
            isLoggable = meal.isLoggable
            rootView = LogMealForm(meal: meal, draft: draft, onEditMeal: { [weak self] in self?.pushEditor() }) { [weak self] in self?.draftChanged($0) }
            draftChanged(draft)
        } catch {
            Self.logger.error("Failed to read Meal: \(error, privacy: .public)")
        }
    }

    private func draftChanged(_ draft: LogMealForm.Draft) {
        self.draft = draft
        addItem.isEnabled = draft.quantity != nil && isLoggable
    }

    // MARK: - Actions

    private func add() {
        guard let quantity = draft.quantity, isLoggable else { return }
        do {
            try dependencies.store.logEntry(meal: mealID, quantity: quantity, at: draft.loggedAt)
            onLogged()
        } catch {
            Self.logger.error("Failed to log Entry: \(error, privacy: .public)")
        }
    }

    private func pushEditor() {
        guard let meal = try? dependencies.store.meal(mealID) else { return }
        let editor = MealEditorViewController(dependencies: dependencies, mode: .edit(meal)) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    private func archive() {
        do {
            try dependencies.store.archiveMeal(mealID)
            navigationController?.popViewController(animated: true)
        } catch {
            Self.logger.error("Failed to archive Meal: \(error, privacy: .public)")
        }
    }
}
