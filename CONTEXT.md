# Coar

A single-user personal health tracker: habits, nutrition, strength training, body
composition, and the sleep and steps Apple Health already knows about.

## Language

**Day**:
A calendar day as it was where the user was when a record was made. Check-ins, Body
Weight, Workouts, and Progress Photos belong to a Day; it is never recomputed later.
_Avoid_: Date (when a time is meant), timestamp

### Habits

**Habit**:
Something the user intends to do repeatedly, with a target and the period that target
applies over. Either yes/no (done or not) or quantitative (an amount).
_Avoid_: Routine, goal, streak

**Period**:
The span a Habit's target applies over: a day, or a Monday-to-Sunday week.
_Avoid_: Schedule, frequency, cadence

**Check-in**:
The record that a habit happened on a given date, carrying that day's total amount.
There is at most one per Habit per day; a yes/no habit's check-in has an amount of 1.
_Avoid_: Entry, completion, log, tick

**Streak**:
The number of consecutive Periods, ending now, in which a Habit met its target. The
current Period counts once met and only breaks the streak once it has ended unmet.
_Avoid_: Chain, run, consistency

### Nutrition

**Macro**:
One of exactly four tracked nutrition values: calories, protein, fat, carbs. Nothing
else is a macro in Coar.
_Avoid_: Nutrient, macronutrient

**Food Item**:
A single named food the user has defined, such as eggs or chicken breast.
_Avoid_: Food, ingredient, product

**Serving**:
A named portion of a Food Item, with the macros for one of it and, when known, its
weight in grams. A Food Item has at least one; one is the default.
_Avoid_: Portion, unit, measure

**Meal**:
A named group of Food Items in fixed quantities, logged as one thing.
_Avoid_: Recipe, dish, combo

**Entry**:
A record that a Food Item or Meal was eaten at a particular time, in some quantity.
Distinct from a Check-in, which belongs to habits.
_Avoid_: Log entry, food log, meal log, serving

**Target**:
The daily macro amounts the user is aiming for, effective from a date.
_Avoid_: Goal, budget, allowance

### Catalogue

**Archived**:
The state of a Habit, Food Item, Meal, Exercise, or Plan the user has retired: hidden
from pickers and lists, but kept because history refers to it. Restorable, or deleted
permanently from its Archived list (never straight from the active list). History keeps its
own copy, so deleting changes no past day; a Habit takes its Check-ins with it, and an
Exercise its Progression.
_Avoid_: Deleted (for archiving), hidden, inactive, disabled

### Training

**Train**:
The tab holding everything about training the body: plans, workouts, exercises, body
weight, and progress photos.
_Avoid_: Strength, gym, fitness, workouts (as a section name)

**Exercise**:
A named movement in the user's catalogue, such as incline dumbbell press, with a primary
Muscle Group, any secondary ones it also works, and optionally the equipment it uses.
_Avoid_: Lift, movement

**Muscle Group**:
One of a fixed list of body regions (including Other) an Exercise trains: one primary,
any number secondary. Used to aggregate volume. Never free text.
_Avoid_: Body part, muscle, target area

**Plan**:
A reusable template: an ordered list of Exercises, each with its Planned Sets.
_Avoid_: Routine, template, program, split, workout (for the template)

**Planned Set**:
One set as prescribed by a Plan: a target weight and a rep range (min and max; a single
number is min = max).
_Avoid_: Target set, prescribed set, set

**Workout**:
One training session that actually happened, on a date, containing the Exercises
performed and the Logged Sets performed for each. May or may not come from a Plan.
_Avoid_: Session, training, workout log

**Active Workout**:
The one Workout currently in progress. There is never more than one.
_Avoid_: Current workout, live workout, in-progress session

**Logged Set**:
One set as actually performed: the weight lifted and the reps completed.
_Avoid_: Actual set, performed set, working set, set

**Superset**:
Two or more adjacent Exercises within a Plan or Workout performed in alternation.
_Avoid_: Circuit, giant set, pairing

**Progression**:
How a single Exercise has moved over time, shown on that Exercise's detail page as
Estimated 1RM per Workout.
_Avoid_: Progress, PR history, strength curve

**Estimated 1RM**:
The single-rep maximum implied by a Logged Set's weight and reps; the best one in a
Workout is that day's value for Progression.
_Avoid_: 1RM (unqualified), max, PR

**Body Weight**:
The user's own weight on a Day; at most one per Day. Never abbreviated to "weight"
where a lifted weight could be meant.
_Avoid_: Weight (unqualified), bodyweight, mass

**Trend Weight**:
The smoothed Body Weight that filters out day-to-day water swings; the hero number on
the weight screen.
_Avoid_: Average weight, moving average, true weight

**Progress Photo**:
A photo of the user's body taken on a date to compare against later ones.
_Avoid_: Photo, progress pic, body photo

### Sleep and steps

Read live from Apple Health and never stored (ADR 0002).

**Night**:
The sleep that belongs to one Day: everything between 6 PM the evening before and 6 PM
that Day, as the Health app groups it (ADR 0006). A Night belongs to the Day the user
woke, so an afternoon nap joins the Night before it and an evening doze the Night after.
_Avoid_: Sleep session, sleep day, last night's sleep (as a data term)

**Time Asleep**:
A Night's value: the hours in the asleep stages (core, deep, REM, unspecified), with
awake and in-bed excluded and hours two sources both recorded counted once. A Night with
no asleep sample has no Time Asleep, shown as `No data`; it is never 0.
_Avoid_: Sleep duration, sleep time, hours slept, in bed

**Steps**:
The step count Apple Health holds for a Day, its own sum across sources.
_Avoid_: Step count, activity, walking
