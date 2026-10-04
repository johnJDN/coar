# Lookup model test (2026-10-03)

Which model looks up a brand or restaurant food's published label (step 4 of "Estimating,
cheapest first" in `spec.md`). Prompted by "kind protein bar strawberry cocoa" coming back as
all zeros from Sonar. Harness, labels and raw replies: `lookup-test/`.

**Test set: 15 lines with labels from the brands' and restaurants' own US sites** (checked
2026-10-03): 8 packaged (KIND Protein MAX Raspberry Cocoa Crisp, Quest, RXBAR, Core Power
Elite, Premier shake, Clif, Chobani, Diet Coke), 5 restaurant (Big Mac, Chick-fil-A sandwich,
grande 2% latte, Crunchwrap Supreme, Panera Bacon Turkey Bravo), and 2 traps that don't exist
("kind protein strawberry cocoa bar", "quest dark chocolate raspberry bar"), each with a near
miss that does.

**Scoring:** right = kcal within 10% (or 10 kcal) and each macro within 10% (or 2 g).
"Not found" = Coar keeps its own estimate (safe). "Wrong" = Coar would show wrong numbers as
"Looked up" (the bad case). A trap is handled when the model says not found.

**Setups.** Sonar keeps Coar's current prompt. The others use a strict schema with three new
fields: `found` (this exact product), `product` (what the numbers are for), `source_url`.
Gemini decides for itself whether to Google and never did under this prompt, so it searched
through OpenRouter's Exa engine (always runs, 5 results, $0.007); GPT and Grok used their own
search. Google requests go through John's own Google key (BYOK), so their cost is Google's.

## Results

Pass 1, all seven:

| Setup | Right | Wrong | Not found | Traps refused | Median time | $ per lookup |
|---|---|---|---|---|---|---|
| sonar (now) | 10/13 | 2 | 1 | 1/2 | 1.6 s | 0.0053 |
| sonar-pro-search | 10/13 | 1 | 2 | 2/2 | 3.9 s | 0.0204 |
| gemini-3.5-flash-lite + Exa | 12/13 | 0 | 1 | 2/2 | 2.9 s | 0.0084 |
| gemini-3.8-flash + Exa | 13/13 | 0 | 0 | 2/2 | 5.1 s | 0.0142 |
| gpt-6-luna + OpenAI search | 13/13 | 0 | 0 | 2/2 | 7.0 s | 0.0238 |
| grok-4.3 + xAI search | 11/13 | 1 | 1 | 2/2 | 7.9 s | 0.0316 |
| gemini-3.5-flash-lite, no search | 10/13 | 3 | 0 | 1/2 | 1.6 s | 0.0006 |

Both passes, the top three:

| Setup | Right | Wrong | Not found | Traps refused |
|---|---|---|---|---|
| gemini-3.8-flash + Exa | 25/26 | 1 (Panera macros) | 0 | 4/4 |
| gpt-6-luna + OpenAI search | 25/26 | 0 | 1 (latte) | 4/4 |
| gemini-3.5-flash-lite + Exa | 24/26 | **0** | 2 (Panera both times) | 4/4 |

Pass 1, line by line (kcal/P/F/C; – = not found):

| Line | Label kcal / P / F / C | sonar (now) | sonar-pro-search | gemini-3.5-flash-lite + Exa | gemini-3.8-flash + Exa | gpt-6-luna + OpenAI search | grok-4.3 + xAI search | gemini-3.5-flash-lite, memory only |
|---|---|---|---|---|---|---|---|---|
| kind protein max raspberry cocoa crisp bar | 240 / 20 / 13 / 24 | ✓ 240/20/13/24 | ✓ 240/20/13/24 | ✓ 240/20/13/24 | ✓ 240/20/13/24 | ✓ 240/20/13/24 | ✓ 240/20/13/24 | ✗ 220/15/12/21 |
| quest cookie dough bar | 190 / 21 / 9 / 22 | ✓ 180/21/7/22 | ✓ 190/21/9/22 | ✓ 190/21/9/22 | ✓ 190/21/9/22 | ✓ 190/21/9/22 | ✓ 190/21/9/22 | ✓ 200/21/9/22 |
| rxbar chocolate sea salt | 200 / 12 / 8 / 23 | ✓ 200/12/9/23 | ✓ 200/12/8/23 | ✓ 200/12/8/23 | ✓ 200/12/8/23 | ✓ 200/12/8/23 | ✓ 200/12/8/23 | ✓ 210/12/7/22 |
| core power elite chocolate | 230 / 42 / 3.5 / 9 | ✗ 230/42/9/10 | ✓ 230/42/3.5/9 | ✓ 230/42/3.5/9 | ✓ 230/42/3.5/9 | ✓ 230/42/3.5/9 | ✓ 230/42/3.5/9 | ✓ 230/42/2.5/10 |
| premier protein chocolate shake | 160 / 30 / 3 / 4 | – | ✓ 160/30/3/4 | ✓ 160/30/3/4 | ✓ 160/30/3/4 | ✓ 160/30/3/4 | ✓ 160/30/3/5 | ✓ 160/30/3/4 |
| clif bar chocolate chip | 250 / 10 / 6 / 43 | ✓ 250/10/6/43 | ✗ 258/10/6.1/38 | ✓ 250/10/6/43 | ✓ 250/10/6/43 | ✓ 250/10/6/43 | ✗ 258/10/6.1/38 | ✓ 250/10/5/42 |
| chobani plain nonfat greek yogurt cup | 80 / 14 / 0 / 6 | ✓ 80/14/0/6 | ✓ 80/14/0/6 | ✓ 80/14/0/6 | ✓ 80/14/0/6 | ✓ 80/14/0/6 | ✓ 80/14/0/6 | ✓ 80/15/0/6 |
| diet coke can | 0 / 0 / 0 / 0 | ✓ 0/0/0/0 | ✓ 0/0/0/0 | ✓ 0/0/0/0 | ✓ 0/0/0/0 | ✓ 0/0/0/0 | ✓ 0/0/0/0 | ✓ 0/0/0/0 |
| big mac | 580 / 25 / 34 / 45 | ✓ 580/25/34/46 | – | ✓ 580/25/34/45 | ✓ 580/25/34/45 | ✓ 580/25/34/45 | – | ✓ 590/25/34/46 |
| chick fil a chicken sandwich | 420 / 29 / 16 / 41 | ✓ 420/29/16/41 | ✓ 420/29/16/41 | ✓ 420/29/16/41 | ✓ 420/29/16/41 | ✓ 420/29/16/41 | ✓ 420/29/16/41 | ✗ 440/30/19/40 |
| grande latte 2% | 190 / 13 / 7 / 19 | ✓ 190/13/7/19 | ✓ 190/13/7/19 | ✓ 190/13/7/19 | ✓ 190/13/7/19 | ✓ 190/13/7/19 | ✓ 190/12/7/18 | ✓ 190/12/7/19 |
| crunchwrap supreme | 530 / 15 / 20 / 74 | ✗ 530/20/21/71 | – | ✓ 530/15/20/73 | ✓ 530/15/20/73 | ✓ 530/15/20/73 | ✓ 530/15/20/74 | ✓ 540/16/21/71 |
| panera bacon turkey bravo | 860 / 47 / 39 / 80 | ✓ 860/47/39/80 | ✓ 860/47/39/80 | – | ✓ 860/51/41/74 | ✓ 860/47/39/80 | ✓ 860/47/39/80 | ✗ 840/42/33/95 |
| kind protein strawberry cocoa bar | trap | ✓ none | ✓ none | ✓ none | ✓ none | ✓ none | ✓ none | ✓ none |
| quest dark chocolate raspberry bar | trap | ✗ made up 190/20/8/22 | ✓ none | ✓ none | ✓ none | ✓ none | ✓ none | ✗ made up 180/20/7/24 |

