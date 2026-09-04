# ADR 0004 — Port selection: API-shaped stub seam, per-user offline-first favourites, and routing

- Status: Accepted
- Date: 2026-08
- Deciders: iOS engineering
- Context tags: navigation, architecture, offline-first, networking-shape, native-iOS

## Context

The "Create a catch record" journey continues after the trip-date sub-journey with **port
selection**: the user records the port they left from and the port they returned to. The design
has three screens:

1. **Add port** — a "type to search" autocomplete ("Add port to vessel ACHILLES"). Shown only when
   the user has **no saved (favourite) ports yet**. Selecting and saving a port **adds it to the
   user's favourite ports**.
2. **Which port did you leave from?** — a radio group of the user's favourite ports, plus an
   "Add another port" secondary button.
3. **Which port did you return to?** — the **same reusable screen** as (2), for the return port.

Two data sources are involved, both described by the product as APIs: the **list of ports** to
search, and the user's **favourite ports**. Neither backend exists yet, so both are **stubbed**
for this phase. This is the app's first **networking-shaped** abstraction, which ADR-0001 said
would warrant its own ADR. This ADR records the port routing/branching and the shape of that stub
seam. It does **not** introduce real endpoints or real persistence — a **future ADR** will cover
the real Ports/Favourites API and offline sync/persistence.

Per the DEFRA
[mobile application standards](https://defra.github.io/software-development-standards/standards/mobile_app_standards/)
we "assume we are providing an offline mobile app": local data is the source of truth and the app
must remain useful without connectivity.

## Decision

### 1. API-shaped provider protocols, stubbed, async-first

We model both data sources as `async throws` provider protocols now, so a real API-backed
implementation can swap in later without changing the view models or their tests:

```swift
struct Port: Identifiable, Hashable { let id: String; let name: String }

protocol PortSearchProviding {
    /// Ports matching `query` (empty when the query is shorter than the minimum).
    func searchPorts(matching query: String) async throws -> [Port]
}

protocol FavouritePortsProviding {
    func favouritePorts() async throws -> [Port]
    func addFavourite(_ port: Port) async throws
}
```

- Async-now avoids a churny sync→async migration when the real API lands, and matches the DEFRA
  Swift Concurrency direction.
- The stubs (`StubPortSearchProvider`, `StubFavouritePortsProvider`) keep a deterministic
  in-memory list of UK ports; `StubFavouritePortsProvider` holds favourites in an in-memory,
  reference-typed store so an added favourite is visible to later screens **within a journey**.
  No data is written to disk in this phase.

### 2. Favourites are **per-user**, not per-vessel

The app maintains a single **user-scoped** list of favourite ports. The "Add port to vessel
`<VESSEL>`" header shows the current vessel name **for context only**; it does not filter the
favourites list. `FavouritePortsProviding` therefore takes **no vessel parameter**. Favourites are
**offline-first** with a **local source of truth**; the provider is stubbed pending the real API.

### 3. Local favourites are the source of truth for the select screens

Screens (2) and (3) render the user's favourite ports from `FavouritePortsProviding`. Adding a
port on the Add-port screen updates that list, so the newly-added port appears on the select
screen the user returns to.

### 4. Routing and branching (extends ADR-0003)

We add routes to `CatchRecordRoute` and thread the selected **vessel name** and reference number
through the payloads, consistent with ADR-0003's route-payload approach (there is no shared
journey-context object; every destination carries the data it needs):

```swift
enum CatchRecordRoute: Hashable {
    // …existing…
    case tripStartedToday(vessel: String, referenceNumber: String)
    case tripDate(phase: TripDatePhase, vessel: String, referenceNumber: String, departureDate: Date?)
    case addPort(vessel: String, referenceNumber: String, returnPhase: SelectPortPhase?)
    case selectPort(phase: SelectPortPhase, vessel: String, referenceNumber: String)
    case placeholderNextStep
}
```

- `SelectVesselViewModel` now **captures** the chosen vessel (previously discarded) and threads it
  onward, so the port headers can render the vessel name.
- **Port entry decision** is a pure, testable function in `CatchRecordRouting`:
  `portEntryRoute(hasFavourites:vessel:referenceNumber:)` → `.selectPort(.departure, …)` when the
  user already has favourites, else `.addPort(…, returnPhase: nil)`. The async favourites fetch
  happens in the calling view model; the decision itself stays pure.
- **"Add another port"** on a select screen pushes `.addPort(…, returnPhase: <current phase>)`
  (the ports search screen). After a successful save, `AddPortViewModel` routes back to the
  correct select screen:
  - `returnPhase == nil` (first-time entry, no favourites yet) → `.selectPort(.departure, …)`;
  - `returnPhase == .departure` → `.selectPort(.departure, …)`;
  - `returnPhase == .return` → `.selectPort(.return, …)`.
  The newly-added favourite is present in the list; no option is pre-selected.
- The reusable select screen is driven by a `SelectPortPhase` enum (`.departure` / `.return`),
  mirroring the existing `TripDatePhase` reuse.

### 5. Scope: still stubbed, no real IO

No real endpoints, no on-disk persistence, no auth in this phase. A **future ADR** covers the real
Ports/Favourites API, on-device persistence (e.g. SwiftData), offline queue and sync/conflict
resolution.

## Consequences

- View models depend only on protocols (`PortSearchProviding`, `FavouritePortsProviding`,
  `CatchRecordRouter`) and a pure router helper, so they are unit-testable with in-memory fakes and
  no `NavigationStack` host.
- Adding the vessel to existing route payloads is a small, contained change to
  `SelectVesselViewModel`, `TripStartedTodayViewModel`, `TripDateViewModel` and the host mapping.
- The async provider shape means the eventual real-API swap is an implementation change behind an
  unchanged protocol, not a re-architecture.
- Standing obligation (per ADR-0001): the real networking/persistence/sync work will each get their
  own ADR, and the native-app governance exception remains current.

## Update (2026-09) — port search now sourced from the real bundled port list

The port **search** side (`PortSearchProviding`) has been re-pointed at the real, bundled
`ports.geojson` list — the same GeoJSON file the offline map's `PortLoader` already parses —
instead of the original 12-port placeholder list. `BundledPortSearchProvider` (renamed from
`StubPortSearchProvider`, which no longer describes what it does) loads, deduplicates (by the
stable `port_code` — a handful of ports repeat identically in the source file) and alphabetically
sorts the ~493 real UK ports once at construction; this is synchronous, bundled data, not a
network call, so the `async throws` shape is unaffected. `PortOption` gained a `coordinate:
PortCoordinate?` field (plain `latitude`/`longitude` `Double`s, not `CLLocationCoordinate2D`, so
the model stays trivially `Hashable`/`Sendable`) populated from the GeoJSON geometry, so a port's
location is available wherever a selected `PortOption` flows (favourites, `CatchRecordDraft`) for
later use (e.g. showing the port on a map). `FavouritePortsProviding` remains an in-memory stub —
this update only replaces the *search* list's data source, not favourites persistence, which is
still deferred to the future real Ports/Favourites API ADR referenced in §5 above.

## References

- DEFRA, *Mobile application standards* (offline-first) —
  https://defra.github.io/software-development-standards/standards/mobile_app_standards/
- GOV.UK Design System, *Button* (secondary / "Add another") —
  https://design-system.service.gov.uk/components/button/
- WCAG 2.2 Success Criterion 4.1.3 (Status Messages) —
  https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- Apple, *NavigationStack* — https://developer.apple.com/documentation/swiftui/navigationstack
- ADR-0001 (architecture), ADR-0003 (Create-a-catch-record navigation).
```
