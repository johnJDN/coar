# Extras accuracy test (2026-10-14)

Can the models give fiber, sodium, caffeine, and alcohol without guessing? 25 lines with
labels or USDA values checked against the brands' own sites and FoodData Central (6 packaged,
3 restaurant, 7 caffeine drinks, 5 plain foods, 4 alcohol): `accuracy-test/extras-truth.json`.
The harness mimics the app: Gemini 3.5 Flash-Lite on the typed line, then, when it asks for a
lookup, Gemini reading an Exa search; a lookup that finds nothing leaves the text reading.
Two passes, about $0.30 of the OpenRouter key. Rerun with `accuracy-test/extras_test.py`.

**Right** = within 1 g or 20% (fiber), 30 mg or 15% (sodium), 10 mg or 15% (caffeine), 0.15
drinks (alcohol). A line the brand doesn't publish a value for can't be marked right or wrong.
For caffeine and alcohol, nothing recorded is correct when there is none.

| Extra | Right | Wrong (a number that's off) | Missing (left blank) | Gave a number the brand doesn't publish |
|---|---|---|---|---|
| fiber | 38 | 0 | 4 | 2 |
| sodium | 33 | 1 | 8 | 2 |
| caffeine | 24 | 0 | 2 | 0 |
| alcohol | 48 | 2 | 0 | 0 |

## What it shows

- **Brand and restaurant foods were never confidently wrong.** Where a lookup found the label,
  fiber and sodium were exact (Big Mac 3 g / 1,060 mg, Chick-fil-A 1,470 mg, Quest 12 g / 220
  mg). Where it didn't, it left them blank.
- **Blanks are the cost.** Lookups left sodium blank for Clif, Taco Bell and Diet Coke, and
  caffeine for Red Bull (the lookup found Wikipedia, not Red Bull's page). The text model knew
  most of those (Red Bull 80, Taco Bell 1,200, Diet Coke 40) but also guessed Clif at 200 (label
  130), so filling blanks from it would trade four right for one wrong; not done.
- **One fix came from this test:** with no label found, the text model's fiber and sodium for a
  brand drink were guessed (Celsius sodium 150, label 5). Now a brand or restaurant food that
  needed a lookup and got none keeps its **caffeine and alcohol** (Celsius 200 mg was right,
  and an alcohol estimate states its strength) but **loses fiber and sodium**.
- **Alcohol from a typed beer runs a little high** (Guinness 1.2 to 1.3 vs 1.04; Bud Light
  read 1.0 vs 0.84 in an earlier pass): it assumes a stronger or bigger pour. The line says what
  it assumed, and the entry's page lets you correct it.
- **Plain foods** were right on fiber and close on sodium; grilled chicken's sodium reads 124
  to 130 against USDA's 88, which is a seasoning difference, not a miss.
- Caffeine was right on all 12 drinks it had a value for (Pike Place 315 vs a published
  315 to 390 range).
- Caveat: 25 lines, two passes. The model's read of a messy real meal ("chicken bowl") isn't
  tested here, and for those it should leave fiber and sodium blank.
