# ADR 0025 — Catch Recording Service connector (catch-record lifecycle + vessel favourites)

- Status: Accepted
- Date: 2026-11
- Deciders: iOS engineering
- Context tags: networking, architecture, security, native-iOS

## Context

The Catch Recording Service (its own OpenAPI 3.1 spec — see
`docs/api/catch-recording-service-openapi.yaml`) is a **separate backend** from the reference-data
API already connected in [ADR-0018](0018-reference-data-api-connector-and-build-time-configuration.md).
It owns the catch-record lifecycle (create a draft, retrieve, complete-replace, per-section
save/patch, abandon, history, submit, list submissions, resume editing a submitted record) and a
vessel's favourite gears/species/ports.

This ADR adds a **connector-only** `URLSession`-backed client for this service, following the same
architecture ADR-0018 established for the reference-data connector: `HTTPPerforming` +
`APIConfiguration` + `AuthTokenProviding`, mapped into the shared `APIError` type. **Nothing in this
change wires the connector to any screen, view model, or the local draft store** —
`CatchRecordServicesFactory` builds the three services at app launch purely so a future feature has
a ready construction path; see §7.

Explicitly out of scope for this change (see the spec's own exclusions and the agreed scope):

- The single hard-coded example-record route under `/example-data/{id}`.
- Downloading a submission artifact's binary content (`GET .../submissions/{n}/artifacts/{type}`) —
  only the metadata-only listing route is connected.
- `GET /v1/catch-records/{id}/completion` (a derived read-model not required yet).
- The skippers routes (no screen exists that needs them yet).
- Moving the existing on-device favourites providers (`FavouriteGearProviding`/
  `FavouriteSpeciesProviding`/`FavouritePortsProviding`, ADR-0004) to be server-backed by this
  connector — that is a distinct, future piece of work.
- Offline queuing/retry of mutations through this connector (the app's general offline-first queue
  pattern, per `swift-swiftui.instructions.md`, is adopted when a real screen starts calling it).

## Decision

### 1. Same architecture as the reference-data connector, in its own `CatchRecord/` folder

`record-catch/Core/Networking/CatchRecord/` holds:

- `CatchRecordDTOs.swift` / `VesselFavouritesDTOs.swift` — wire-shaped `Codable` request/response
  types, mirrored 1:1 from the OpenAPI spec's component schemas. Kept as this connector's **own**
  types (never reusing `CatchRecordDraft`/`VesselOption`/etc.), per ADR-0018's precedent.
- `CatchRecordAPIRoute` (`CatchRecordEndpoint.swift`) — a pure enum of the 18 in-scope
  `(method, path)` pairs plus header/query assembly, with no I/O — fully unit-testable.
- `CatchRecordTransport.swift` — the shared send/decode/error-mapping logic (and the client-side
  precondition validators, see §4), composed into each service rather than duplicated three times.
- `CatchRecordErrorEnvelope.swift` — maps the service's own **flat** error body
  (`{statusCode, code, message, correlationId, details[]}` — distinct from the reference-data API's
  nested `{error: {...}}` envelope) into the shared `APIErrorDetails` type. `message`/`details` are
  **deliberately dropped**, never logged or surfaced — server-authored text must never become
  user-facing copy or leak into diagnostics (figma-design.instructions.md §6; security.instructions.md).
- `CatchRecordService.swift` / `VesselFavouritesService.swift` / `CatchRecordPlatformService.swift`
  — the three protocols (`CatchRecordServicing`, `VesselFavouritesServicing`,
  `CatchRecordPlatformServicing`) and their real/`Stub*`/`Failing*` triples, following the exact
  "real + stub + failing" pattern `ReferenceDataClient.swift` established.

### 2. `CatchRecordAPIRoute`/`CatchRecordWeightPrecision` naming — avoiding collisions

The app's own in-journey navigation route enum is already named `CatchRecordRoute`
(`Features/CatchRecord/Routing/CatchRecordRoute.swift`), and `SpeciesOption.swift` already declares
a `WeightPrecision` enum for the UI's own above/below/discarded weight fields. The connector's
equivalents are named `CatchRecordAPIRoute` and `CatchRecordWeightPrecision` to avoid ambiguous
type-lookup errors — these are wire-shape types, not the app's domain types, and are not meant to be
interchangeable with them.

### 3. `catchRecordReference` — client-generated, not server-assigned

See [ADR-0026](0026-client-generated-catch-record-reference.md) for the generator itself.
`CreateDraftCatchRecordPayload.catchRecordReference` carries this app-generated value. **Known
dependency on the backend team:** the service's documented validation pattern for this field
(`^GBR-[A-Z0-9]+-\d{6}-\d{6}$`) does not match the app's `{RSS}-{DDMMYYYY}-{HHMMSS}` format — see
ADR-0026 §"Known dependency". This connector does not re-validate against that pattern client-side,
so a backend fix needs no client change.

### 4. Client-side precondition checks — never send an invalid request

`CatchRecordRequestValidation` (in `CatchRecordTransport.swift`) checks, **before** any request is
built: `version ≥ 1` (If-Match/section-save/abandon/submit/edit-start), `limit` in `1...100`
(listing/history), `submissionNumber` in `1...1000`, `Idempotency-Key` length `1...256`, and the
complete-replacement payload ≤ 1 MiB. Any failure throws `APIError.invalidRequest(reason:)` — a new
case added to the shared `APIError` enum (`isRetryable` is always `false` for it, since nothing was
ever sent) — and the HTTP client is never invoked. This mirrors the DEFRA/OWASP MASVS "validate
input at boundaries" requirement (security.instructions.md) at the client's own boundary, not just
the server's.

### 5. `If-Match` sent as a plain version digit

The spec's examples show `If-Match` carrying a bare integer (e.g. `"3"`), not a quoted HTTP entity
tag as RFC 9110 §13.1.1 would normally expect for that header. This connector follows the spec's
documented shape; the one-line call site (`applyCommonHeaders` in `CatchRecordEndpoint.swift`) is
isolated so it is trivial to change if the backend's real expectation turns out to differ.

### 6. Explicit-null encoding for `PairFishingDTO`

`pairVessel`/`pairSkipperName` are **required and nullable** in the spec. Swift's synthesised
`Encodable` conformance omits a `nil` `Optional` key entirely rather than emitting `null` — which
would violate "required". `PairFishingDTO` has a hand-written `encode(to:)` that always writes both
keys, `null` or not. No other DTO in this connector needs the same treatment (every other optional
field is genuinely optional, not required-and-nullable).

### 7. `CatchRecordServicesFactory` — wiring without a consumer yet

`App/CatchRecordServicesFactory.swift` builds `CatchRecordServices` (bundling the three service
protocols) from:

- `APIConfiguration(key: "CATCH_RECORD_API_BASE_URL")` — a **new**, separate `MMOCRAppConfig` key
  from the reference-data connector's `API_BASE_URL` (see `Config/app-config.schema.json`), since the
  two services are not necessarily hosted at the same address. **Placeholder only**: no real
  per-stage value exists yet from the backend team, so every stage's `Local.xcconfig`/CI Environment
  leaves it unset, and the factory falls back to `Failing*` services (`APIError.invalidConfiguration`)
  — a safe, visible degradation, never a crash or a guessed-wrong address.
- `MSALAccessTokenProvider` (`Core/Networking/MSALAccessTokenProvider.swift`) — adapts the app's
  single `Authenticating` instance (via `RootSessionCoordinator.sharedAuthenticator`, a new
  read-only accessor) into the `nonisolated`/`Sendable` `AuthTokenProviding` seam this connector
  depends on, so bearer tokens come from the *same* signed-in MSAL session every other authenticated
  call in the app uses — never a second, independent sign-in state. See ADR-0022 addendum "API
  scope" for the new `Authenticating.accessToken()` requirement and `EntraConfiguration.catchRecordAPIScope`
  (from the new, also-placeholder `ENTRA_API_SCOPE` config key).
- `-uiTest*` launches always get `Stub*` services (never real network), matching
  `ReferenceDataSyncCoordinator.make`'s own UI-testing fallback.

`RecordCatchApp` constructs `catchRecordServices` once at launch and holds it in `@State` — **not
read by any view yet**. Wiring a real feature (e.g. submitting a catch record from the existing
journey, or showing submission history) is a separate, future change.

## Consequences

- A real, typed, tested connector exists for all 10 catch-record-lifecycle + 6 favourites + 2
  platform routes, ready for a future feature to call — without that feature needing to design its
  own networking layer from scratch.
- Two configuration keys the backend team has not yet supplied real values for
  (`CATCH_RECORD_API_BASE_URL`, `ENTRA_API_SCOPE`) are tracked in `Config/app-config.schema.json` as
  `required: false`, with the same "revisit once real values exist" convention ADR-0022 established
  for its own placeholder keys.
- The `catchRecordReference` format mismatch (ADR-0026) is a known, tracked dependency on the
  backend team updating their validation — not a silent landmine.
- No behavioural or visual change ships to users in this change; it is purely additive, internal
  infrastructure.

## Open questions (for a future change)

- Confirm the Catch Recording Service's real base URL per stage with the backend team.
- Confirm the Entra API scope string once the service is registered with the Entra tenant team.
- Confirm whether `If-Match` really expects a bare digit or a quoted entity tag (§5).
- Confirm `Trip.dateStarted`/`dateEnded`'s real wire shape (date-only vs date-time) — currently
  carried as opaque `String`, matching the spec's own untyped `{ type: string }` declaration.
- Decide which screen/view model becomes this connector's first real consumer, and design the
  offline queue/retry strategy for it at that point.
