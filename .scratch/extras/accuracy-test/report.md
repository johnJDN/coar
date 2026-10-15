| Extra | Right | Wrong (a number that's off) | Missing (left blank) | Gave a number the brand doesn't publish |
|---|---|---|---|---|
| fiber | 38 | 0 | 4 | 2 |
| sodium | 33 | 1 | 8 | 2 |
| caffeine | 24 | 0 | 2 | 0 |
| alcohol | 48 | 2 | 0 | 0 |

| Line | Path | Fiber | Sodium | Caffeine | Alcohol |
|---|---|---|---|---|---|
| quest cookie dough bar | lookup | ok: 12 (truth 12) | ok: 220 (truth 220) | –: — (truth —) | ok: — (truth 0) |
| rxbar chocolate sea salt | lookup | ok: 5 (truth 5) | ok: 190 (truth 190) | –: — (truth —) | ok: — (truth 0) |
| clif bar chocolate chip | lookup | ok: 5 (truth 5) | blank: — (truth 130) | –: — (truth —) | ok: — (truth 0) |
| chobani plain greek yogurt | lookup | ok: 1 (truth 0) | ok: 55 (truth 55) | –: — (truth —) | ok: — (truth 0) |
| premier protein chocolate shake | lookup | ok: 2 (truth 2) | ok: 230 (truth 230) | –: — (truth —) | ok: — (truth 0) |
| kind protein max raspberry cocoa bar | lookup | ok: 10 (truth 10) | ok: 180 (truth 180) | –: — (truth —) | ok: — (truth 0) |
| big mac | lookup | ok: 3 (truth 3) | ok: 1060 (truth 1060) | –: — (truth —) | ok: — (truth 0) |
| chick-fil-a chicken sandwich | lookup | blank: — (truth 1) | ok: 1470 (truth 1470) | –: — (truth —) | ok: — (truth 0) |
| taco bell crunchwrap supreme | lookup | ok: 6 (truth 6) | blank: — (truth 1210) | –: — (truth —) | ok: — (truth 0) |
| red bull | lookup | ok: 0 (truth 0) | ok: 105 (truth 105) | blank: — (truth 80) | ok: — (truth 0) |
| celsius | text (lookup found nothing) | blank: — (truth 0) | blank: — (truth 5) | ok: 200 (truth 200) | ok: — (truth 0) |
| monster energy | text (lookup found nothing) | –: — (truth —) | –: — (truth —) | ok: 160 (truth 160) | ok: — (truth 0) |
| starbucks latte grande | lookup | ok: 0 (truth 0) | ok: 170 (truth 170) | ok: 150 (truth 150) | ok: — (truth 0) |
| starbucks pike place grande | lookup | ok: 0 (truth 0) | ok: 10 (truth 10) | ok: 352.5 (truth 352.5) | ok: — (truth 0) |
| coke | text | ok: 0 (truth 0) | ok: 45 (truth 45) | ok: 34 (truth 34) | ok: — (truth 0) |
| diet coke | lookup | ok: 0 (truth 0) | blank: — (truth 40) | ok: 46 (truth 46) | ok: — (truth 0) |
| 2 hard boiled eggs | text | ok: 0.0 (truth 0.0) | ok: 124 (truth 124) | ok: — (truth 0) | ok: — (truth 0) |
| banana | text | ok: 3.1 (truth 3.1) | ok: 1 (truth 1) | ok: — (truth 0) | ok: — (truth 0) |
| cup of oatmeal | text | ok: 4 (truth 4.0) | ok: 2 (truth 9.4) | ok: — (truth 0) | ok: — (truth 0) |
| cup of white rice | text | ok: 0.6 (truth 0.6) | ok: 0 (truth 1.6) | ok: — (truth 0) | ok: — (truth 0) |
| 6 oz grilled chicken breast | text | ok: 0 (truth 0) | WRONG: 122 (truth 88.4) | ok: — (truth 0) | ok: — (truth 0) |
| bud light | text (lookup found nothing) | –: — (truth —) | –: — (truth —) | –: — (truth —) | ok: 0.8 (truth 0.84) |
| guinness | text (lookup found nothing) | –: — (truth —) | –: — (truth —) | –: — (truth —) | WRONG: 1.2 (truth 1.04) |
| glass of red wine | text | ?: 0 (truth —) | ?: 5 (truth —) | –: — (truth —) | ok: 1 (truth 1.13) |
| shot of vodka | text | ok: 0 (truth 0) | ok: 0 (truth 0) | ok: — (truth 0) | ok: 1.0 (truth 1.0) |

## Run 3 (2026-10-14): the lookup searches for "<line> nutrition facts"

Prompted by "shin ramen" coming back with no sodium: the search, made from the line alone,
kept landing on Nongshim's Korean page (calories only), and three replays of the old setup
all ended with sodium blank. Asking for the label lands on nongshimusa.com every time (520
cal, 1,620 mg sodium, 3 g fiber). One pass of the 25 lines, `run3-nutrition-facts.json`
($0.15), against run 1 / run 2:

| Extra | Right | Wrong | Missing | Unpublished number |
|---|---|---|---|---|
| fiber | 20 (19 / 19) | 0 | 1 (2 / 2) | 1 |
| sodium | 20 (16 / 17) | 1 | 0 (4 / 4) | 2 |
| caffeine | 13 (12 / 12) | 0 | 0 (1 / 1) | 0 |
| alcohol | 24 | 1 | 0 | 0 |

Lookups now find labels for Celsius, Monster and Bud Light (before: nothing found), and
sodium for Clif, Crunchwrap and Diet Coke. The one new "unpublished" is Monster's 370 mg,
which its US can does print; the truth file just doesn't have it.
