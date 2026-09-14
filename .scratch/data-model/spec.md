# Data model foundation

Cross-cutting concerns for the Core Data + CloudKit model that every tab depends on.
The decisions themselves are ADRs 0002–0005 and the glossary in `CONTEXT.md`; the
tickets here are the implementation consequences that fall out of them.

Shared shapes to build once, not per feature:

- **Dated series** — macro Target; habit target + period.
- **One-per-Day record** — Check-in (per Habit), Body Weight.
- **Day-keyed date** — Check-in, Body Weight, Workout, Progress Photo; Entry carries an
  instant plus its Day (ADR 0005).
