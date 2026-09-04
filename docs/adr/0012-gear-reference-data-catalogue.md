# ADR 0012 — Gear reference-data catalogue (replaces the single seine-nets stub)

- Status: Accepted
- Date: 2026-09
- Deciders: iOS engineering (with product/data confirmation from the user)
- Context tags: domain-model, reference-data, localisation, offline-first, api-stub-seam, native-iOS

## Context

Until now `StubGearSearchProvider` (and therefore the Add-gear search screen) offered a single
gear, "Seine nets (not specified)", as a stand-in for the future gear reference-data API (see
ADR-0004). The product owner supplied the real MMO fishing-gear reference list — 39 rows of `Code`,
`Fishing Gear Description`, and up to two **Measurement** columns (fixed properties, captured once
per favourite — ADR-0010's `requiredMeasurements`) and two **Detail** columns (per-trip values,
captured each time the gear is used — ADR-0010's `variableMeasurements`).

The source list had two data-quality issues, resolved with the user before implementation:

- The FAO code `PS1` was used twice, for both "One boat operated purse seine" and "Purse seine".
  Since `GearOption.id` is the stable identity favourites are keyed on (see `FavouriteGearProvider`
  and `GearCatch.id`), a duplicate id would silently collapse two different gears. **Resolved:**
  "One boat operated purse seine" is removed; "Purse seine" is renamed to the unique code `PS`.
- `NK` (Gear not known/not specified) and `RG` (Recreational gear) are out of scope for this app and
  are **removed** entirely, per the user's explicit instruction.

Four gears in the source list define **no** measurements at all: `NK`, `RG` (both removed, above),
`HMD` (Mechanised dredges) and `MIS` (Miscellaneous gear (diving)). The existing journey had no
defined behaviour for a gear with an empty `requiredMeasurements` list — `GearMeasurementsView`
would render a heading and hint with no fields at all. Confirmed with the user: such a gear should
be **followed as designed** rather than given synthetic measurements, and the "Enter the
measurements for `<gear>`" screen should be **skipped** for it.

## Decision

### 1. `GearOption.all` — the full catalogue, keyed by FAO code

`GearOption.id` switches from "the display name" (the seine-nets-only stub's shortcut) to the
stable **FAO gear code** (e.g. `TBB`, `OTB`, `GTN`). `GearOption.all: [GearOption]` supplies all 36
gears (39 source rows − `NK` − the duplicate `PS1` − `RG`), and is the new default for
`StubGearSearchProvider`. `GearOption.seineNets` (code `SX`) is kept as a named handle for existing
previews/tests and also appears in `all`.

### 2. A shared, de-duplicated measurement catalogue

The 39 source rows use only **13 distinct questions** (5 required, 8 variable). Each is declared
once as a `static let` on `GearMeasurement` (e.g. `.meshSize`, `.numberOfTrawlNets`, `.hooksHauled`,
`.netLengthLeft`) and referenced by every gear that asks it, rather than re-declaring the same
`id`/`labelKey` pair per gear.

### 3. Zero-measurement gears skip the measurements screen

`AddGearViewModel.submit()` now branches on `gear.requiredMeasurements.isEmpty`:

- **Non-empty** (the previous, only behaviour): push `.gearMeasurements(...)` as before.
- **Empty** (`HMD`, `MIS`): save the gear straight to favourites via the injected
  `FavouriteGearProviding` and push `.selectGear(...)` directly, skipping the now-empty
  measurements screen entirely. `AddGearViewModel` gains a `favouriteGears` dependency (mirroring
  `GearMeasurementsViewModel`) plus `isSaving`/`saveFailed` state for this path, and `AddGearView`
  gains the same save-failed error banner pattern already used by `GearMeasurementsView`.
  `CatchRecordHostView` now threads its shared `favouriteGears` store into `AddGearView`.

A gear with no **variable** measurements (most of the zero-required gears, plus any gear that only
defines one kind) already renders no conditional-reveal field on `SelectGearView` — no change
needed there.

### 4. Generic favourite summary, not mesh-size-specific

`SelectGearView.measurementSummary(for:)` previously hard-coded a mesh-size-shaped summary format
(`"%dmm mesh"`). It now builds a generic `"<label>: <value>"` summary per captured required
measurement (String Catalog key `catchRecord.gear.measurement.summary`, format `"%@: %d"`), joined
with ", " when a gear has several (e.g. beam trawl: "Mesh size (mm): 100, Number of beams: 2"). This
is a deliberate content deviation from the previous bespoke phrasing, recorded here for governance —
the generic form was chosen because 35 of the 36 gears are no longer mesh-only.

### 5. Wording reconciled to the source reference data

The existing `catchRecord.gear.variableMeasurement.timesShot` copy ("...shot on trip") is updated to
match the source list's wording ("...shot **on the trip**"). The existing
`catchRecord.gear.measurement.meshSize` label ("Mesh size (mm)") is kept in sentence case per GOV.UK
content style, rather than adopting the source list's title-case "Mesh Size (mm)" verbatim — GOV.UK
guidance treats sentence case as the correct on-screen convention regardless of a data source's own
casing.

### 6. Welsh translations flagged `needs_review`

Every new measurement/detail label gets a best-effort Welsh translation, added with
`state: needs_review` and a translator `comment` (mirroring ADR-0002's `[CY-TODO]` convention),
since several are specialist fishing-gear terms this change could not get professionally verified.
These markers are comment-only and never appear in a user-visible `value`, per ADR-0002 §4.

## Consequences

- `GearOption.id` is no longer guaranteed to equal `GearOption.name`; any code that assumed the two
  were interchangeable (none found beyond the removed mesh-size-specific summary) must key off `id`.
  Accessibility identifiers derived from `gear.id` (e.g. `CatchRecord.selectGear.option.<id>`,
  `CatchRecord.checkYourAnswers.section.gear.<id>`) changed from a lower-cased gear name to a
  lower-cased FAO code (`...option.sx`, `...section.gear.SX`); the UI/unit tests referencing these
  were updated in the same change.
- The Add-gear search screen now offers 36 real gears instead of one; `AddGearViewModelTests` seed an
  explicit single-gear `StubGearSearchProvider` where a test's intent is to stay scoped to one gear,
  rather than relying on the provider's default.
- Offline-first is preserved: this is reference data plus a UI-only stub provider change; no
  network or persistence is introduced. The real gear reference-data API remains behind the
  ADR-0004 stub seam — `GearOption.all` is exactly the shape that API is expected to return.
- Standing follow-up: a Welsh speaker must review the `needs_review` translations before public
  beta, per the accessibility/Welsh Language Standards obligation (ADR-0002, DEFRA constraint §3).
- Standing data-quality note: the `PS1` duplicate and the `NK`/`RG` removals were resolved directly
  with the product owner for this change; if the future real Gear API supplies its own canonical
  codes, this catalogue should be reconciled against it rather than assumed authoritative long-term.

## References

- ADR-0004 (API-stub seam), ADR-0010 (required vs variable measurement split), ADR-0011 (per-gear
  catch grouping), ADR-0002 (localisation and `needs_review`/`[CY-TODO]` convention).
- GOV.UK Design System — content style, sentence case: https://www.gov.uk/guidance/style-guide/a-to-z-of-gov-uk-style
