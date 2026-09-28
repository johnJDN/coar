# Exercise library

Status: done (2026-09-27)

Decided with John on 2026-09-27. The list itself is `list.md` (148 exercises, reviewed). This
supersedes the "List" half of `.scratch/ideas/exercise-library.md`. Tutorials and videos stay
parked there.

## Problem Statement

Setting up Coar means creating every exercise by hand: a name, a primary muscle group, the
groups it also works, and its equipment. That's 14 forms for John's three-day plan alone, and
each one means looking up which muscles an exercise works. It's the most tedious part of
starting with Coar.

## Solution

- **A built-in library of 148 common gym and home exercises,** each with its muscle groups
  and equipment in Coar's own terms. It's offered wherever an exercise is added. One tap copies
  it into the user's exercises, where it's theirs to rename, edit or archive like any other.
- **AI fill-in on New exercise.** For anything not in the library, typing the name fills in the
  muscle groups and equipment, which the user checks and saves.

## User Stories

1. As John, I want the exercise picker (Add Exercise, from a plan or a workout) to list the library under my own exercises, grouped by muscle group, so that I can add an exercise I haven't created yet in one tap.
2. As John, I want tapping a library exercise there to create it in my exercises and add it to the plan or workout at once, so that it's one step, not two.
3. As John, I want the filter to search the library too, by name or by muscle group ("chest"), so that I find things quickly.
4. As John, I want library exercises I already have (same name, active or archived) left out, so that I never create duplicates.
5. As John, I want Exercises → + to open the library with New exercise at the top, and to stay open as I tap several, each disappearing once added, so that setting up all my exercises is a run of taps.
6. As John, I want an exercise added from the library to keep the library's name, with its muscle groups, equipment and rest still mine to change, so that the library stays the one name for it and is never added twice. A variation the library lacks is a New exercise, which I can name as I like. (Changed 2026-09-27: first built as renameable; John: "that shouldn't be possible".)
7. As John, I want New exercise to fill in the muscle groups and equipment shortly after I type a name (from the library when the name is in it, otherwise from AI), with a note saying so, so that I only check it rather than look it up.
8. As John, I want a fill-in never to overwrite muscle groups or equipment I've set myself, so that the AI can't undo my choice.
9. As John, I want New exercise to work exactly as today without a key or a connection, so that the fill-in is a help, not a requirement.

## Implementation Decisions

- **The library is Swift data in the app** (`ExerciseLibrary.entries`), generated once from
  `list.md`. There's no bundle file to load, and it's type-checked against `MuscleGroup`.
  Equipment is stored as the text Coar already stores: an `Equipment` title, or the Other
  name ("Ab wheel", "Trap bar").
- **Adding copies the entry through the existing `Store.createExercise`,** with no rest
  default. There's no link back to the library and no schema change, so no CloudKit deploy.
- **"Already have"** means an exercise, active or archived, whose name matches
  case-insensitively. Archived ones come back through Restore, not a second copy.
- **The picker** takes a mode:
  - **plan or workout:** your exercises, New exercise, then the library. Picking returns an
    exercise, as today.
  - **catalogue**, from Exercises → +: New exercise, then the library. Tapping adds the entry
    and keeps the sheet open; Done closes it.
  - The library appears as one section per muscle group, in `MuscleGroup` order, with
    headers.
  - The filter matches the name, or the primary group's title.
- **AI fill-in** (New exercise only, never on edit):
  - It runs 1.2 s after the name stops changing.
  - An exact library name match is used first, for free, with the note "From the library".
  - Otherwise the OpenRouter text model (`FoodModels.text`'s model; one constant for AI text
    in Coar) gets a strict schema: primary group, secondary groups and equipment, each
    limited to Coar's lists, plus Other with a name.
  - The note reads "Filled in by AI from the name. Check it."
  - It applies only while the details are still the defaults, or still the last fill-in; the
    user's own change stops it.
  - With no key, it fails silently and the form behaves as today.

## Testing Decisions

- **Seam 2:**
  - the library's integrity (148 entries, unique names, no primary repeated as secondary,
    equipment a known title or Other);
  - "already have" filtering, and filtering by name or group;
  - parsing the fill-in reply;
  - the rule for when a fill-in may apply.
- **Seam 1:** adding a library entry creates an ordinary Exercise with its groups and
  equipment.
- **UI:** checked by hand in the simulator.

## Out of Scope

- Tutorials, videos and images. Rest defaults per exercise.
- Pasting a whole plan.
- Keeping copies in step with later changes to the library.
