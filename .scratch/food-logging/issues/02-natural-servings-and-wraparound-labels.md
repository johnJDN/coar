# 02: Natural servings, and labels across several photos

**What to build:** John (2026-10-16): Save to Foods should keep a food's natural serving
("8 crackers", "15 chips", "1 breast") as well as grams, even when the line was typed in grams;
and a nutrition label that wraps around a package doesn't fit in one photo.

**Status:** done

- [x] Every model (typed, lookup, photo) also returns the food's natural serving apart from what
      was eaten: `serving_name`, `serving_grams`, `piece_name` (`ServingSizePrompt`), read into
      `Estimate.servingSize`; "None" and bare weights are dropped in code
- [x] Save to Foods keeps that serving with its weight (the default) and one piece beside it when
      it counts several ("5 crackers" 16 g and "cracker" 3.2 g); the Entry stays exactly as
      logged ("45 g", "10 crackers") (`Estimate.naturalServings`, `Store.logEntrySavingFood(servings:…)`)
- [x] A label reads its household measure as printed ("5 crackers (16 g)", "2/3 cup (55 g)")
- [x] "8 ritz crackers" of a saved food with a piece uses the piece (`FoodLibrary.pieceServing`)
- [x] Up to three photos read together: Choose Photo picks up to three (in order); Take Photo's
      "Anything to add?" has Add another photo; the model is told they're parts of one label or
      views of one meal
- [x] Tests (9)

## Comments

- 2026-10-16 (agent): Live checks (`../typed-lines/`): "45g ritz crackers" 225 cal with serving
  "5 crackers" 16 g, piece "cracker"; "10 ritz crackers" 160 cal; "150g cooked chicken breast"
  248 cal with "1 breast" 172 g; "30g lays" "about 15 chips" 28 g; salmon "1 fillet", yogurt
  "3/4 cup". Photos: a generated cracker label split across two images read as one item (name
  and carbs from one, calories, fat and sodium from the other); "45 g" → 225 cal; "8 crackers" →
  128 cal. The instructions went through three rounds: the first wording made "10 crackers"
  come back as 5, the second made saved-food matching too eager ("pho but no noodles" matched
  the saved Pho) and split the malatang bowl. The final wording says the fields never change
  anything else, with two worked examples. Typed-line check 26/27, size/split 17/17. Left as
  deliberate:
  - **A plain food's natural serving is a typical one** (a breast about 170 g); weigh to be exact.
  - **The piece serving is only for counted foods** ("5 crackers"), not "2/3 cup".
  - **Take another photo only from the camera**; from the library, pick up to three at once.
  - Not tried on a real wrapped package; the generated label was split top and bottom.
