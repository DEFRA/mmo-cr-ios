# CatchRecord module

`Features/CatchRecord/` implements the **"Create a catch record"** journey for the MMO Catch
Recording app — the multi-screen flow a fisher uses to record a trip (vessel, dates, ports, gear,
species caught) and confirm submission. This document covers the whole module: architecture,
navigation, every screen, the shared journey state, data models, and how offline-first,
accessibility and testing are handled throughout.

This is a **UI-only phase**: there is no real backend yet. Every "API" (vessels, ports, gears,
species, favourites) is a stubbed, protocol-shaped provider so a real implementation can be swapped
in later without changing view models or their tests. Nothing is persisted to disk yet — see
[ADR-0005](../../../docs/adr/0005-catch-record-draft-model.md) for the planned persistence work.

## Related ADRs and design specs

- [ADR-0001 — App architecture pattern](../../../docs/adr/0001-app-architecture-pattern.md) (MVVM)
- [ADR-0003 — Create-a-catch-record navigation](../../../docs/adr/0003-create-catch-record-navigation.md)
  (typed route enum + router, why not `NavigationPath`)
- [ADR-0004 — Port selection: API-shaped stub seam](../../../docs/adr/0004-port-selection-and-api-stub-seam.md)
  (provider protocols, per-user favourites, routing/branching pattern reused by gear and species)
- [ADR-0005 — Catch record draft model](../../../docs/adr/0005-catch-record-draft-model.md)
  (`CatchRecordDraft`, the shared journey-scoped state)
- [Design spec — Create a catch record, Part 1](../../../docs/design-specs/create-catch-record.md)
  (copy table, states, accessibility annotations for the first screens)

## Architecture

- **Pattern:** MVVM. Every screen is a `View` + `@Observable` `@MainActor` `ViewModel` pair. Views
  hold no business logic — they render state and forward intents (`submit()`, `addAnother()`, …) to
  the view model.
- **Validation:** each screen with a required answer has a small, pure, static `...Validation` enum
  (e.g. `DraftActionValidation`, `SelectVesselValidation`) that maps the current selection to a
  String Catalog error key or `nil`. Pure functions are trivially unit-testable without a view host.
  The pattern throughout: `didAttemptSubmit` gates the error (nothing is shown before the first
  "Save and continue"), and a failed validation **never navigates** — the user stays on the screen
  with a recoverable, accessible inline error.
