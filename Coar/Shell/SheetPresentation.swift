import UIKit

extension UIViewController {
    /// Wraps a screen for presentation as a sheet (DESIGN.md §2): an inline-title navigation
    /// bar, the given detents, and a grabber. Settings and the log sheets share it.
    func inSheet(detents: [UISheetPresentationController.Detent]) -> UIViewController {
        let navigation = UINavigationController(rootViewController: self)
        navigation.navigationBar.prefersLargeTitles = false
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
        }
        return navigation
    }
}
