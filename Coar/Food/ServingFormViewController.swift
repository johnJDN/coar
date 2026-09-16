import SwiftUI
import UIKit

/// The Serving sheet, pushed from the Food Item editor. Hosts `ServingForm`; Save hands the
/// Serving back to the editor's draft (nothing is written until the Food Item is saved).
final class ServingFormViewController: UIHostingController<ServingForm> {

    private var draft: ServingForm.Draft
    private let onSave: (ServingDraft) -> Void
    private let saveItem = UIBarButtonItem(systemItem: .save)

    /// `isFirst`: the Food Item has no Serving yet, so this one is the default.
    init(serving: ServingDraft?, isFirst: Bool, onSave: @escaping (ServingDraft) -> Void) {
        var draft = ServingForm.Draft(serving)
        if isFirst { draft.isDefault = true }
        self.draft = draft
        self.onSave = onSave
        super.init(rootView: ServingForm(draft: draft) { _ in })
        rootView = ServingForm(draft: draft) { [weak self] in self?.draftChanged($0) }
        title = serving == nil ? "New Serving" : "Serving"
        saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
        saveItem.isEnabled = draft.serving != nil
        navigationItem.rightBarButtonItem = saveItem
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    private func draftChanged(_ draft: ServingForm.Draft) {
        self.draft = draft
        saveItem.isEnabled = draft.serving != nil
    }

    private func save() {
        guard let serving = draft.serving else { return }
        onSave(serving)
        navigationController?.popViewController(animated: true)
    }
}
