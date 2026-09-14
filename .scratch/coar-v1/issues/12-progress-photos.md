# 12: Progress Photos

**What to build:** From Train, a Progress Photos chip opens a grid by Day; add a photo from the camera or the library; pick any two for a side-by-side compare captioned with each photo's Day and the nearest Body Weight. Photos are external-binary attributes so CloudKit syncs them as assets (ADR 0002).

**Blocked by:** 03

**Status:** ready-for-agent

- [ ] Grid `UICollectionView` of thumbnails with `radiusInner`, newest first, Day caption
- [ ] Add: camera capture or library pick; stored as an external-binary attribute with the local Day
- [ ] Compare: select two → two-up screen, each captioned with Day and the Body Weight on the nearest Day (or `—`)
- [ ] Delete a photo with confirmation
- [ ] Tests (façade): photo Day-keying; nearest-Body-Weight lookup picks the closest Day on either side, `nil` when none
