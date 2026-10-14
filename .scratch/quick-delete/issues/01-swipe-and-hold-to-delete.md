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
- 2026-10-14 (agent): The same two gestures on the Describe tab's lines (typed, and the
  foods a photo turned into), at John's request. Swipe a line left for Remove (UIKit's own
  swipe, since Describe is a real list; a long swipe removes at once), or press and hold it
  for a Remove menu. Checked in the simulator.
  Left as deliberate:
  - **No confirmation and no Undo** here: a removed line is cheap to type or take again and
    nothing is logged. A photo still being read is let go; its answer finds no line to land
    on (tested), so it doesn't come back.
  - **The last line is emptied, not removed**, as backspace already does; an empty last line
    has nothing to remove, so no swipe or menu.
  - **Press and hold works on the numbers and caption under a food, not on the typed text
    itself**: holding the text is iOS's own text selection and starts editing. The swipe works
    anywhere on the row, with the keyboard up or down; with the keyboard up and a line being
    edited, the menu may not appear, so the swipe is the dependable one.
