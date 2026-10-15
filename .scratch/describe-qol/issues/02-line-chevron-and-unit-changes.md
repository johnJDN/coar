# 02: A chevron on Describe lines; unit changes that keep the macros right

**What to build:** John asked (2026-10-14) whether correcting an AI line is easy. Two gaps:
nothing showed a line opens a page, and changing the Unit only relabelled the macros.

**Status:** done

- [x] Disclosure chevron (`textTertiary`) on filled, failed and waiting lines
- [x] `DescribeLineEdit.setUnit`: g / oz / kg / lb convert by weight when it's known
- [x] Any other unit: a note that the macros are for the old portion, and "Estimate again
      for 1 cup", which re-sends the line as "Pho, 1 cup"; until then the line keeps its last numbers
- [x] Typing a macro accepts the new unit
- [x] Unit field without autocorrect (it turned "cup" into "so")
- [x] Tests (7, `LineUnitTests`)

## Comments

- 2026-10-14 (agent): Checked in the simulator with fake estimates: the chevron shows, the
  note and the green action appear for "cup", and tapping it re-estimates the line. Left as
  deliberate:
  - **Only mass units convert.** Cups, slices and bowls have no fixed weight, so the app asks
    the model again rather than guessing.
  - **An unresolved unit change leaves the line as it was** (old portion and macros, which
    are still right for it) until you estimate again or type a macro.
  - **Grams round to whole numbers, ounces to one decimal** after a conversion.