- **Routing:** a single typed, homogeneous route enum (`CatchRecordRoute`) backs one
  `NavigationStack`, owned by `CatchRecordRouter`. See [Navigation & routing](#navigation--routing).
- **Shared state:** two flavours, both offline-first with a local, in-memory source of truth:
  - `CatchRecordDraft` — one journey-scoped accumulator of every value captured so far (vessel,
    dates, ports, gear, species). See [CatchRecordDraft](#catchrecorddraft).
  - Favourites providers (`FavouritePortsProviding`, `FavouriteGearProviding`,
    `FavouriteSpeciesProviding`) — per-user saved lists, shared across the screens in a journey so an
    item added on an "Add ⟨thing⟩" screen is immediately visible on the select/summary screen the
    user returns to. See [Providers & data models](#providers--data-models).
- **Async work:** `Task { await ... }` from a synchronous `submit()`/intent method for the async
  branching decisions (fetch favourites → decide next route). The route decision itself
  (`CatchRecordRouting`) is kept **pure**, so it is unit-testable without async/await ceremony.

## Navigation & routing

Everything lives in `Routing/`:

| File | Responsibility |
|---|---|
| `CatchRecordRoute.swift` | The `Hashable` enum of every screen in the journey, each case carrying exactly the payload its destination needs (vessel name, reference number, gear, phase enums, etc.) — there is no shared "journey context" object threaded implicitly; see ADR-0003/0004. |
| `CatchRecordRouter.swift` | `@Observable` owner of `path: [CatchRecordRoute]`. `startFromDraft(_:)` / `startNew()` seed the stack; `push`/`pop`/`popToRoot`/`setPath` are the only ways screens navigate — no `NavigationLink`s in the feature code. Conforms to `HeaderNavigating` so the custom `ViewHeader`'s back button works. |
| `CatchRecordRouting.swift` | Pure, static **entry-route decisions** shared by several screens: `entryRoute(for:)` (Home table tap), `portEntryRoute`, `gearEntryRoute`, `speciesEntryRoute` (has-favourites? select screen : add screen). Kept out of the router/views so these branch points are unit-testable with no `NavigationStack` host. |
| `CatchRecordHostView.swift` | Hosts the single `NavigationStack`, binds it to the router's `path`, and maps every `CatchRecordRoute` case to its destination `View`. Injects the shared `CatchRecordRouter`, `CatchRecordDraft` and favourites providers into the environment/call sites so every screen shares one instance per journey. |

### Journey map

```
Home ──(Unsent row)──► DraftAction ──(Complete)──► SelectVessel
Home ──(Create new)───────────────────────────────► SelectVessel
                                                          │
                                                          ▼
                                              TripStartedToday
                              ┌───────(Yes)───────────────┴───────(No)───────────┐
                              ▼                                                  ▼
                     [enter port sub-journey]                          TripDate(.departure)
                                                                                  │
                                                                                  ▼
                                                                         TripDate(.return)
                                                                     (late? ──► SubmissionNudge)
                                                                                  │
                                                                                  ▼
                                                                     [enter port sub-journey]
                                                                                  │
              ┌───────────────────────────────────────────────────────────────────┘
              ▼
   has favourite ports? ──No──► AddPort ──(save)──► SelectPort(.departure)
              │Yes
              ▼
   SelectPort(.departure) ──► SelectPort(.return)
                                        │
                          has favourite gears? ──No──► AddGear ──► GearMeasurements ──(save)──► SelectGear
                                        │Yes                                                          │
                                        ▼                                                             │
                                  SelectGear ◄─────────────────────────────────────────────────────────┘
                                        │
                                        ▼
                                 CatchLocation (map)
                                        │
                       has favourite species? ──No──► AddSpecies ──► RecordSpeciesWeights
                                        │Yes                                   │
                                        ▼                                     │
                              RecordSpeciesWeights ◄───────────────────────────┘
                                        │ (Add a species ──► AddSpecies ──► back here)
                                        ▼
                                SpeciesSummary (remove / add another / continue)
                                        │
                                        ▼
                                LandingStorage  (Yes/No — kept onboard?)
                         ┌──────(Yes)───────┴───────(No)──────┐
                         ▼                                    │
              LandingStorageSpecies                           │
                         └──────────────────┬──────────────────┘
                                             ▼
                                   CheckYourAnswers
                                             │
                                             ▼
                                SubmissionConfirmation
                                             │
                                             ▼
                                  PlaceholderNextStep  (future phase)
```

## Screens

Each screen folder follows the same shape: `<Screen>View.swift`, `<Screen>ViewModel.swift`, and
(when it has a required answer) a `<Screen>Validation.swift`. Accessibility identifiers are
namespaced `CatchRecord.<screenId>.*` throughout (e.g. `CatchRecord.selectVessel.saveContinue`).

| # | Folder | Route case | Purpose | Continues to |
|---|---|---|---|---|
| 1 | `DraftAction/` | `.draftAction(SubmissionRow)` | What to do with an existing **Unsent** draft record: Complete or Delete (destructive `confirmationDialog`, requires explicit confirm). | Complete → `.selectVessel`; Delete confirmed → `popToRoot()` (Home) |
| 2 | `SelectVessel/` | `.selectVessel` | Pick the vessel for a new trip, from `VesselProviding` (stubbed: ACHILLES, HERCULES). Writes `draft.vessel`. | `.tripStartedToday` |
| 3 | `TripStartedToday/` | `.tripStartedToday` | Yes/No — did the trip start and finish today? | Yes → port sub-journey; No → `.tripDate(.departure)` |
| 4 | `TripDate/` | `.tripDate(phase:...)` | Reusable day/month/year date entry for departure **and** return (driven by `TripDatePhase`). Writes `draft.departureDate`/`draft.returnDate`. | Departure → `.tripDate(.return)`; Return → late? `.submissionNudge` : port sub-journey |
| 5 | `SubmissionNudge/` | `.submissionNudge(daysLate:...)` | Interposed only when the trip ended **>24h** ago (`SubmissionNudge.isNeeded`, injectable clock). Reminds the user records must be submitted within 24h, with a link back to correct the date. | port sub-journey |
| 6 | `AddPort/` | `.addPort(...)` | Type-to-search a port; shown only when the user has **no favourite ports**. Saves to favourites. | `.selectPort(<returnPhase ?? .departure>)` |
| 7 | `SelectPort/` | `.selectPort(phase:...)` | Reusable radio list of favourite ports for departure **and** return (`SelectPortPhase`), plus "Add another port". Writes `draft.departurePort`/`draft.returnPort`. | Departure → `.selectPort(.return)`; Return → gear sub-journey |
| 8 | `AddGear/` | `.addGear(...)` | Type-to-search a gear (only Seine nets in this phase); shown when there are **no favourite gears**. | `.gearMeasurements` |
| 9 | `SelectGear/` | `.selectGear(...)` | Multi-select checkboxes of favourite gears, plus "Add another gear". Writes `draft.gear`. | `.catchLocation` |
| 10 | `GearMeasurements/` | `.gearMeasurements(gear:...)` | Whole-number measurement entry for a gear (e.g. mesh size for seine nets); saves the gear (with values) to favourites. | `.selectGear` |
| 11 | `CatchLocation/` | `.catchLocation(gear:...)` | Pick the statistical area on a map (`SeaMapView`). Writes `draft.statisticalArea`. | species sub-journey |
| 12 | `AddSpecies/` | `.addSpecies(...returnPhase:)` | Type-to-search a species; shown when there are **no favourite species**. `returnPhase` records where to return (weights screen vs summary). | back to `returnPhase` screen |
| 13 | `RecordSpeciesWeights/` | `.recordSpeciesWeights(gear:...)` | Tick favourite species and enter live weights (above minimum always shown; below-minimum/legally-discarded are reveal-able optional fields). Weight validation is deferred — free text for now. | `.speciesSummary` |
| 14 | `SpeciesSummary/` | `.speciesSummary(gear:...)` | Read-only list of recorded species with remove/add-another. Writes `draft.speciesCaught`. | `.landingStorage` |
| 15 | `LandingStorage/` | `.landingStorage(...)` | Yes/No — any catch not landed straight away (bait/keep pots)? | Yes → `.landingStorageSpecies`; No → `.checkYourAnswers` |
| 16 | `LandingStorageSpecies/` | `.landingStorageSpecies(...)` | Tick species kept onboard/in keep pots and record one weight each. Writes `draft.speciesNotLanded`. | `.checkYourAnswers` |
| 17 | `CheckYourAnswers/` | `.checkYourAnswers(...)` | Read-only summary of the whole `CatchRecordDraft` in four sections (Trip, Gear used, Species caught, Species not landed); each row's "Change" control pushes **forward** into the journey at the screen that captured it. | `.submissionConfirmation` |
| 18 | `SubmissionConfirmation/` | `.submissionConfirmation(...)` | Final "Confirmation" screen: explains what submitting means (weight accuracy, tolerance levels, enforcement), requires a single confirmation checkbox before "Accept and submit trip details" proceeds. | `.placeholderNextStep` |
| 19 | `PlaceholderNextStep/` | `.placeholderNextStep` | Minimal, no-view-model placeholder ending the journey until the next phase (real submission) is built. | — |

### 1. Draft action (`DraftAction/`)

Reached only from an **Unsent** row on the Home submissions table
(`CatchRecordRouting.entryRoute(for:)` — every other status resolves to `nil` and stays inert).
`DraftActionOption` is `.complete`/`.delete`. Deleting requires a destructive
`confirmationDialog` (`showDeleteConfirmation`); confirming calls `router.popToRoot()`, cancelling
just dismisses the dialog leaving the selection untouched.

### 2. Select vessel (`SelectVessel/`)

`VesselProviding` is the (stubbed) source of the vessel list (`StaticVesselProvider`: ACHILLES,
HERCULES). Generates the journey's **placeholder reference number**
(`SelectVesselViewModel.placeholderReferenceNumber`, a static UI-only value, not derived from any
backend — see the design spec's reference-number note) and threads it through every later screen.

### 3–5. Trip started today / Trip date / Submission nudge

`TripStartedToday` short-circuits straight into the port sub-journey when the trip is today
("Yes"); otherwise `TripDate` is shown twice — once per `TripDatePhase` (`.departure`/`.return`) —
as the same reusable screen (heading/hint/accessibility ids all driven off the phase). On a valid
**return** date, `SubmissionNudge.isNeeded(tripEndDate:now:)` (an injectable clock keeps this
deterministic in tests) decides whether to interpose the nudge screen before continuing into the
port sub-journey.

### 6–7. Add port / Select port

Mirrors the pattern described in ADR-0004: `AddPort` (search + save-to-favourites) is shown only
with **no favourites yet**; `SelectPort` is the same `View`/`ViewModel` reused for both the
departure and return picks via `SelectPortPhase`. `CatchRecordRouting.portEntryRoute` is the pure
decision of which of the two screens to enter on. "Add another port" carries the current phase as
`returnPhase` so saving returns to the right select screen.

### 8–10. Add gear / Select gear / Gear measurements

Same has-favourites branching as ports (`CatchRecordRouting.gearEntryRoute`), but gear also needs a
measurements step: `GearMeasurements` collects one whole-number field per
`GearMeasurement` the gear declares (only mesh size, for Seine nets, in this phase), attaches the
parsed values (`GearMeasurementValidation.parse`), saves the gear to favourites, and returns to
`SelectGear` so the user can tick it. `SelectGear` uses **checkboxes** (multi-select), unlike the
single-select port/vessel radio screens, though only the first ticked gear is currently threaded
into `draft.gear` (single-gear support in this phase).

### 11. Catch location (`CatchLocation/`)

Renders the existing `SeaMapView`/`SeaMapCoordinator` (see `Features/Map/`) so the user taps a
statistical subzone. `CatchLocationValidation.errorKey(for:)` requires a non-nil selection before
continuing. On success, fetches favourite species and pushes the pure
`CatchRecordRouting.speciesEntryRoute` decision (mirrors port/gear entry).

### 12–14. Add species / Record species weights / Species summary

Same has-favourites pattern again. `RecordSpeciesWeights` is the richest screen in the module:
per-species ticking plus three weight fields (`aboveEntries` always shown once ticked;
`belowEntries`/`discardedEntries` are optional, user-revealed/removable via
`reveal…`/`remove…` methods) — all free-text for now, numeric validation deferred to a future
phase. `loadFavourites()` re-seeds selection/reveal state from anything already captured, so
returning to the screen (e.g. via a Check-your-answers "Change" link) shows prior answers.
`SpeciesSummary` is the read-only list with remove/add-another, and is what actually writes
`draft.speciesCaught` on continue.

### 15–16. Landing storage / Landing storage species

A Yes/No gate (`LandingStorageOption`) for whether any catch is being kept onboard/in keep pots
rather than landed immediately. "Yes" branches into `LandingStorageSpecies` — the same
tick-species-and-enter-weight shape as `RecordSpeciesWeights`, but with a single weight field per
species — which writes `draft.speciesNotLanded`. Both branches converge on `.checkYourAnswers`.

### 17. Check your answers (`CheckYourAnswers/`)

Purely a **projection** of `CatchRecordDraft` — the view model holds no mutable state of its own
and performs no validation, so it's directly unit-testable against a seeded draft. Four ordered
sections (`Section`/`Row` structs): **Trip** and **Gear used** always render (even with zero rows);
**Species caught**/**Species not landed** are omitted entirely when empty. Every row carries a
`changeRoute` back to the screen where that value was captured; tapping "Change" **pushes forward**
(not a pop) so the existing "Save and continue" flow naturally returns here.

### 18. Submission confirmation (`SubmissionConfirmation/`)

The final gate before "submission". A bold notice (icon + sentence, meaning never conveyed by
colour/icon alone) explains what submitting means, followed by a three-point bullet list and a
single required confirmation checkbox (`CheckboxGroup` with one option). "Accept and submit trip
details" validates the checkbox (`SubmissionConfirmationValidation`) — an inline error shows and the
screen does **not** navigate until it's ticked. A real submit action doesn't exist yet, so a
confirmed accept continues to `.placeholderNextStep`.

### 19. Placeholder next step (`PlaceholderNextStep/`)

Deliberately has no view model — no state or behaviour yet. Marks where the next phase (a real
submission/success screen, backed by a real API) will be built.

## Providers & data models

`Features/Common/Data/` holds the module's shared, API-shaped stub seam (see ADR-0004):

- **`PortOption` / `GearOption` (+ `GearMeasurement`) / `SpeciesOption`** — `nonisolated`,
  `Sendable` value types with a stable `id` (currently the name, for the stub) so a real API-backed
  provider can later supply server identifiers without changing call sites. Each has a
  `with…(...)` copy-and-modify helper (`withMeasurements`, `withWeights`) instead of mutable state.
- **`FavouritePortsProvider` / `FavouriteGearProvider` / `FavouriteSpeciesProvider`** — each defines
  an async `…Providing` protocol (`favouritePorts()`/`addFavourite(_:)`, etc., plus
  `removeFavourite(id:)` for species) and a `Stub…Provider` in-memory, reference-typed
  implementation. Favourites are **per-user**, not per-vessel, and are the **local, offline-first
  source of truth** for every select/summary screen — nothing is written to disk yet.
- **`PortSearchProvider` / `GearSearchProvider` / `SpeciesSearchProvider`** — the separate
  "search the full catalogue" stub seam used by the Add-⟨thing⟩ screens, distinct from the
  favourites the user has already saved.
- **`VesselProviding`** (in `SelectVessel/`) — the (stubbed) vessel list; not yet a full
  provider/favourites pair since only two vessels exist in this phase.
- **`SubmissionRow`** (`Common/Components/Table/SubmissionsTable.swift`) — a Home submissions-table
  row (date, vessel, `SubmissionStatus`, created-by); only an `.unsent` row has a defined
  `CatchRecordRoute` entry point in this phase.

### `CatchRecordDraft`

`Features/Common/Data/CatchRecordDraft.swift` — the single, `@Observable`, `@MainActor`,
journey-scoped accumulator shared across every screen in the stack (injected by
`CatchRecordHostView`, mirroring the favourites providers). It **complements** the route-payload
approach rather than replacing it: routes still carry the specific values a destination needs for
its own display/deep-linking, while the draft accumulates the whole in-progress record for the
Check-your-answers summary and eventual submission.

```swift
final class CatchRecordDraft {
    var vessel: String?
    var departureDate: Date?
    var returnDate: Date?
    var departurePort: PortOption?
    var returnPort: PortOption?
    var statisticalArea: String?
    var gear: GearOption?
    var speciesCaught: [SpeciesOption] = []
    var speciesNotLanded: [SpeciesOption] = []
}
```

Not persisted to disk in this phase — see ADR-0005 and the "future ADR" notes throughout this
module for the planned on-device persistence/sync work.

## Offline-first

Per the DEFRA mobile standards and the app-wide mandatory constraint, this module assumes **no
connectivity by default**:

- Every "API" is a stubbed, protocol-shaped, in-memory provider — no live network calls exist yet.
- Favourites (ports/gears/species) and the draft are local, in-memory sources of truth, shared for
  the lifetime of a journey via reference types injected once at `CatchRecordHostView`.
- Screens that "save" (Add-port/gear/species, Gear measurements, Record species weights, Landing
  storage species) surface a `saveFailed` flag with a recoverable, accessible inline error banner
  rather than crashing or silently discarding input, ready to become real network/persistence
  failures later without changing the view/view-model contract.
- Nothing here is persisted across app restarts yet — that is explicit future-phase scope (see
  ADR-0005), not an oversight.

## Accessibility

Every screen follows the same conventions (see the
[accessibility instructions](../../../.github/instructions/accessibility.instructions.md) and the
design spec's accessibility annotations):

- Copy renders via the shared `TitleText`/`ParagraphText`/`LocalizedText` components — no fixed
  frames, so Dynamic Type scales to 200%/accessibility sizes without clipping.
- `RadioGroup`/`CheckboxGroup` render one accessibility container per question, `.isSelected` on
  chosen options (never colour alone), and a combined "Error: ⟨message⟩" element (icon + red text +
  red border) that does **not** navigate when shown.
- Destructive actions (delete a draft) use a `.destructive` `confirmationDialog` requiring an
  explicit second tap.
- "Change" links and other secondary actions are real `Button`s with the `.isLink` trait and a
  44×44pt minimum target, with a composed label (e.g. "Change Departure port") rather than a bare
  "Change".
- Every screen accepts the active locale via `.environment(\.locale, languageStore.language.locale)`
  so VoiceOver pronunciation matches the selected language (English/Welsh).

## Localisation

All copy goes through `AppLanguageStore.localized(_:)` / `LocalizedText`, backed by
`Resources/Localizable.xcstrings`. Because the String Catalog is a structured file this agent
cannot hand-edit reliably, new keys are added via small, idempotent Python scripts in `scripts/`
(e.g. `add_submission_nudge_strings.py`, `add_submission_confirmation_strings.py`) — each skips
keys that already exist and marks Welsh values `needs_review` (never a `[CY-TODO]` prefix in
rendered copy) pending real translation.

## Testing

- **Unit tests** (`record-catchTests/Feature/CatchRecord/`) mirror the source tree: one
  `…ViewModelTests` and, where applicable, one `…ValidationTests` per screen, plus
  `CatchRecordRouterTests`/`CatchRecordRoutingTests` for the shared navigation/branching logic.
  View models are tested with an in-memory `CatchRecordRouter` and stub providers — no
  `NavigationStack` host required.
- **UI tests** (`record-catchUITests/CatchRecordUITests.swift`) drive critical journeys end-to-end
  via stable `CatchRecord.*` accessibility identifiers, seeded by dedicated `-uiTestCatchRecord…`
  launch arguments in `record_catchApp.swift` (e.g. `-uiTestCatchRecordCheckYourAnswers`,
  `-uiTestCatchRecordSubmissionConfirmation`) so a mid-journey screen can be UI-tested without
  driving the whole flow by hand.
- Coverage targets follow the project-wide gate: **≥95%** for view models/services/routing logic,
  **100%** for validation/error-handling paths — see the
  [testing instructions](../../../.github/instructions/testing.instructions.md).
