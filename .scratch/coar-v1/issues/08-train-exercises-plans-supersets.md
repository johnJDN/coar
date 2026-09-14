# 08: Train: Exercises, Plans, Supersets

**What to build:** The Exercise catalogue (name, primary Muscle Group from a fixed list, optional equipment, optional rest default) and the Plan editor: an ordered list of Exercises, each with ordered Planned Sets carrying a target weight (kg, shown in the display unit) and a min–max rep range, with adjacent Exercises groupable as a Superset. Train root lists Plans. Archive, don't delete.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Exercises chip opens the catalogue; editor with name, Muscle Group picker (fixed enum), equipment text, rest default seconds; archive
- [ ] Train root shows a Plans section (cards with name and "n exercises") and the chips row
- [ ] Plan editor: add Exercises from the catalogue picker (archived hidden), reorder, remove; per Exercise an ordered list of Planned Sets with weight and repMin/repMax (single number entered as min = max, shown as one number)
- [ ] Superset: link two or more adjacent Exercises into one group; unequal set counts allowed; link icon shown between grouped cards
- [ ] Archive Plan from its editor; Archived section with restore
- [ ] Tests (façade): Plan exercise and set ordering persists through save/reload; superset group membership persists; archived Exercises absent from the picker; Planned Set weight stored kg when lbs entered
