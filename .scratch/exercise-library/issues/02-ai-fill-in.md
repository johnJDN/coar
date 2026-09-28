# 02: AI fill-in on New exercise

**What to build:** On New exercise, 1.2 s after the name stops changing, fill in the primary
group, the groups it also works, and the equipment: from a library entry with that exact name
(free, "From the library"), otherwise from the OpenRouter text model with a strict schema
("Filled in by AI from the name. Check it."). It applies only while the details are the
defaults or the last fill-in, and does nothing without a key. Spec: stories 7–9.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] `ExerciseSuggester`: library first, then the model; reply parsing into Coar's groups and equipment
- [ ] The form's debounced fill-in, with the note in the muscle section's footer; never on edit
- [ ] The rule: apply only over the defaults or the last fill-in
- [ ] Tests: parsing (valid, unknown group dropped, Other equipment), the apply rule, the library-first path
- [ ] Check the prompt against the real model from the Mac on a few names
