# 02: About me

**Spec:** `../spec.md`

**Status:** done

Age (from date of birth), sex, and height, read from Apple Health's characteristics and height; shown in a new Settings section "About me". Where Health has none, a field to type it, stored in Coar. Used by the coach and later by maintenance calories. Settings' "exactly four things" note becomes five.

## Comments
- 2026-10-16 (agent): Done. Settings → About me: birthday (date picker, age in the footer),
  sex (Female / Male / Other / Not set), height (ft and in with lbs, cm with kg), and "Fill
  from Apple Health", which asks once and fills only empty fields. Stored as one `Profile`
  record (deduped to the latest). Left as deliberate: Coar's copy is the one used; Health is
  a source to fill from, not read every time.
