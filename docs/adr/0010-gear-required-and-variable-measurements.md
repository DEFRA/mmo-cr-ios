# ADR 0010 — Gear measurements split into required (per-favourite) and variable (per-trip)

- Status: Accepted
- Date: 2026-08
- Deciders: iOS engineering
- Context tags: architecture, domain-model, offline-first, api-stub-seam, native-iOS

## Context

A gear (fishing method) carries measurements. Until now `GearOption` modelled these as a single
`measurements: [GearMeasurement]` list, captured once on the gear-measurements screen when the user
adds the gear to their favourites (e.g. mesh size for seine nets). See ADR-0004 (API-stub seam) and
ADR-0005 (`CatchRecordDraft`).

Fisheries reference data distinguishes **two kinds** of gear measurement:

- **Required measurements** — fixed properties of the gear itself (e.g. mesh size). They do not
  change between trips, so they belong to the saved favourite and are captured once.
- **Variable measurements** — values that change **per trip** (e.g. the number of times seine nets
  were shot). They must be captured **each time the gear is used**, i.e. on the "What gear did you
  use?" (SelectGear) screen, not when the gear is first saved.

The single-list model could not represent this distinction, so the SelectGear screen had no way to
ask for per-trip values. The design (see the design spec) reveals a per-trip field beneath a gear
when it is ticked.

We assume the future gear reference-data API will supply, per gear, both the required and the
variable measurement definitions. This is modelled now behind the existing stubbed, API-shaped
providers so no call site changes when the real API arrives.

## Decision

### 1. Split `GearOption.measurements` into two ordered lists

`GearOption` now exposes `requiredMeasurements: [GearMeasurement]` and
`variableMeasurements: [GearMeasurement]`. Each `GearMeasurement` keeps its existing shape (`id`,
`labelKey`, optional whole-number `value`). Copy-and-modify helpers are renamed/added accordingly:
`withRequiredMeasurements(_:)` and `withVariableMeasurements(_:)`. The clearer names are preferred
over the ambiguous `measurements`/`withMeasurements` per the Swift API Design Guidelines (clarity at
the point of use); the rename is compile-time-checked and all call sites were updated.

The seine-nets stub gains one variable measurement, `timesShot`
(`catchRecord.gear.variableMeasurement.timesShot` — "Number of times gear was shot on trip").

### 2. Where each kind is captured

- **Required** measurements stay captured on the gear-measurements screen at add-to-favourites time
  and are stored with the favourite (unchanged behaviour).
- **Variable** measurements are captured on the SelectGear screen: ticking a gear reveals its
  variable field(s) (GOV.UK conditional-reveal pattern). Each revealed field is **required** once
  shown and must be a whole number (reusing `GearMeasurementValidation`). On "Save and continue" the
  captured values are attached to the selected gear via `withVariableMeasurements(_:)` and written to
  `CatchRecordDraft.gear`.

### 3. Surfacing on Check your answers

The gear section renders required measurement rows (their "Change" returns to the gear-measurements
screen) followed by variable measurement rows with their captured values (their "Change" returns to
the SelectGear screen, where they are captured).

### 4. Single-gear draft limitation retained

The UI supports multi-select and reveals variable fields per ticked gear, but — matching the current
phase — only the first selected gear flows into `CatchRecordDraft.gear`. Per-gear variable entries are
keyed by `"<gearId>.<measurementId>"` so the model is ready for multi-gear submission without
rework. Full multi-gear submission is a future-phase follow-up.

## Consequences

- `GearOption` is the domain authority for the required/variable distinction; view models and the
  reference-data stub populate it. Equality now includes both lists, so routes carrying a
  `GearOption` compare on captured variable values too.
- The shared `CheckboxGroup` component gained an optional per-option conditional-reveal (generic with
  a backwards-compatible convenience init) so the SelectGear screen can reveal a field only while an
  option is ticked. Recorded as a DesignSystem deviation for governance (no existing component
  rendered a conditional reveal).
- Accessibility: revealed content is a single simple field placed directly after its checkbox in the
  accessibility tree, per GOV.UK guidance (which notes the WCAG 2.2 SC 4.1.2 known limitation that
  screen-reader users are not always notified of a reveal; simple reveals tested acceptably).
- Offline-first is preserved: values are captured into the in-memory `CatchRecordDraft`; no network
  or persistence is added here.
- Standing obligation: on-device persistence/sync of captured measurements is covered by the future
  persistence ADR foreshadowed in ADR-0005; the real gear reference-data API remains behind the
  ADR-0004 stub seam.

## References

- ADR-0004 (port selection, favourites, API-stub seam), ADR-0005 (`CatchRecordDraft`).
- GOV.UK Design System, *Checkboxes — Conditionally revealing a related question* —
  https://design-system.service.gov.uk/components/checkboxes/
- W3C, *WCAG 2.2 SC 4.1.2 Name, Role, Value* —
  https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- Swift API Design Guidelines — https://www.swift.org/documentation/api-design-guidelines/