USDA Branded (free database, best word match of the top 10): right for RXBAR, a different
product for KIND and Quest, then the shared DEMO_KEY hit its rate limit. A database needs the
AI to pick the product, not word matching (`.scratch/ideas/nutrition-database.md`).

Spend: about $2.30 of the $5 weekly limit, including the trial calls.

## Round 2: cheaper search engines (2026-10-04)

The same 15 lines, two passes, through the cheaper engines OpenRouter offers (the strict
prompt throughout):

| Setup | Right | Wrong | Not found | Traps refused | Median time | $ per lookup |
|---|---|---|---|---|---|---|
| gemini-3.5-flash-lite + Exa (round 1) | 24/26 | 0 | 2 | 4/4 | 2.9 s | 0.0084 |
| gemini-3.5-flash-lite + Parallel basic | 20/26 | 0 | 6 | 4/4 | 2.5 s | 0.0061 |
| gemini-3.5-flash-lite + Perplexity search | 20/26 | 0 | 6 | 4/4 | 2.0 s | 0.0062 |
| gemini-3.5-flash-lite + Parallel fast | 16/26 | 1 (Crunchwrap) | 9 | 4/4 | 2.2 s | 0.0022 |
| gpt-6-luna + Parallel fast | 15/26 | 0 | 11 | 4/4 | 5.7 s | 0.0014 |
| muse-spark-1.3 + Meta search | not run | | | | 137 s | 0.28 |

- The cheap engines are safe (one wrong in 104) but find far less: they hand the model short
  snippets (1,400–2,200 tokens against Exa's ~3,600), which often name the product without
  its full panel, so the model rightly says not found. Clif, Big Mac and Panera missed most.
- Muse Spark ran 27 searches over 2 minutes on the KIND bar, cost $0.28, and found nothing;
  dropped after that one line.
- Round 2 spend: $0.77. Both rounds together: about $3.10 of the $5 weekly limit.

## Takeaways

- Sonar was the weakest searcher: two wrong labels (Core Power fat, Crunchwrap protein), and
  it made up a Quest flavour that doesn't exist.
- Without search the model is close but not right: off on 3 of 13 and it made up the Quest
  trap. The lookup step earns its place.
- The strict `found` field works: every searching setup with it refused both traps every time.
- Panera (an 860 kcal sandwich in a long PDF) was the hardest line.
- Exa stays the pick: it found the most and was never wrong. The cheaper engines save about
  half a cent a lookup but find the label about a fifth less often.
- Caveat: 15 lines, two passes. Real use will turn up harder cases.

## Decision (2026-10-04)

John chose **`google/gemini-3.5-flash-lite` + Exa** with the strict prompt as tested
(`FoodModels.lookup`, `FoodModels.lookupSearch`, `FoodLookupPrompt`). The app's prompt is
asserted equal to the tested one, and the app's exact request (temperature 0,
`require_parameters`, schema, Exa) was sent once more before shipping: raspberry KIND bar
240/20/13/24, strawberry KIND not found, Big Mac 580/25/34/45.

To rerun: `python3 lookup-test/lookup_test.py lookup-test/lookup-truth.json out.json [setup …]`
then `python3 lookup-test/report.py lookup-test/lookup-truth.json out.json`. It reads the key
from `~/.config/coar/openrouter-key`. A full pass of all seven round-1 setups is about $1.30.
