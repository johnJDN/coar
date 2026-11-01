# 03: Copy entries to another time or Day

**What to build:** John (2026-11-01): select several Food entries and copy them to the same Day
at a different time, or to a different Day.

**Status:** done

- [x] Select (bar, or an entry's menu: Select / Copy to…): check badges on the cards, tap to
      toggle, Cancel and "Copy N to…"
- [x] The sheet: Day, Keep their own times (default on) or one Time, Copy N entries
- [x] Copies keep the snapshot, links to the food or meal, and a meal's parts (ADR 0003); the
      originals stay (`Store.copyEntries`)
- [x] A toast says where; Show goes to that Day
- [x] Tests (2)

## Comments

- 2026-11-01 (agent): Left as deliberate: copying only, no multi-delete or move yet (Delete on
  a selection is easy to add if wanted); the selection clears when the Day changes away from
  its entries.
