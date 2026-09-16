import SwiftUI
import UIKit

/// A Meal line's sheet, pushed from the Meal editor (or from the Food Item picker for a new
/// line). Hosts `MealComponentForm`; Save hands the line back to the editor's draft (nothing
/// is written until the Meal is saved).
final class MealComponentFormViewController: UIHostingController<MealComponentForm> {

    private var draft: MealComponentForm.Draft
    private let servings: [ServingRecord]
    private let onSave: (MealComponentDraft) -> Void
    private let saveItem = UIBarButtonItem(systemItem: .save)

    /// `component` is the line being edited, or nil for a new line of `foodItem`; a new line
    /// starts on the default Serving, one of it.
    init(foodItem: FoodItemRecord, component: MealComponentDraft?, onSave: @escaping (MealComponentDraft) -> Void) {
        servings = foodItem.servings
        let servingID = component?.servingID ?? foodItem.defaultServing?.id
        draft = MealComponentForm.Draft(
            id: component?.id ?? UUID(),
            foodItemID: foodItem.id,
            servingID: foodItem.serving(servingID)?.id ?? foodItem.defaultServing?.id,
            typedQuantity: component?.quantity ?? 1
        )
        self.onSave = onSave
        super.init(rootView: MealComponentForm(servings: servings, draft: draft) { _ in })
        rootView = MealComponentForm(servings: servings, draft: draft) { [weak self] in self?.draftChanged($0) }
        title = foodItem.name
        saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
        saveItem.isEnabled = draft.component(among: servings) != nil
        navigationItem.rightBarButtonItem = saveItem
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    private func draftChanged(_ draft: MealComponentForm.Draft) {
        self.draft = draft
        saveItem.isEnabled = draft.component(among: servings) != nil
    }

    private func save() {
        guard let component = draft.component(among: servings) else { return }
        onSave(component)
    }
}
