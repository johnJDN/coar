import Foundation

extension IndexPath {
    /// Where a dragged row may land in a list whose reorderable rows sit at the top of their
    /// section above fixed rows (an "Add …" row): inside that section, at or above
    /// `lastReorderable`. A drag past either end snaps to the nearest allowed slot.
    static func reorderTarget(original: IndexPath, proposed: IndexPath, lastReorderable: Int) -> IndexPath {
        let last = Swift.max(lastReorderable, 0)
        guard proposed.section == original.section, proposed.item <= last else {
            return IndexPath(item: proposed.section < original.section ? 0 : last, section: original.section)
        }
        return proposed
    }
}
