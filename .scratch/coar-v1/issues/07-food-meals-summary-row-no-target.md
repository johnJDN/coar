# 07: Food: Meals, summary row, no-target state

**What to build:** Create a Meal from Food Items in fixed quantities; log it from the Meals segment as one Entry on the timeline with a quantity multiplier, keeping the component breakdown in its detail; and a compact summary row above the timeline showing consumed / target with a thin bar per macro against the Target in force that Day — with `—` and empty bars when no Target applies (`.scratch/data-model/issues/02`).

**Blocked by:** 06, 02

**Status:** ready-for-agent

- [ ] Meal editor: name; components as Food Item + Serving + quantity; reorder; archive
- [ ] Meals segment lists active Meals with summed macros as subtitle; logging creates one Entry with the Meal's name, summed macros × multiplier, and a component snapshot
- [ ] Meal Entry detail shows the breakdown; editing the Entry's macros or multiplier never touches the Meal
- [ ] Summary row: four thin bars (calories, protein `accentBlue`, fat `accentPink`, carbs `accentOrange`), "consumed / target" labels, target from "in force on Day"
- [ ] No Target for the Day: label reads "1,240 / —", bar track drawn, no fill; row never collapses
- [ ] Tests (façade): meal snapshot survives editing the Meal or its Items; a Day before the first Target reports nil target and the row model renders the empty form
- [ ] Tests (pure): summed macros × multiplier
