# 01: Timeline entry cards in three fixed rows

**What to build:** John's screenshot (2026-10-14) showed entry cards wrapping unpredictably:
the portion and macros shared one line, so "C 27" or "F 0.3 · C 27" dropped to a second line,
and the calories centred against a two-line name drifted. Option A from the mock, with names
allowed two lines.

**Status:** done

- [x] Row 1: the name (up to two lines) with "105 cal" level with its first line
- [x] Row 2: the portion as said ("1 medium banana", "3 slices", "2 servings (28 g)", "150 g");
      `FoodText.portion` and `plural`
- [x] Row 3: "P 1 · F 0 · C 27" in whole grams (`wholeGrams`); the entry's page keeps decimals
- [x] Tests: the portion wording and the whole-gram line

## Comments

- 2026-10-14 (agent): Checked in the simulator with long names (Bạch Cúc Crunchy Curry Beef
  Jerky, Vietnamese pork sausage): every card is name / portion / macros, calories on the
  name's first line.
  Left as deliberate:
  - A serving named with its own amount keeps the "×" for more than one ("4 × 1 egg"), and so
    does a fraction of a counted thing ("1.5 × cup").
  - Plurals follow simple English rules (slices, glasses, patties, pieces of toast); an
    irregular one would read oddly, and a word already ending in "s" stays.
  - Whole grams on the card only.
