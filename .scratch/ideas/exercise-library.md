# Exercise library and tutorials (deferred until closer to release)

Status: parked 2026-09-26 at John's request. Nothing built.

## Sources checked (2026-09-26, primary sources)

| Source | Size | Media | Licence / terms | Notes |
|---|---|---|---|---|
| free-exercise-db (github.com/yuhonas/free-exercise-db) | 876 (584 strength) | 2 JPGs each, **rights not cleared** (scraped; maintainer: "at your own risk") | Data: Unlicense (public domain) | Primary/secondary muscles, equipment, category, level, instructions. Bundle the JSON, drop the images. |
| wger (wger.de/api/v2/exerciseinfo) | 912 | Images on ~273, 78 videos on 46 | Per item CC-BY-SA 4/3, some CC0; code AGPL | Attribution + share-alike; no API key; updated weekly. |
| MuscleWiki API | 1,900+ | 7,700+ videos | Proprietary; $10–200/mo; attribution + watermark; videos stream only; text cache ≤30 days | Most polished demos. |
| ExerciseDB / AscendAPI | 1,500 free, 11k paid | GIFs (v2 videos) | Media licence not stated; URLs rotate weekly | Rights unconfirmed. |
| API Ninjas | "3,000+" | none | Proprietary; free tier non-commercial | Single muscle only. |
| everkinetic/data | 293 | line drawings | CC-BY-SA 4 | Unmaintained since 2022. |

YouTube: linking or embedding the official player (WKWebView / SFSafariViewController) is allowed; downloading or caching video is not.

## Recommendation when picked up

- List: free-exercise-db data (public domain), mapped to Coar's MuscleGroup (+ secondary) and Equipment, bundled offline as a searchable library in the exercise picker; picking copies into the user's catalogue. Consider trimming to ~300 common gym exercises.
- Tutorials: a "How to" button opening a YouTube search per exercise, plus an optional pinned video link per exercise (synced). Later, curated embedded videos for the most-used lifts; MuscleWiki only if a subscription is acceptable.
- Open questions for John: personal-only vs App Store (licensing), in-app video vs opening YouTube, library size, paying for MuscleWiki.
