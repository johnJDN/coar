# Awkward typed lines (2026-10-15)

`typed_check.py`: 27 lines through the real typed-line prompt (with a small saved library)
and the web lookup where the app would make one, each with its own check. Prompted by
John's malatang bowl: one run in three split it into nine lines, and the bowl came out low.

| Run | Prompt | Result | Spend |
|---|---|---|---|
| `run1.json` (2 each) | as of Build 13 | 50/54: a shared or partly eaten chain item ("shared a large fries", "most of a Chipotle burrito") got the whole published label | $0.13 |
| `run2.json` (2 each) | + use every detail (counts, weight, broth, share); a dish listed with its ingredients is one line; lookup scales to the share | 53/54 | $0.11 |
| `run3.json` (1 each) | lookup's share rule reworded as conditional, last | see below | |

Malatang now stays one line (6 of 6 runs) at 590–650 (hand total from John's ~450 g before
broth: ~630–660 with a little broth). Shared fries come out at half (~250), "most of" a
burrito at three quarters (814), a pizza split three ways at a third (700).

Also checked, unchanged: the size/split check (`../describe-qol/prompt_check.py`) 17/17; the
25-line extras test (`../extras/accuracy-test/run4-portions.json`) the same within noise.

**Separate issue, not from these changes:** the Big Mac lookup today usually reads only the
calories from McDonald's page (1 of 6 complete with the old prompt, 0 of 6 with the new), so
the line keeps the model's own estimate (~550–590) without sodium. Search variance on that
page; worth revisiting with a fallback that keeps found calories and estimates the rest.

**Follow-up:** `run3.json` caught "2 pumps vanilla" not being added (both the plain venti oat
latte and the vanilla one at 270). Added drink extras to the "use every detail" rule (syrup
pumps about 20 kcal each, extra shots, toppings, sugar level). Replayed: vanilla 250–270
(published plain ~220), 4 pumps caramel + extra shot 320, taro 25% sugar 280. The plain
latte's own estimate without a lookup runs a little high (270); not chased.
