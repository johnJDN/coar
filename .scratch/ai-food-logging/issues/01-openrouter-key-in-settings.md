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

**Status:** ready-for-agent

- [ ] `KeyStore` protocol with a Keychain implementation (generic password, service `com.johnnguyen.coar.openrouter`, `AfterFirstUnlockThisDeviceOnly`, not synchronizable) and an in-memory fake for tests
- [ ] `OpenRouterClient` holds the base URL and the key lookup in one place. Its first call is `GET /api/v1/key`, returning usage, limit and limit reset
- [ ] Settings "AI" section:
  - no key: a paste field and Save;
  - with a key: "•••• a1b2", then "$0.14 of $2 this week" (or "No limit"), then Remove key
- [ ] Save checks the key first:
  - 401 shows "OpenRouter rejected the key" and the key isn't stored;
  - no connection stores it and says "Couldn't check the key: no connection"
- [ ] The key never appears in logs, Core Data, `UserDefaults`, or test output
- [ ] Write `docs/adr/0007-ai-through-openrouter-with-a-key-on-the-device.md`:
  - AI requests go through OpenRouter with the user's key in the Keychain;
  - a server with App Attest and per-user limits replaces it before release;
  - considered: Anthropic direct, on-device Foundation Models, a server now
- [ ] DESIGN.md §11 Settings line and the v1 spec's Settings decision mention the key
- [ ] Tests:
  - `KeyStore` fake round-trip;
  - `/key` reply parsing (limit, no limit, reset period);
  - error mapping (401, 402, offline)
- [ ] Check by hand in the simulator: paste John's key from the pasteboard (`xcrun simctl pbcopy`), and see the usage line and Remove key work
