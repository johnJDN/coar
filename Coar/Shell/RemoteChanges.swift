import UIKit

extension UIViewController {
    /// Re-renders a screen after a remote-change import (`Store.remoteChangesDidMerge`), so a
    /// screen on show reflects what another device wrote, through the same façade read and
    /// snapshot apply it does on appearance. A screen not on show skips it: its next
    /// `viewWillAppear` reads afresh anyway. Keep the token and remove it in `deinit`.
    func observeRemoteChanges(_ render: @escaping @MainActor () -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: Store.remoteChangesDidMerge, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard self?.viewIfLoaded?.window != nil else { return }
                render()
            }
        }
    }
}
