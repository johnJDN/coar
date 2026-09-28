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

**Status:** ready-for-agent

- [ ] Camera through `UIImagePickerController` (camera) and `PHPickerViewController` (library); the camera usage string added to Info.plist
- [ ] Downscale and encode in memory; nothing written to disk
- [ ] Photo schema: a list of items with `source` (photo | label), name, portion (quantity, unit, grams?) and macros; a label item carries per-serving macros
- [ ] Items are inserted as filled lines, with library handles sent too so a photographed saved food can match (04's rules)
- [ ] While the photo is checked, a placeholder line says "Reading photo…"; a failure turns it into a failed line with retry (the image is kept in memory until the sheet closes)
- [ ] Editing a photo line's text re-estimates it as a typed line (source changes)
- [ ] Tests (pure): photo reply parsing (plate with several items, a label, empty result = failed), label quantity scaling
- [ ] Check by hand: a plate photo from the simulator's library and a nutrition label photo; on John's phone at human testing, a real meal
