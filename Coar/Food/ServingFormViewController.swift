import SwiftUI
import UIKit

/// The Serving page, pushed from the Food Item editor. Hosts `ServingForm`. No Save: every
/// change that makes a valid Serving goes straight into the editor's draft
/// (`EditorSaving`), so back is done. Leaving a Serving that is half typed asks first.
final class ServingFormViewController: UIHostingController<ServingForm> {

    private let initial: ServingForm.Draft
    private var draft: ServingForm.Draft
    private let onChange: (ServingDraft) -> Void
    private var backGuard: BackGuard?

    /// `isFirst`: the Food Item has no Serving yet, so this one is the default.
    init(serving: ServingDraft?, isFirst: Bool, onChange: @escaping (ServingDraft) -> Void) {
        var draft = ServingForm.Draft(serving)
        if isFirst { draft.isDefault = true }
        self.initial = draft
        self.draft = draft
        self.onChange = onChange
        super.init(rootView: ServingForm(draft: draft) { _ in })
        rootView = ServingForm(draft: draft) { [weak self] in self?.draftChanged($0) }
        title = serving == nil ? "New Serving" : "Serving"
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        backGuard = BackGuard(controller: self) { [weak self] in
            guard let self, draft.serving == nil, draft != initial else { return .leave }
            return .ask(title: "This serving isn't complete", message: "It needs a name, and its numbers can't be negative. Go back without it?", discard: "Discard")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        backGuard?.refresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backGuard?.release()
    }

    private func draftChanged(_ draft: ServingForm.Draft) {
        self.draft = draft
        if let serving = draft.serving { onChange(serving) }
        backGuard?.refresh()
    }
}
