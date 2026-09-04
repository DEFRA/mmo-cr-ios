# ADR 0011 — Per-gear catch grouping and multi-gear journey loop

- Status: Accepted
- Date: 2026-09
- Deciders: iOS engineering
- Context tags: architecture, domain-model, navigation, offline-first, native-iOS

## Context

ADR-0010 introduced multi-select on "What gear did you use?" (`SelectGearView`) and per-trip
variable measurements per ticked gear, but explicitly deferred full multi-gear submission: "only
the first selected gear flows into `CatchRecordDraft.gear`" (ADR-0010 §4). In practice, the
statistical (sub)area picked on the catch-location map and the species caught are both properties
of **a single gear's use on the trip**, not the trip as a whole — a vessel using two different
gears on the same trip may fish two different areas and catch different species with each. The
flat `CatchRecordDraft.gear` / `.statisticalArea` / `.speciesCaught` fields could not represent
this, and the journey had no way to ask "where/what did you catch **with this gear**?" more than
once per trip, nor any way to return to the map screen for a second or third gear.

This ADR resolves that follow-up, superseding ADR-0010 §4 and amending the model introduced in
ADR-0005.

## Decision

### 1. Introduce `GearCatch`, one per selected gear

`GearCatch` is a `nonisolated`, `Sendable` `struct` grouping `gear: GearOption` (with its captured
required/variable measurements), `statisticalArea: String?` and `speciesCaught: [SpeciesOption]`.
`CatchRecordDraft.gear`/`.statisticalArea`/`.speciesCaught` are replaced by a single
`gearCatches: [GearCatch]`, one entry per gear ticked on `SelectGearView`, in selection order.
`CatchRecordDraft.orderedGears` (`gearCatches.map(\.gear)`) and
`gearCatchIndex(forGearID:)` are added as convenience accessors used by the catch-location and
species view models to find "this gear's" entry to write into.

`speciesNotLanded` remains a single, trip-level list on `CatchRecordDraft`, unchanged — it is asked
once, after every gear's catch has been recorded, and is not split per gear (there is no per-gear
"not landed" concept in the current design).

### 2. `SelectGearView` captures every ticked gear, not just the first

`SelectGearViewModel.submit()` now writes **all** ticked gears (in favourites order, each with its
own captured variable measurements) into `draft.gearCatches`, and pushes the catch-location screen
for the **first** confirmed gear.

### 3. The catch-location and species screens write into their own gear's entry

`CatchLocationViewModel`/`CatchLocationManualEntryViewModel.submit()` write the chosen statistical
area into `draft.gearCatches[gearCatchIndex(forGearID: gear.id)]` rather than a single trip-level
field. `RecordSpeciesWeightsViewModel.submit()` does the same for `speciesCaught`.

### 4. The journey loops back to the map for each additional gear

A pure, unit-testable routing decision, `CatchRecordRouting.speciesCompletionRoute(...)`, resolves
where "Save and continue" on "Which species did you catch with `<gear>`?" goes next:

- If more selected gears remain after the current one (a multi-gear journey), loop back to
  `.catchLocation(gear:)` for the **next** gear — repeating the location → species pair once per
  gear.
- Otherwise (a single selected gear, or this was the last of several), continue to the trip-level
  landing-storage question, exactly as before multi-gear support.

No numeric "gear 2 of 3" progress caption is shown between loops — the existing gear-named heading
("using `<gear>`" / "with `<gear>`") is sufficient to orient the user, and GDS only recommends a
progress indicator when user research shows it helps; this journey has not identified that need.

### 5. Check your answers renders one section per gear, and "Change" can skip back here

`CheckYourAnswersViewModel` now renders one section per `GearCatch` (titled by the gear's name,
since it is untranslated reference data), showing that gear's name, its required and variable
measurements, its statistical area and the species caught with it — rather than one flat "Gear
used" + "Species caught" pair of sections. Because the same field label (e.g. "Statistical area")
now repeats once per gear section, each "Change" control's accessibility label is disambiguated
with the gear's name (e.g. "Change Statistical area for Seine nets"), per the GOV.UK Design System
guidance that a summary-card's Change link must say what it changes.

Editing a gear's statistical area or species caught from Check your answers is a **bigger**
correction than editing a trip-level field: the normal "Change" pattern **pushes forward** through
the remaining journey (so "Save and continue" naturally returns to Check your answers), but for a
per-gear field that would otherwise walk the user through every other gear's catch-location/species
screens again before returning. Instead, `CatchRecordDraft.returnToCheckYourAnswersAfterSpecies` is
set (via `CheckYourAnswersViewModel.change(to:resumingAtCheckYourAnswers:)`) whenever a per-gear
row's "Change" is tapped, and consumed by `speciesCompletionRoute` to return **straight back** to
Check your answers once that one gear's mini re-entry (map → species) completes, regardless of how
many other gears exist. The flag is reset as soon as it is consumed (or whenever `change(to:)` is
called again), so it never leaks into a normal forward-journey save.

## Consequences

- `GearCatch` is a small, `Sendable` value type — no new isolation or persistence concerns beyond
  what `CatchRecordDraft` already has (still in-memory only for this phase; see ADR-0005 §3).
- `CatchRecordRouting.speciesCompletionRoute` is the single place the loop/continue/return-to-CYA
  decision is made, kept pure (no router/view dependency) so it is directly unit-testable,
  mirroring the existing `portEntryRoute`/`gearEntryRoute`/`speciesEntryRoute` pattern.
- `GearMeasurementsViewModel`'s "required measurements" flow is unaffected — required measurements
  are still captured once per favourite gear, not per trip, and are unrelated to this per-trip
  catch-location/species looping.
- Offline-first is preserved: all new fields are captured into the in-memory `CatchRecordDraft`; no
  network or persistence is added here.
- Standing obligation: on-device persistence/sync of `gearCatches` is covered by the future
  persistence ADR foreshadowed in ADR-0005.

## References

- ADR-0005 (`CatchRecordDraft`), ADR-0010 (gear required/variable measurements — §4 superseded by
  this ADR).
- GOV.UK Design System, *Check answers* —
  https://design-system.service.gov.uk/patterns/check-answers/
- GOV.UK Design System, *Task list pages* (guidance on when a numbered progress indicator helps) —
  https://design-system.service.gov.uk/patterns/task-list-pages/
