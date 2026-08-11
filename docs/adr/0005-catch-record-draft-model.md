# ADR 0005 — A single journey-scoped `CatchRecordDraft` as the offline-first source of truth

- Status: Accepted
- Date: 2026-08
- Deciders: iOS engineering
- Context tags: architecture, offline-first, navigation, native-iOS

## Context

The "Create a catch record" journey (ADR-0003) currently threads data between screens **only**
through `CatchRecordRoute` associated values (e.g. `vessel`, `referenceNumber`, `departureDate`,
`gear`), and through the per-domain favourites providers (`FavouritePortsProviding`,
`FavouriteGearProviding`, `FavouriteSpeciesProviding` — ADR-0004). There is no single place holding
the **whole** in-progress catch record. As the journey grows towards a "Check your answers" summary
screen and eventual submission, every value captured across the journey (vessel, dates, ports,
statistical area, gear, species caught and not landed) needs to be available in one place without
re-deriving it from a chain of route payloads, and without an intervening screen accidentally
dropping a value it doesn't itself need.

Per the DEFRA
[mobile application standards](https://defra.github.io/software-development-standards/standards/mobile_app_standards/),
the app must remain offline-first with local data as the source of truth.

## Decision

### 1. Introduce `CatchRecordDraft`: a single, journey-scoped, reference-typed model

`CatchRecordDraft` is a `@MainActor @Observable final class` with mutable properties for every
value captured across the journey: `vessel`, `departureDate`, `returnDate`, `departurePort`,
`returnPort`, `statisticalArea`, `gear`, `speciesCaught`, `speciesNotLanded`. It is constructed once
per journey by `CatchRecordHostView` (mirroring how `favouritePorts`/`favouriteGears`/
`favouriteSpecies` are constructed and shared today) and is the **single source of truth** for the
in-progress record: any screen that captures a value writes it here; any screen that needs to
display a previously-captured value (notably a future "Check your answers" screen) reads it here,
rather than reconstructing it from route payloads.

### 2. Complements, not replaces, ADR-0003/ADR-0004 route payloads

Route payloads continue to carry the specific values a destination needs for its own routing and
display logic — for example, so UI tests can deep-link straight into a mid-journey screen via
`-uiTestCatchRecord*` launch arguments without needing a pre-populated draft, and so each screen's
tests remain simple, explicit unit tests against known inputs. `CatchRecordDraft` does not remove
any existing route associated values in this phase; it adds a parallel, accumulating record of the
**whole** journey alongside them. A later phase may reduce duplication once the draft is threaded
through every screen, but that is out of scope here.

### 3. Offline-first, in-memory only for now

`CatchRecordDraft` is not persisted to disk in this phase — it lives only as long as the
`CatchRecordHostView` instance (i.e. the current app session/journey). If the app is terminated
mid-journey, the draft is lost today, matching current behaviour (the same is true of the existing
favourites providers and route path). A **future ADR** will cover on-device persistence (e.g.
SwiftData) of the in-progress draft so a journey can be resumed after termination, and any
sync/conflict resolution needed once a real backend exists.

## Consequences

- `CatchRecordHostView` gains a `draft: CatchRecordDraft` property, constructed with a default and
  overridable at `init`, and injected into the environment (`.environment(draft)`) alongside the
  router — consistent with how the favourites providers are wired.
- View models are not yet changed to read from or write to `draft` in this phase; that wiring is
  deferred to a later phase per-screen, minimising the size of this change.
- `@Observable` and `@MainActor` mean SwiftUI views can read `draft` directly without additional
  binding plumbing, and all mutation happens on the main actor, matching the rest of the journey's
  view models.
- Standing obligation (per ADR-0001): persistence and sync of the draft will get their own ADR when
  implemented.

## References

- DEFRA, *Mobile application standards* (offline-first) —
  https://defra.github.io/software-development-standards/standards/mobile_app_standards/
- Apple, *Observation* — https://developer.apple.com/documentation/observation
- ADR-0001 (architecture), ADR-0003 (Create-a-catch-record navigation), ADR-0004 (port selection,
  favourites, API-stub seam).
