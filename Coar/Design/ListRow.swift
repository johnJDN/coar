import UIKit

// `ListRow` (DESIGN.md §7) as a list cell: the title in the card-title style over a `label`
// subtitle, on `surface`, with no separator (§10). Shared by the "+" sheet and the editors.
extension UIListContentConfiguration {
    static func listRow() -> UIListContentConfiguration {
        var content = UIListContentConfiguration.subtitleCell()
        content.textProperties.font = UIFont.cardTitle
        content.textProperties.color = UIColor.textPrimary
        content.secondaryTextProperties.font = UIFont.label
        content.secondaryTextProperties.color = UIColor.textSecondary
        content.textToSecondaryTextVerticalPadding = 2
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: Metrics.spaceInner, bottom: 12, trailing: Metrics.spaceInner)
        return content
    }

    /// An "Add …" row at the foot of an editor's list: the title beside a green `+`.
    static func addRow(_ title: String) -> UIListContentConfiguration {
        var content = listRow()
        content.text = title
        content.image = UIImage(systemName: "plus.circle.fill")
        content.imageProperties.tintColor = UIColor.accentGreen
        content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .headline)
        return content
    }
}

extension UIBackgroundConfiguration {
    static func listRow() -> UIBackgroundConfiguration {
        var background = UIBackgroundConfiguration.listCell()
        background.backgroundColor = UIColor.surface
        return background
    }
}
