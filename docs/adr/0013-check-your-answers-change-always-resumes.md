# ADR 0013 — Every "Change" link on Check your answers returns straight back there

- Status: Accepted
- Date: 2026-09
- Deciders: iOS engineering
- Context tags: navigation, ux, offline-first, native-iOS

## Context

ADR-0011 §5 introduced `CatchRecordDraft.returnToCheckYourAnswersAfterSpecies`, set whenever a
**per-gear** row's "Change" (statistical area or species caught) was tapped from Check your
answers, so that editing just that field returned straight back to Check your answers once its
mini re-entry (catch-location → species) completed, instead of walking forward through every other
selected gear.

Every other "Change" link on Check your answers — vessel, departure/return date,
departure/return port, a gear's name/required measurements, and a gear's variable (per-trip)
measurements — did **not** get this treatment. Tapping "Change" on the vessel, for example, pushed
`SelectVesselView`; on save it continued into "Did your trip start and finish today?", both trip
dates, the late-submission nudge (if applicable), both ports, the gear sub-journey, catch-location,
species, and landing storage — the **entire remainder of the journey** — before finally reaching
Check your answers again. Correcting a single field this way meant re-answering every subsequent
question, which is a poor, confusing correction experience and does not match the GOV.UK Design
System's *Check answers* pattern, where a Change link takes the user to fix one thing and returns
them straight back.

Two smaller, related defects were found while fixing this:

1. `GearMeasurementsViewModel.submit()` only ever wrote an edited gear's required measurements into
   the **favourites** store, never back into `CatchRecordDraft.gearCatches` — so even before this
   ADR, editing a gear's mesh size from Check your answers would not actually update the value
   shown there.
2. `SelectGearViewModel.submit()` always rebuilt `draft.gearCatches` from scratch as bare
   `GearCatch(gear:)` entries, discarding any already-captured `statisticalArea`/`speciesCaught` for
   gears re-ticked after "Add another gear" (or, now, when resuming from Check your answers).

## Decision

### 1. Generalise the resume flag to every "Change" link

`CatchRecordDraft.returnToCheckYourAnswersAfterSpecies` is renamed to
`returnToCheckYourAnswers` and is now set by **every** call to
`CheckYourAnswersViewModel.change(to:)` — the per-row `resumesAtCheckYourAnswers` distinction on
`CheckYourAnswersViewModel.Row` is removed, since it is now always true. `change(to:)` no longer
takes a parameter for it.

### 2. Each screen's `submit()` checks the flag and, when set, returns straight to Check your answers

Rather than continuing into its normal "next screen", once a screen's own edit is saved it checks
`draft.returnToCheckYourAnswers`; if set, it clears the flag and pushes `.checkYourAnswers(...)`
directly instead of its usual next route:

- `SelectVesselViewModel` — after writing `draft.vessel`, skips "Did your trip start and finish
  today?" and the whole rest of the journey.
- `TripDateViewModel` — after writing the departure or return date, skips the other date, the
  late-submission nudge and the port screens. Only the one date being corrected is re-asked; the
  other (already captured) date is left untouched.
- `SelectPortViewModel` — after writing the departure or return port, skips the other port and the
  gear sub-journey.
- `GearMeasurementsViewModel` — after saving to favourites (see fix below), skips
  `SelectGearView`.
- `SelectGearViewModel` — after writing `draft.gearCatches` (see fix below), skips
  catch-location/species for every ticked gear.

The gear's statistical-area and species-caught rows are unchanged from ADR-0011: their "Change"
still walks the map → species pair for that one gear before returning, which remains a deliberate,
documented exception (editing where/what was caught with a gear is treated as one combined edit),
not a gap this ADR needed to close.

### 3. Fix: `GearMeasurementsViewModel` now syncs the draft, not just favourites

`GearMeasurementsViewModel.submit()` now also updates `draft.gearCatches[gearCatchIndex(...)].gear`
in place (when that gear is already part of the trip), so a measurement edit is reflected on Check
your answers immediately, for both the resume path and the normal forward-journey path.
`GearCatch.gear` changes from `let` to `var` to allow this in-place update.

### 4. Fix: `SelectGearViewModel` preserves already-captured per-gear progress

`SelectGearViewModel.submit()` now looks up each ticked gear's existing `GearCatch` (via
`draft.gearCatchIndex(forGearID:)`) and, when found, keeps its `statisticalArea`/`speciesCaught`
rather than discarding them; only genuinely new gears start a fresh, empty `GearCatch`. This is a
strict improvement independent of resuming at Check your answers — it also fixes the same data loss
when re-ticking gears after "Add another gear" mid-journey.

## Consequences

- Every "Change" link on Check your answers now behaves consistently: fix one thing, return to
  Check your answers — matching the GOV.UK Design System *Check answers* pattern and avoiding
  forcing the user to re-answer unrelated, already-completed questions.
- The `CatchRecordDraft.returnToCheckYourAnswers` flag remains a single, transient (in-memory only)
  navigation hint, reset as soon as it is consumed; it carries no persisted state and has no
  security or accessibility surface of its own.
- `GearCatch.gear` becoming `var` is a narrowly-scoped mutability change to a `Sendable` value type
  held only inside `CatchRecordDraft`; no new isolation concerns are introduced.
- All affected view models ship unit tests for both the "resume" and "preserve existing progress"
  behaviour (`SelectVesselViewModelTests`, `TripDateViewModelTests`, `SelectPortViewModelTests`,
  `GearMeasurementsViewModelTests`, `SelectGearViewModelTests`, `CheckYourAnswersViewModelTests`).

## References

- ADR-0011 (per-gear catch grouping and multi-gear journey loop — §5 superseded/generalised by this
  ADR).
- GOV.UK Design System, *Check answers* —
  https://design-system.service.gov.uk/patterns/check-answers/
