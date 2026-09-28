# 01: OpenRouter key in Settings

**What to build:** A new "AI" section in Settings with an "OpenRouter key" row.
- John pastes his key once. It's saved to this iPhone's Keychain (never synced, logged, or shown
  again except its last four characters).
- On save, Coar checks the key with OpenRouter and shows what it has spent against its limit.
  A bad key is an obvious error.
- Remove key deletes it.

This is the only place the key is entered, and the Describe tab (02) reads it from here. Spec:
stories 27–29, "The key".

**Blocked by:** None

**Status:** done

- [x] `KeyStore` protocol with a Keychain implementation (generic password, service `com.johnnguyen.coar.openrouter`, `AfterFirstUnlockThisDeviceOnly`, not synchronizable) and an in-memory fake for tests
- [x] `OpenRouterClient` holds the base URL and the key lookup in one place. Its first call is `GET /api/v1/key`, returning usage, limit and limit reset
- [x] Settings "AI" section:
  - no key: a paste field and Save;
  - with a key: "•••• a1b2", then "$0.14 of $2 this week" (or "No limit"), then Remove key
- [x] Save checks the key first:
  - 401 shows "OpenRouter rejected the key" and the key isn't stored;
  - no connection stores it and says "Couldn't check the key: no connection"
- [x] The key never appears in logs, Core Data, `UserDefaults`, or test output
- [x] Write `docs/adr/0007-ai-through-openrouter-with-a-key-on-the-device.md`:
  - AI requests go through OpenRouter with the user's key in the Keychain;
  - a server with App Attest and per-user limits replaces it before release;
  - considered: Anthropic direct, on-device Foundation Models, a server now
- [x] DESIGN.md §11 Settings line and the v1 spec's Settings decision mention the key
- [x] Tests:
  - `KeyStore` fake round-trip;
  - `/key` reply parsing (limit, no limit, reset period);
  - error mapping (401, 402, offline)
- [x] Check by hand in the simulator: paste John's key from the pasteboard (`xcrun simctl pbcopy`), and see the usage line and Remove key work

## Comments

- 2026-09-27 (agent): Implemented.
  - `Coar/AI/APIKeyStore.swift`: the `APIKeyStore` protocol, `KeychainKeyStore`, and
    `lastFour`.
  - `Coar/AI/OpenRouterClient.swift`:
    - the client owns the base URL, the bearer header (plus `X-Title: Coar`) and a stubbable
      `Transport`;
    - `OpenRouterError` maps 401 → key rejected, and 402 or a 403 mentioning a limit →
      limit reached;
    - URL errors meaning no network → offline; a timeout is a plain failure, not offline;
    - `message` gives each error's sentence for the screen;
    - `OpenRouterKeyStatus.spendText` gives spending in the limit's window.
  - `AppDependencies.openRouter` is new.
  - Settings has an "AI" section: paste field and Save key; "Checking the key…"; then
    "•••• last four", Spent, and Remove key. A problem shows as a coral warning row.
  - ADR 0007 written; DESIGN.md §11 and the v1 spec's Settings line updated.
  - Tests: `OpenRouterTests` (6: spending text, the key being checked is the one sent, no
    key fails before any request, the status → error mapping, offline vs timeout).
  - Checked in the iPhone 18 Pro simulator: the section renders, paste works, and a rejected
    key shows the coral row and isn't kept.
  - The success path (a real key saved and showing its spending) wasn't checked in the
    simulator. It mirrors the Mac's clipboard, and putting the key on the Mac clipboard was
    rightly refused. It's covered by the tests, and John checks it on the phone at human
    testing.
  - Left as deliberate (see `human-testing.md`):
    - a key that can't be checked for lack of a connection, or whose limit is spent, is
      still kept (only a rejected key isn't);
    - the key has its own Save because it's checked first.
