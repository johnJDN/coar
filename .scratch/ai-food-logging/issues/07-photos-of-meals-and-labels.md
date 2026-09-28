# 07: Photos of meals and nutrition labels

**What to build:** A camera button on the Describe tab with a menu: Take Photo, Choose Photo.
The photo goes to `google/gemini-3.8-flash`, shrunk to 1,024 px as JPEG 0.7, and is never
written to disk.
- **A plate** adds one line per food it sees, marked "From photo".
- **A nutrition label** adds one line read exactly from the label, marked "From label". Its
  Serving is the label's ("1 bar (60 g)"), its quantity is 1, and the line page (05) sets how
  many were eaten.
- Lines from a photo edit, save as food, and log like any other.

Spec: stories 19–21, "Estimating" → Photos.

**Blocked by:** 02, 05

**Status:** done

- [x] Camera through `UIImagePickerController` (camera) and `PHPickerViewController` (library); the camera usage string added to Info.plist
- [x] Downscale and encode in memory; nothing written to disk
- [x] Photo schema: a list of items with `source` (photo | label), name, portion (quantity, unit, grams?) and macros; a label item carries per-serving macros
- [x] Items are inserted as filled lines, with library handles sent too so a photographed saved food can match (04's rules)
- [x] While the photo is checked, a placeholder line says "Reading photo…"; a failure turns it into a failed line with retry (the image is kept in memory until the sheet closes)
- [x] Editing a photo line's text re-estimates it as a typed line (source changes)
- [x] Tests (pure): photo reply parsing (plate with several items, a label, empty result = failed), label quantity scaling
- [x] Check by hand: a plate photo from the simulator's library and a nutrition label photo; on John's phone at human testing, a real meal

## Comments

- 2026-09-27 (agent): Implemented.
  - **The photo model.** `FoodModels.photo` = `google/gemini-3.8-flash`. `FoodPhotoPrompt`
    covers a plate (one item per food, with visible sauces and fat) and a label (one item
    read exactly, per serving, the serving's size in the unit). Its strict schema is
    `{items: [...]}`, derived from the text schema: `source` added, `is_food` and
    `needs_lookup` removed. Saved foods are listed as in 04, so a photographed saved food
    can match.
  - **Estimator.** `FoodEstimator.estimate(photo:library:)` → `[Estimate]`, with a 40 s
    timeout. `Estimate.photoItems(reply:)` parses the reply. `CachingFoodEstimator` passes
    photos through and never caches them.
  - **The image.** `FoodPhoto.jpeg(from:)` shrinks it to 1,024 px on the long edge at
    scale 1, then JPEG 0.7, in memory. Photos are never written to disk.
  - **The draft.** `DescribeDraft.addPhoto()` adds a "Photo" placeholder (`isPhoto`) above
    the trailing empty line. `finishPhoto` replaces it:
    - with one filled line per item, named after it; an impossible item fails alone;
    - no items fails it ("No food or nutrition label found in the photo.");
    - a failed request lands like a typed line's.
    - A placeholder not yet read when the sheet closed or the app quit comes back failed
      ("Photos aren't kept…"), since the image is gone.
  - **The screen.** A camera bar button beside `…` with a menu: Take Photo (disabled where
    there's no camera) and Choose Photo (`PHPickerViewController`, one image, no library
    permission needed).
    - The image is kept in memory by line until it's read, so Try again works.
    - Editing a placeholder's text forgets the photo.
    - The caption reads "Reading photo…".
    - The camera usage string now mentions food and labels.
  - **Tests:** `DescribePhotoTests` (7): plate and label replies, label servings scaling,
    the placeholder replaced above the empty line, no food / failed request / one impossible
    item, a placeholder failing after the sheet closes, the 1,024 px JPEG, and the schema's
    fields all required. Suite green at 316.
  - **The real photo model,** from the Mac, on two Wikimedia Commons images:
    - a roast chicken dinner → roast chicken 360 kcal, gravy 40, broccoli 30, stuffing
      180, as four items, in 6.5 s;
    - a basmati rice label → one "serving (100 g)" item with 350 kcal, P 9, F 1, C 76,
      exactly as printed, in 4.9 s.
  - **Checked in the simulator** (fake estimates):
    - Choose Photo → the picker → "Photo · Reading photo…" → two lines "From photo" and
      the total updated.
    - The simulator now shows its software keyboard (after the reboot for the keyboard
      setting), so typing was checked too: Return opened a line below, "egg" filled in as
      "Your food" two seconds after the last key without losing the caret, and backspace
      on the emptied line removed it and moved focus up.
  - Left as deliberate:
    - no note typed with a photo (fix portions on the lines);
    - a photo line's text is the food's name, and editing it re-estimates it as typed;
    - Take Photo uses the plain system camera.
