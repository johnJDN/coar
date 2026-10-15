# 01: Sizes, splitting, suggestions, photo notes

**What to build:** `../spec.md` items 1, 2, 4, 5.

**Status:** done

- [x] Size rule in the typed-line library prompt; live-checked
- [x] `parts` in the typed-line schema; `ReplyError.severalFoods`; `DescribeDraft.split`; the
      screen sends each new line
- [x] `FoodLibrary.suggestions(for:)`; `SuggestionBar` as the line field's input accessory
- [x] `estimate(photo:note:library:)`; "Anything to add?" alert; the photo prompt's note rule
- [x] Tests (8) and the live prompt check

## Comments

- 2026-10-14 (agent): Checked in the simulator: "2 eg" offers Eggs and "Eggs & rice"; picking
  Eggs fills "2 Eggs · Your food" at once. Choosing a photo asks "Anything to add?" and reads it
  with the note. The split isn't visible with fake estimates (only the real model sends parts).
  Left as deliberate:
  - **Scaling is a rule of thumb** (large 1.5, small 0.75); the line shows it, and a saved
    serving for the size always wins.
  - **A split line's parts are sent as the model wrote them** ("eggs", not "2 eggs" when you
    didn't say); each keeps the line's Save to Foods choice.
  - **Suggestions start at two letters** and show at most four, most recently used first;
    nothing once the line already is a name.
  - **The note is asked every time** you add a photo, but Read photo with it empty is one tap.
    Cancel drops the photo.
  - The photo note wasn't tried against the real model.
