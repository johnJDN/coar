import SwiftUI
import UIKit

/// A Meal line's page, pushed from the Meal editor (or in place of the Food Item picker for
/// a new line). Hosts `MealComponentForm`. No Save: the line goes into the editor's draft
/// as it changes (`EditorSaving`); a new line is added the moment its page opens, on the
/// default Serving, one of it. Leaving with the quantity empty asks first.
final class MealComponentFormViewController: UIHostingController<MealComponentForm> {

    private var draft: MealComponentForm.Draft
    private let servings: [ServingRecord]
    private let isNew: Bool
    private let onChange: (MealComponentDraft) -> Void
    private var backGuard: BackGuard?

    /// `component` is the line being edited, or nil for a new line of `foodItem`.
    init(foodItem: FoodItemRecord, component: MealComponentDraft?, onChange: @escaping (MealComponentDraft) -> Void) {
        servings = foodItem.servings
        isNew = component == nil
        let servingID = component?.servingID ?? foodItem.defaultServing?.id
        draft = MealComponentForm.Draft(
            id: component?.id ?? UUID(),
            foodItemID: foodItem.id,
            servingID: foodItem.serving(servingID)?.id ?? foodItem.defaultServing?.id,
            typedQuantity: component?.quantity ?? 1
        )
        self.onChange = onChange
        super.init(rootView: MealComponentForm(servings: servings, draft: draft) { _ in })
        rootView = MealComponentForm(servings: servings, draft: draft) { [weak self] in self?.draftChanged($0) }
        title = foodItem.name
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        backGuard = BackGuard(controller: self) { [weak self] in
            guard let self, draft.component(among: servings) == nil else { return .leave }
            return .ask(title: "This line isn't complete", message: "It needs a serving and a quantity. Go back without these changes?", discard: "Discard Changes")
        }
        if isNew, let component = draft.component(among: servings) { onChange(component) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        backGuard?.refresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backGuard?.release()
    }

    private func draftChanged(_ draft: MealComponentForm.Draft) {
        self.draft = draft
        if let component = draft.component(among: servings) { onChange(component) }
        backGuard?.refresh()
    }
}
