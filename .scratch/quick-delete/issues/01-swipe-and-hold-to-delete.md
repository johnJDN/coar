# 01: Swipe or hold a logged food to delete it

**What to build:** Delete (and Save as food) straight from the Food timeline, so an entry
needn't be opened first. John asked for both a swipe and a long press (2026-10-14).

**Status:** done

- [x] Swipe an Entry left: a coral Delete the height of the row; a short swipe leaves it
      showing, a long one (or a fast flick) deletes at once; one row open at a time; a scroll
      or a tap elsewhere closes it
- [x] Press and hold: a menu with Delete, and Save as food when the Entry isn't from a saved
      food or meal and its name isn't in Foods; the row lifts alone, rounded
- [x] Deleting never confirms; an Undo toast (a glass capsule above the tab bar, 7 s) puts the
      Entry back exactly as it was (`Store.restoreEntry`: same id, time, Day, snapshot, Meal
      breakdown, links to its food or meal when they still exist)
- [x] VoiceOver: custom actions Delete and Save as food on each row
- [x] Tests: delete then restore (plain, Food Item, Meal with breakdown, already back)

## Comments

- 2026-10-14 (agent): Implemented and checked in the simulator: swipe reveals Delete, tapping it
  deletes with the Undo toast, Undo restores the Entry and the totals, a full swipe deletes at
  once, and press-and-hold lifts the row with a Delete menu.
  Left as deliberate:
  - **No confirmation** on delete, in exchange for Undo; the entry page's "Delete entry" still
    asks, since it's a deliberate trip.
  - **A custom swipe**, not UIKit's swipe actions: an hour is not a list section, and those
    actions would drag the timeline's rail with the row and stand taller than it. Only the row
    moves.
  - Undo works only while the toast is up (7 s) and on this screen; it re-creates the Entry
    (same id), so a synced device briefly sees it vanish and return.
  - The press-and-hold menu uses the iOS 16 `contextMenuConfigurationForItemsAt`; the older
    single-item method never fired on iOS 26.
  - Not offered on the entry page's own Delete, Meals, or Foods lists.
