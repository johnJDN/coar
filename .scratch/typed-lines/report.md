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
