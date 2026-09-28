# 04: Your library wins

**What to build:** A line that means one of John's Food Items or Meals uses it: its macros, and
an Entry linked to it through the existing log calls.
- **Exact names** ("protein shake", "2 eggs", "½ post-workout shake") match locally with no
  model call.
- **Looser wording** ("my usual shake") is matched by the text model through short library
  handles. The macros still come from the library, and a handle that doesn't resolve falls
  back to the estimate.
- Filled rows say "Your food" or "Your meal".

Spec: stories 11–12, "Estimating" steps 1 and 3.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Exact local match:
  - normalised text equals an unarchived Food Item or Meal name, with a trailing "s" folded;
  - a leading quantity multiplies the default Serving (or the Meal)
- [ ] Library handles:
  - `f1`, `s1`, `m1` in the text model's prompt, mapped back locally;
  - archived items left out;
  - the prompt stays small (names and Serving names only)
- [ ] The reply schema gains an optional `match: {handle, serving, quantity}`
- [ ] A resolving match wins over the estimate; an unresolved handle is ignored and the estimate stands
- [ ] Log routes library lines through `logEntry(foodItem:serving:quantity:)` / `logEntry(meal:quantity:)`, so "recently used" order updates
- [ ] A Meal that isn't loggable (a line lost its Serving) doesn't match; the line is estimated instead
- [ ] Tests:
  - pure: exact matching (quantity, plural, fractions, archived excluded) and handle mapping (valid, unknown, archived);
  - façade: a library-matched Log links the Entry to the Food Item or Meal
- [ ] Check by hand: "2 eggs" with Eggs saved fills instantly with no request in the Food log; "my usual shake" matches the saved shake
