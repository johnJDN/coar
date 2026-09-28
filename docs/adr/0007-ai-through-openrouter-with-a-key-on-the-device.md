# 0007. AI goes through OpenRouter, with the user's key on the device until release

**Status:** accepted (2026-09-27)

## Context

Food logging estimates macros from typed lines and photos (`.scratch/ai-food-logging/`).
That needs models Coar does not ship: a cheap text model for everyday foods, a web-search
model for restaurant and brand foods, and a vision model for photos. The best price for each
job comes from different vendors, and prices move month to month. A model API key cannot
ship inside the app, because anyone can pull it out of the binary. Today Coar has one user.

## Decision

- Every AI request goes to **OpenRouter**. One API and one bill reach Google, Anthropic,
  OpenAI and Perplexity models, so a model is a constant that is cheap to change.
- **For now, the key is the user's own.** It's pasted once in Settings and kept as a
  Keychain generic password on that iPhone:
  - after-first-unlock, this device only, never synced;
  - never logged, and never in Core Data or `UserDefaults`.
  - Settings checks it with OpenRouter before keeping it and shows its spending against its
    limit.
- **Before release, a small server holds the key instead.** The server checks each request
  with App Attest and limits each user. `OpenRouterClient` owns the base URL and where the
  auth comes from, so that change touches one type.

## Considered options

- **Anthropic directly.** One strong vendor, but no cheap search model, and the price
  floor is higher than Gemini Flash-Lite for the everyday lines that are most of the traffic.
  Rejected. Claude models remain reachable through OpenRouter.
- **On-device Foundation Models.** Free and private, but too small to know that a chain's
  burrito bowl is about 1,000 kcal or to judge portions from a photo. Worth revisiting as a
  first pass for plain foods.
- **A server now.** It's the right shape for release, but hosting, App Attest and abuse
  limits are wasted work for one user. Deferred.

## Consequences

- Each person pays for their own usage until the server exists, which suits a single-user
  TestFlight build and doesn't suit a public release.
- OpenRouter adds a small margin and is a single dependency. If it goes away, the client
  moves to another OpenAI-compatible endpoint.
- Tests stub the transport. The real requests are checked by hand.
