import SwiftUI
import UIKit
import os

/// The log page, pushed from the "+" sheet: pick a Serving and a quantity, then Add creates
/// the Entry through the façade at the sheet's instant. The `…` menu edits or archives the
/// Food Item. Re-reads the Food Item on every appearance, so an edit shows at once.
final class LogFoodViewController: UIHostingController<LogFoodForm> {

    private static let logger = Logger(category: "Food")

    private let dependencies: AppDependencies
    private let foodItemID: FoodItemRecord.ID
    private let onLogged: () -> Void
    private var draft: LogFoodForm.Draft
    private let addItem = UIBarButtonItem()

    init(dependencies: AppDependencies, foodItemID: FoodItemRecord.ID, at instant: Date, onLogged: @escaping () -> Void) {
        self.dependencies = dependencies
        self.foodItemID = foodItemID
        self.onLogged = onLogged
        draft = LogFoodForm.Draft(servingID: UUID(), loggedAt: instant)
        super.init(rootView: LogFoodForm(servings: [], draft: draft) { _ in })

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
            guard let food = try dependencies.store.foodItem(foodItemID), let defaultServing = food.defaultServing else {
                navigationController?.popViewController(animated: true)
                return
            }
            title = food.name
            if !food.servings.contains(where: { $0.id == draft.servingID }) {
                draft.servingID = defaultServing.id
            }
            rootView = LogFoodForm(servings: food.servings, draft: draft) { [weak self] in self?.draftChanged($0) }
            draftChanged(draft)
        } catch {
            Self.logger.error("Failed to read Food Item: \(error, privacy: .public)")
        }
    }

    private func draftChanged(_ draft: LogFoodForm.Draft) {
        self.draft = draft
        addItem.isEnabled = draft.quantity != nil
    }

    // MARK: - Actions

    private func add() {
        guard let quantity = draft.quantity else { return }
        do {
            try dependencies.store.logEntry(foodItem: foodItemID, serving: draft.servingID, quantity: quantity, at: draft.loggedAt)
            onLogged()
        } catch {
            Self.logger.error("Failed to log Entry: \(error, privacy: .public)")
        }
    }

    private func pushEditor() {
        guard let food = try? dependencies.store.foodItem(foodItemID) else { return }
        let editor = FoodItemEditorViewController(dependencies: dependencies, mode: .edit(food)) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    private func archive() {
        do {
            try dependencies.store.archiveFoodItem(foodItemID)
            navigationController?.popViewController(animated: true)
        } catch {
            Self.logger.error("Failed to archive Food Item: \(error, privacy: .public)")
        }
    }
}
