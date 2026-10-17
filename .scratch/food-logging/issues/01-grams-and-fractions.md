# 01: Log by grams and by fractions

**What to build:** John (2026-10-16): he photographs nutrition labels and weighs what he eats;
later he wants to enter the grams, or a fraction of the label's serving. "yes build all four".

**Status:** done

1. [x] **Grams wherever the weight is known.** `QuantityRow` has a servings | g switch when the
       portion's weight is known: a Describe line's page and an Entry's page (through
       `PortionUnit`, which now converts to and from any unit whose weight it knows), and the
       Foods log sheet (the Entry logs as "45 g", macros scaled by grams over the Serving's
       weight; `Store.logEntry(…grams:)`).
2. [x] **Fractions and quick amounts.** Quantity takes "1/3", "1 1/2", "½" (`FoodText.parseAmount`),
       with ¼ ½ ¾ 1 1½ 2 under it (hidden in grams).
3. [x] **"45g granola".** `FoodLibrary.weightMatch`: a saved food's name with a weight before or
       after it is worked out from a Serving whose weight is known, with no model, and logs in
       grams, linked to the food. The model's listing now shows each Serving's weight, with a
       rule for grams of a saved food when the wording is looser.
4. [x] **A grams note on a label photo.** The photo instructions: a weight in the note makes the
       label's item that weight in grams, every number scaled. Live-checked on a generated label
       (55 g serving, 240 cal): "45 g" and "I had 45 grams" gave 45 g, 196 cal, fiber and sodium
       scaled; "half a serving" gave 0.5 serving.

## Comments

- 2026-10-16 (agent): Checked in the simulator: "45g granola" fills in at once (196 cal, Your
  food); Foods → Granola → g → 45 shows 196.4 cal. Left as deliberate:
  - **Label lines stay in the label's serving** until switched (or a note gives grams), so
    Save to Foods keeps the label's serving, weight and all.
  - **Weights need a Serving with a known weight**: a food saved from a label has one; an
    estimated "bowl" usually doesn't, and gets no switch.
  - **Rounded**: grams to whole numbers when switching; servings to two decimals.
  - Lines and entries in grams read "45 g", not "45 × g".
