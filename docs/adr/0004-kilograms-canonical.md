# 0004. Mass is stored in kilograms; the unit setting is display-only

**Status:** accepted (2026-09-13)

The app displays pounds by default with a kilograms setting, but every stored mass
(lifted weight on Planned and Logged Sets, Body Weight) is a kilogram value. The unit
setting converts on display and on input only, rounding at display precision. Chosen over
"store as entered with a unit tag" and "store lbs" because HealthKit's mass unit is
kilograms (the Body Weight write path needs no conversion), a single canonical unit means
flipping the setting never migrates history, and lbs input round-trips cleanly at one
decimal.
