# 12: Progress Photos

**What to build:** From Train, a Progress Photos chip opens a grid by Day; add a photo from the camera or the library; pick any two for a side-by-side compare captioned with each photo's Day and the nearest Body Weight. Photos are external-binary attributes so CloudKit syncs them as assets (ADR 0002).

**Blocked by:** 03

**Status:** done

- [x] Grid `UICollectionView` of thumbnails with `radiusInner`, newest first, Day caption
- [x] Add: camera capture or library pick; stored as an external-binary attribute with the local Day
- [x] Compare: select two → two-up screen, each captioned with Day and the Body Weight on the nearest Day (or `—`)
- [x] Delete a photo with confirmation
- [x] Tests (façade): photo Day-keying; nearest-Body-Weight lookup picks the closest Day on either side, `nil` when none

## Comments

- 2026-09-16 (agent): Implemented. Façade (`Store+ProgressPhotos`): `addProgressPhoto(image:thumbnail:on:)`,
  `progressPhotos()` (newest Day first, latest added first within a Day), `progressPhoto(_:)`,
  `progressPhotoImage(_:)` / `progressPhotoThumbnail(_:)` (the listing never touches the bytes),
  `deleteProgressPhoto(_:)`; `Store.bodyWeight(nearest:)` beside `bodyWeight(on:)`, built on a new
  `Day.distance(to:)`. Model (additive): `ProgressPhoto` gained an optional `id: UUID` and an inline
  `thumbnailData` next to the external-binary `imageData`. Encoding: `ProgressPhotoEncoder` redraws the
  picked image as a JPEG capped at 2048 px on the long edge (0.85) plus a 400 px thumbnail (0.7), so
  the grid never decodes a full photo and no EXIF or location metadata reaches the store or iCloud;
  it also reads the EXIF `DateTimeOriginal` of a library pick to key its Day. Picking:
  `ProgressPhotoPicker` wraps `UIImagePickerController` (camera; `NSCameraUsageDescription` added) and
  `PHPickerViewController` (library, no permission needed). UI: the Train chip is live with an
  "n photos" subtitle; `ProgressPhotosViewController` is a 3-column compositional grid of
  `ProgressPhotoCell`s (`radiusInner` squares on `surfaceSunken`, Day caption, "Today" for today),
  subtitle "5 photos · tap two to compare", `+` menu (Take photo / Choose from library), empty-state
  card; `ProgressPhotoCompareViewController` is one card with the two photos side by side in
  portrait wells, each captioned with its Day and the nearest Body Weight in the display unit.
  Verified by rendering the screens in the test host over an in-memory store (grid with a pick,
  compare, single view, empty state, light and dark). Tests: 8 new façade tests (Day-keying across
  zones, newest-first order, byte round-trip, delete, nearest Body Weight either side / tie / none);
  182 pass via
  `xcodebuild -project Coar.xcodeproj -scheme Coar -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test`.
  Left as deliberate: (1) a library photo is dated the Day it was taken when its file carries an
  EXIF date (the camera's wall-clock day is exactly the local Day of ADR 0005), else today; a camera
  capture is today. (2) Photos are re-encoded and capped at 2048 px to keep iCloud quota sane
  (ADR 0002 consequences); metadata is stripped. (3) A second `thumbnailData` attribute rather than
  downsampling `imageData` on every scroll. (4) Compare is pick-two: tapping a thumbnail picks it
  (lavender ring + check), the second pick pushes the two-up at once, picks clear on return; the
  earlier photo is always on the left regardless of pick order. (5) Long-press offers View (the
  photo alone on the compare screen) and Delete (alert, "This cannot be undone"); a photo is deleted
  outright, not archived, since nothing refers to it. (6) Nearest Body Weight prefers the earlier Day
  on a tie; the caption reads "185.3 lbs on Sep 11" when the nearest Day is not the photo's own.
  (7) Take photo is hidden where there is no camera (simulator). (8) Lavender is assigned to
  Progress Photos in DESIGN.md §3 (chip tile and pick ring). (9) `Day.shortText` / `shortTitle`
  became the shared "Sep 13" / "Today" caption; `TrainText.dayText` and the Body Weight caption now
  use it. (10) No caption editing: the `caption` attribute stays unused (the spec calls it optional
  and the ticket does not ask for it).
- 2026-09-16 (agent, after /code-review): `progressPhotos()` now fetches only `id`/`day`/
  `modifiedAt` as rows (the inline thumbnail was being loaded with every fault) and the Train chip
  counts with `progressPhotoCount()` (`context.count(for:)`); Compare tie-breaks same-Day photos by
  `modifiedAt` and decodes each image once (a unit change re-reads only captions);
  `Preferences.observeMassUnit` returns a `MassUnitObservation` token that removes itself, replacing
  the observer + `deinit` block copied across five screens; the picker's three dismissals fold into
  one; `TrainText.dayText` (a pure pass-through to `Day.shortText`) is gone; the delete alert says
  "progress photo"; `ProgressPhotoEncoderTests` (pure) covers the EXIF Day parse (valid, missing,
  malformed) and the 2048 / 400 px caps. Left as deliberate: the chip subtitle "3 photos" and the
  grid subtitle "5 photos · tap two to compare" keep the short noun (the chip and screen are titled
  Progress Photos, so the term is qualified in place; the CONTEXT.md avoid-list guards the domain
  term, not every caption); the pick ring is a 3 pt lavender border (DESIGN §1.1 "no borders" is
  about separating surfaces; this is a selection state, and §3 now names it) rather than a bloom;
  EXIF-dated library picks stay (ADR 0005 keys by the Day the user lived, which for a library photo is
  the Day it was taken, not the Day it was imported); a transparent PNG picked from the library is
  flattened onto black (JPEG has no alpha, body photos never do).
