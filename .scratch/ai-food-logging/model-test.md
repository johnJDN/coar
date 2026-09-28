# Text model test (2026-09-27)

Which model fills in typed lines. Each model got the app's exact prompt and strict schema
(`FoodEstimatePrompt`), with no catalogue, through OpenRouter, at temperature 0 (OpenAI's
reasoning models don't take one). Everything this session, including the photo and Sonar
trials, cost $0.07 of the key's $2 weekly limit.

**Test set: 22 lines with known answers.**
- 17 plain foods with USDA FoodData Central values ("2 large eggs" 143 kcal, "6 oz grilled
  chicken breast" 281, "1 cup cooked black beans" 227, …).
- 5 chain items with the chains' published US numbers: Big Mac 590, medium fries 320,
  Starbucks grande caffè latte 190, Chick-fil-A chicken sandwich 420, and a Chipotle chicken
  bowl summed from Chipotle's ingredient figures (565).

| Model | Mean kcal error, plain | Worst plain | Mean kcal error, chain | Chain lines flagged for lookup | Median time | ≈ $ per line |
|---|---|---|---|---|---|---|
| google/gemini-3.5-flash-lite | 0.2% | 3% (Greek yogurt) | 2.5% | 5/5 | 1.2 s | 0.0006 |
| google/gemini-3.1-flash-lite | 0.7% | 5% (oatmeal) | 4.9% | 5/5 | 1.7 s | 0.0004 |
| google/gemini-3.8-flash | 0.6% | 8% (Greek yogurt) | 1.0% | 5/5 | 2.5 s | 0.0011 |
| openai/gpt-5-mini | 0.5% | 4% (Greek yogurt) | 6.1% | 5/5 | 7.1 s | 0.0015 |
| openai/gpt-5-nano | 0.7% | 7% (oatmeal) | 11.5% | 5/5 | 13.1 s | 0.0008 |
| anthropic/claude-haiku-4.5 | 3.7% | 36% (baked potato: 103 vs 161) | 5.1% | 5/5 | 2.3 s | 0.0012 |

**Decision:** switch the text model to `google/gemini-3.5-flash-lite`.
- It's the most accurate on plain foods, second on chain foods, and the fastest.
- It costs about $0.0006 a line, against $0.0004 before.
- Chain lines go to Sonar in the app regardless, and every model flagged all five.

**Caveats:**
- These are textbook foods and portions, which every model knows well. Real meals with vague
  portions are where estimates drift, and this test doesn't measure that. John's human-testing
  pass does.
- Cost per line is estimated from list prices and typical token counts, because OpenRouter
  didn't report cost for the Google requests.
- Photos weren't compared across models. Gemini 3.8 Flash read the test label exactly, and its
  plate breakdown was plausible (`issues/07`).
