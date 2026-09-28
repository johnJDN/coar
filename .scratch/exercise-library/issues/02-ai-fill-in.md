# 02: AI fill-in on New exercise

**What to build:** On New exercise, 1.2 s after the name stops changing, fill in the primary
group, the groups it also works, and the equipment: from a library entry with that exact name
(free, "From the library"), otherwise from the OpenRouter text model with a strict schema
("Filled in by AI from the name. Check it."). It applies only while the details are the
defaults or the last fill-in, and does nothing without a key. Spec: stories 7–9.

**Blocked by:** 01

**Status:** done

- [x] `ExerciseSuggester`: library first, then the model; reply parsing into Coar's groups and equipment
- [x] The form's debounced fill-in, with the note in the muscle section's footer; never on edit
- [x] The rule: apply only over the defaults or the last fill-in
- [x] Tests: parsing (valid, unknown group dropped, Other equipment), the apply rule, the library-first path
- [x] Check the prompt against the real model from the Mac on a few names

## Comments

- 2026-09-27 (agent): Implemented.
  - **The suggester** (`Coar/Train/ExerciseSuggester.swift`):
    - `ExerciseSuggestion` holds the groups, equipment and source. It reads a strict reply,
      dropping unknown groups and never repeating the primary; "None" → nil; "Other" → the
      named equipment.
    - `ExerciseSuggester.suggest(for:)` checks for a library entry with that exact name
      first. Otherwise, only with a key, it asks `FoodModels.text` (Gemini 3.5 Flash-Lite,
      15 s). It's quiet on failure (logged).
    - `MuscleGroup.named` is new.
  - **The form.** `ExerciseForm.Draft` gains `acceptsSuggestion(after:)` (details still the
    new form's, or still the last suggestion's) and `apply`. The form takes an optional
    `suggest`, which only New exercise passes.
    - It runs from `.task(id: trimmedName)` after 1.2 s, and re-checks the rule and the name
      before applying.
    - The muscle footer shows the note while the details are still the suggestion's.
  - **Prompt checks** against Gemini 3.5 Flash-Lite, on John's names and a few outside the
    library:
    - "Incline DB press 30°" → Chest + Triceps, Shoulders · Dumbbell;
    - "Dips, slight lean" → Chest + Triceps, Shoulders · Bodyweight;
    - "Standing rear delt fly" → Shoulders + Back · Dumbbell;
    - "DB Romanian deadlift" → Hamstrings + Glutes, Back · Dumbbell;
    - "Landmine row" → Back · Other: Landmine;
    - "Copenhagen plank" → Other (adductors) + Core, Glutes;
    - "Trap bar farmer's walk" → Forearms · Other: Trap bar.
    - Each took 1.0–1.9 s.
  - **Tests:** `ExerciseSuggestionTests` (7): reading a reply; Other, None and bad groups;
    a library name with no request; no key with no request; filling only an untouched form
    and replacing only itself; Other equipment; the schema's lists matching Coar's. Suite
    green at 328.
  - **Not checked in the simulator:** the form's name field brought up no software keyboard
    this session, so nothing could be typed. John checks it on the phone.
  - Left as deliberate:
    - the form's default (Chest, nothing else) counts as untouched, so choosing Chest
      yourself before typing doesn't stop a fill-in;
    - no fill-in on edit;
    - with no key, only library names fill in, silently.
