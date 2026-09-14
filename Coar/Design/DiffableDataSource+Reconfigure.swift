import UIKit

extension UICollectionViewDiffableDataSource {
    /// Applies `snapshot`, reconfiguring every item it shares with the current snapshot so a
    /// cell that stays on screen picks up its new content. Always animated once on screen
    /// (DESIGN.md §9).
    func apply(
        reconfiguringExisting snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>,
        animatingDifferences: Bool = true
    ) {
        var snapshot = snapshot
        let existing = Set(self.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter(existing.contains))
        apply(snapshot, animatingDifferences: animatingDifferences)
    }
}
