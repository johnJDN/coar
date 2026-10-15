# Describe quality of life (2026-10-14)

John picked four of seven ideas: **1** size words scale your saved food, **2** split a line
with several foods, **4** your foods offered as you type, **5** a note with a photo. Not now:
times in the line ("for lunch at 1pm"), the photo's own time, "Log again" on an entry.

## 1. Sizes

"large pho" against a saved Pho with one "bowl" serving used to log one bowl, labelled "Your
food". Now the typed-line prompt says: a serving named for the size wins (Fries: "large");
otherwise match and scale (large about 1.5, small 0.75, half 0.5, double 2). A product's
standard size ("2 large eggs") is not a portion size, and an addition ("with extra noodles") is
not a size. The line shows the scaling ("1.5 × bowl · Your food").

## 2. Several foods on one line

The typed-line reply gains `parts`: the separate foods a line lists ("eggs, toast and coffee"
→ three). Two or more, and the line becomes one line per food in its place, each estimated on
its own (and matched against Foods, and looked up, on its own). A dish with parts stays one
food ("toast with butter", "salt and pepper chicken wings").

## 4. Your foods as you type

After two letters, saved foods and meals whose name (or a word of it) starts with what's
typed show as glass capsules above the keyboard: name over "default serving · calories". Picking
one makes the line that name (after any amount typed: "2 Pho") and fills it from Foods at once,
with no model. Nothing shows once the line already is a name.

## 5. A note with a photo

After picking or taking a photo, an alert asks "Anything to add?" with an optional field ("I ate
half"). The note goes with the image to the photo model, which is told to trust it over what it
sees and say so in the items' notes.

## Tested

- `prompt_check.py`: 17 lines against a small saved library, live, two final passes (33/34; the
  miss was "venti iced latte" against a "grande" serving left unmatched, so estimated fresh).
- Unit tests for parsing parts, the split, suggestions, and the photo note in the request.
- Not tested live: the photo note (no shareable food photo to send).
