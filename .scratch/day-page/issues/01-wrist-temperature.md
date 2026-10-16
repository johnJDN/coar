# 01: Wrist temperature

**Spec:** `../spec.md`

**Status:** done

Add Apple's sleeping wrist temperature (`HKQuantityTypeIdentifierAppleSleepingWristTemperature`, °C or °F by locale) as an overnight reading: a row on the Overnight card against the usual (flag when more than 0.5° above), its history page with the band. Read with the other overnight readings' permission (re-ask: it's a new type).

## Comments
- 2026-10-16 (agent): Done. A `Vital` (°C kept, °F shown for US units, two decimals), one a
  Night dated at its end, flagged half a degree above the usual (only warmer); a row on the
  Overnight card and its own history with the band. The new type re-asks the overnight
  readings' permission once.
