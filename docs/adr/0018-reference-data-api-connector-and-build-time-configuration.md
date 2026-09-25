# ADR 0018 — Reference data API connector and build-time configuration

- Status: Accepted
- Date: 2026-09
- Deciders: iOS engineering
- Context tags: networking, architecture, security, build-configuration, native-iOS

## Context

The app's first real backend now exists for local development: an MMO reference-data API exposing
read-only collections (vessels today; ports/gear/species are expected to follow the same shape
later) at:

```
GET {baseURL}/api/v1/reference-data/{dataset}?view=mobile
Header: Authorization: Bearer <token>
```

(plus a single-item route, `GET {baseURL}/api/v1/reference-data/{dataset}/{itemId}?view=mobile`,
returning a bare item rather than the collection envelope — see the correction note below), verified
by hand against a locally-running instance at `http://localhost:3002`. This ADR records
how the app talks to it: a typed, testable `async`/`await` connector, how the base URL is supplied
per build configuration, and how a bearer token is threaded through pending real authentication.

This ADR **extends, not replaces**, ADR-0004. ADR-0004 introduced the app's first
networking-shaped abstraction — `async throws` provider protocols (`PortSearchProviding`,
`FavouritePortsProviding`) backed by in-memory/bundled stubs, explicitly deferring "the real
Ports/Favourites API" to a future ADR. This is that future ADR for the **vessels** dataset: the
first protocol-shaped seam from ADR-0004 to get a real, network-backed implementation. It does
**not** touch the existing stub providers (`StaticVesselProvider`, `BundledPortSearchProvider`,
`StubSpeciesSearchProvider`, `StubGearSearchProvider`) or any view/view model — those keep using
their existing stub seams until a follow-up change wires a view model to the new connector.

Per `.github/instructions/ci-cd.instructions.md`, the frozen configuration strategy for this app
is **build-time configuration ("Option B")**: each environment is compiled with its own
`.xcconfig`-driven settings, there is **no runtime endpoint selector**. That document also records
the "current repo state" gap this ADR starts to close: "the app has no configuration mechanism yet
... there are no `.xcconfig` files and no API base URL". This ADR adds the `.xcconfig` +
`APIBaseURL` mechanism for the **existing single `record-catch` scheme's Debug/Release
configurations only** — it does **not** introduce the three-environment/three-bundle-ID split
that document separately describes; that remains a distinct, larger piece of work for the iOS
DevOps track.

Explicitly out of scope: offline caching, persistence, an outbound sync/write queue, and conflict
resolution. The app's `RecordsRepository`/`CatchRecordDraft` offline-first persistence already
exists for catch records (ADR-0014); reference-data caching for *this* connector (so a vessel list
survives a lost connection) is deferred to its own follow-up ADR once a real screen consumes it.
Real OAuth/OIDC authentication is similarly deferred; only a seam is introduced here.

## Decision

### 1. Typed, async/await `URLSession` connector behind a protocol

Per Apple's networking guidance (TN3151), `URLSession` is the recommended HTTP client and has
first-class `async`/`await` support — no third-party HTTP library is introduced.

```swift
protocol HTTPPerforming: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

protocol ReferenceDataFetching: Sendable {
    func fetchVessels() async throws -> [VesselOption]
    func fetchVessel(id: String) async throws -> VesselOption
}
```

`RemoteReferenceDataClient` implements `ReferenceDataFetching` over an injected `HTTPPerforming`,
`APIConfiguration` and `AuthTokenProviding` — mirroring the dependency-injected, protocol-first
shape ADR-0004 already established for `PortSearchProviding`/`FavouritePortsProviding`, so it is
unit-testable with an in-memory `StubHTTPClient` and requires no live network in the test suite. A
`StubReferenceDataClient` (fixture-backed) is also provided for future call sites/tests, following
the same "real + stub pair" pattern as the existing providers. **Neither is wired into
`AppEnvironment` or any view model in this change** — this PR is the connector only.

### 2. A generic envelope, one concrete dataset

The API wraps every dataset in the same envelope shape (`dataset`, `collectionId`,
`schemaVersion`, `version`, `view`, `total`, `items`). We model that generically —
`ReferenceDataEnvelope<Item: Decodable & Sendable>` — so adding a second dataset later is a new DTO
+ domain mapping, not a new networking shape. `ReferenceDataset` is a `String`-backed enum
currently containing only `.vessels`; there is deliberately no "list collections" endpoint to
model, since the live contract doesn't expose one. The single-item route (`GET
.../{dataset}/{itemId}?view=mobile`) returns a **bare** item, not an envelope, and is modelled
separately rather than forced through the same decoder.

`VesselOption` (the domain-facing value type, alongside `PortOption`/`GearOption` in
`Features/Common/Data/`) requires only `id` and `name`; `pln`, `cfr`, `displayName` and
`lengthOverallMetres` are all optional, matching the real API which can omit any of them.
`displayName` is derived (`"NAME PLN"`, falling back to `NAME`) when the API doesn't supply one, so
call sites always have a single display string to render.

### 3. Build-time `APIBaseURL` via `.xcconfig`, aligned with the frozen Option-B decision

Two new `.xcconfig` files (`Config/Debug.xcconfig`, `Config/Release.xcconfig`) each define
`API_BASE_URL`, wired to the app target's Debug/Release build configurations via
`BASE_CONFIGURATION_REFERENCE`. Debug points at `http://localhost:3002` (the `$()`-escaped `//` is
required so `.xcconfig` doesn't treat it as a comment); Release is a placeholder HTTPS value
pending a real production endpoint. Two per-configuration `Info.plist` files
(`Info-Debug.plist`/`Info-Release.plist`), selected via `INFOPLIST_FILE`, expose `API_BASE_URL` to
the app as `APIBaseURL`, while `GENERATE_INFOPLIST_FILE` stays `YES` so the target's existing
`INFOPLIST_KEY_*` build settings (Face ID usage description, scene manifest, orientations, export
compliance) continue to merge into the generated plist rather than being silently dropped — this
was verified against a real Debug build before the rest of this change was written (see
Consequences).

`APIConfiguration` reads `APIBaseURL` from `Bundle.main` and throws
`APIError.invalidConfiguration` if it is missing, blank, or fails to parse as a URL. As
defence-in-depth against a misconfigured Release build ever shipping an `http://` endpoint, it also
**rejects any non-`https` scheme unless compiled under `#if DEBUG`** — so a plain-HTTP base URL can
only ever be accepted in a debug build of the app, never in a release/App-Store binary, regardless
of what a `.xcconfig` happens to contain.

### 4. Debug-only, narrowly-scoped ATS exception — never `NSAllowsArbitraryLoads`

`security.instructions.md` and DEFRA's mobile standards both mandate all traffic be encrypted and
forbid disabling ATS wholesale. `http://localhost:3002` (and, for on-device testing over a LAN, the
Mac's LAN IP) is not HTTPS, so the **Debug** `Info.plist` carries a narrowly-scoped exception:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>
        </dict>
    </dict>
</dict>
```

per Apple's guidance on `NSExceptionDomains` (scoped per-domain) rather than
`NSAllowsArbitraryLoads` (global, and increasingly restricted — see the cited
`NSAllowsLocalNetworking` documentation on iOS 17+ no longer implicitly trusting raw LAN IP
addresses). The **Release** `Info.plist` carries **no** `NSAppTransportSecurity` key at all, so
Release inherits the platform default of requiring HTTPS everywhere. Testing on a physical device
against the Mac's LAN IP requires adding that specific IP as a further `NSExceptionDomains` entry
in the **Debug** plist only (documented in `docs/api/reference-data-api.md`); per Apple's TN3179,
the local-network *privacy* prompt (`NSLocalNetworkUsageDescription`, also Debug-only) is a
separate mechanism from the ATS *encryption* exception and both are required for on-device testing.

### 5. Token seam: DEBUG-only environment variable, no committed value, successor is Keychain

There is no real auth flow yet (OAuth/OIDC is explicitly out of scope here). Rather than invent a
throwaway login screen, we introduce the minimal seam the real implementation will later replace:

```swift
protocol AuthTokenProviding: Sendable {
    func bearerToken() async throws -> String?
}
```

`EnvironmentTokenProvider`, compiled only under `#if DEBUG`, reads
`ProcessInfo.processInfo.environment["REFERENCE_DATA_API_TOKEN"]` and returns `nil` when unset or
blank — **no default value is ever committed** to source, `.xcconfig`, or `Info.plist`, satisfying
the DEFRA "never commit secrets" constraint even for a local-dev-only token. When the provider
returns `nil`, the request is built **without** an `Authorization` header at all (never an empty or
placeholder one), so an unauthenticated call reaches the real API and its `401` response surfaces
through the normal error path as `APIError.unauthorized` — a clear, actionable failure rather than
a silent one. The shared `record-catch` scheme declares `REFERENCE_DATA_API_TOKEN` with an
**empty** value in its `EnvironmentVariables` so it is discoverable in Xcode's scheme editor
without committing a value.

**This is explicitly a placeholder.** `Core/Security/KeychainStoring.swift` already exists for
persisted secrets (see ADR-0009); once real OAuth/OIDC authentication lands, the successor to
`EnvironmentTokenProvider` is a `KeychainStoring`-backed token provider (storing/refreshing a real
access token), and `EnvironmentTokenProvider` is deleted. No production/Release code path can reach
`EnvironmentTokenProvider`, since it does not exist outside `#if DEBUG`.

### 6. Status/error mapping is total and typed

`APIError` is a `Sendable`, `Equatable` enum (`invalidConfiguration`, `offline`, `timedOut`,
`transport(code:)`, `unauthorized`, `forbidden`, `notFound`, `server(status:)`,
`decoding(String)`), so every failure mode the connector can produce is enumerable and testable
rather than a stringly-typed `Error`. HTTP statuses map deterministically (`401` →
`.unauthorized`, `403` → `.forbidden`, `404` → `.notFound`, other `4xx` → `.transport(code:)`,
`5xx` → `.server(status:)`); `URLError.notConnectedToInternet`/`.networkConnectionLost` map to
`.offline` (a transient, retryable condition — consistent with the app's offline-first posture,
even though this connector does not itself implement a retry/queue) and `URLError.timedOut` to
`.timedOut`; a `DecodingError` becomes `.decoding(String)` carrying a non-sensitive description.

### 7. Structured logging, never the token or headers

`NetworkLogger` logs method, path and status via `OSLog`/`Logger` (subsystem
`uk.gov.defra.record-catch`, category `networking`), matching the DEFRA requirement to log errors
with a configurable debug level. The request URL is logged at `privacy: .private`. Headers,
`Authorization` values, the token itself, and response bodies are **never** logged — enforced by
construction (the logger is only ever handed method/path/status/duration, never the `URLRequest` or
raw response), and the log sink is injectable so a test can assert none of that data ever appears
in emitted log lines.

## Consequences

- `URLSessionHTTPClient` (`timeoutIntervalForRequest = 15s`, `waitsForConnectivity = false`) is the
  only concrete `HTTPPerforming`; failing fast when offline (rather than waiting indefinitely for
  connectivity) matches "the app must remain useful/responsive without connectivity" — the caller
  gets `.offline` promptly instead of a hung request.
- The Debug/Release `Info.plist` split was verified against a real Debug build before the rest of
  the connector was written: the existing `INFOPLIST_KEY_NSFaceIDUsageDescription`, scene manifest,
  orientation and `ITSAppUsesNonExemptEncryption` settings all still merge correctly into the
  generated plist alongside the new `APIBaseURL`/ATS/local-network keys, so no fallback
  (moving those settings into the plist files directly) was needed.
- This is a **connector only**. No view, view model, or `AppEnvironment` changes in this PR;
  `StaticVesselProvider` and `VesselProviding` are untouched. A future change wires a real screen to
  `ReferenceDataFetching` and, at that point, must also decide the offline caching/sync story this
  ADR deliberately defers.
- Developers must export `REFERENCE_DATA_API_TOKEN` in their own environment (e.g. via Xcode's
  scheme editor or a shell export before `xcodebuild`) to authenticate against a local backend that
  requires it; forgetting to do so produces a clear `.unauthorized` failure rather than a silent one,
  and is documented in `docs/api/reference-data-api.md`.
- The three-environment/three-bundle-ID build-time configuration split described in
  `ci-cd.instructions.md` remains **not yet implemented** — this ADR only adds Debug/Release
  `.xcconfig`s for the existing single scheme. That remains open work for the iOS DevOps track.

## Correction (post-acceptance): the collection route has no `{collectionId}` path segment

This ADR originally documented the collection route as
`GET {baseURL}/api/v1/reference-data/{dataset}/{collectionId}?view=mobile`. **That was wrong**,
discovered and corrected by directly probing the running local backend at
`http://localhost:3002` rather than re-reading the original sample transcript.

**Root cause:** the original sample `curl` command referenced an unset `$VESSEL_ID` shell
variable. With that variable empty, the URL collapsed to `.../vessels/?view=mobile` — the
trailing slash still routed to the **collection** endpoint on the local stub server, which was
misread as evidence that a collection is addressed by a `{collectionId}` path segment. It isn't:
`collectionId` is a **response** field inside the envelope, never a request path component.

**Verified live contract (corrected):**

- Collection: `GET {baseURL}/api/v1/reference-data/{dataset}?view=mobile` → the
  `ReferenceDataEnvelope` (unchanged shape, still carries `collectionId` as a response field).
- Single item: `GET {baseURL}/api/v1/reference-data/{dataset}/{itemId}?view=mobile` → a **bare**
  item object (not an envelope). Unknown `itemId` → `404` with an `{"error": {"code","message",
  "traceId","retryable"}}` body.
- Omitting `Authorization` entirely → `401`. An invalid bearer token value currently → `200` on
  the local stub (it does not validate token values — not proof that auth is enforced).
- `view` defaults to `canonical` when omitted; the app always sends `view=mobile` explicitly.

**What changed in the code:** `makeReferenceDataRequest` (§1/§2) dropped its `collectionId`
parameter and now builds the collection URL with no extra path segment; a new
`makeReferenceDataItemRequest` builds the single-item URL; `ReferenceDataFetching` gained
`fetchVessel(id:)` alongside the renamed `fetchVessels()` (no `collectionId` parameter); a new
private decode path in `RemoteReferenceDataClient` decodes the bare single-item response instead
of forcing it through the envelope decoder. The HTTP-status/`URLError` → `APIError` mapping in §6
was **not** affected by this correction and required no changes.

## References

- Apple, *NSAllowsLocalNetworking / `NSExceptionDomains`* —
  https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking
- Apple, *TN3151: Choosing the right networking API* —
  https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api
- Apple, *TN3179: Understanding local network privacy* —
  https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
- DEFRA, *Mobile application standards* —
  https://defra.github.io/software-development-standards/standards/mobile_app_standards/
- ADR-0004 (port selection API-shaped stub seam — the async provider protocols this ADR gives its
  first real implementation to).
- ADR-0009 (offline biometric local re-entry; `Core/Security/KeychainStoring.swift`, the future
  home of the real bearer token once OAuth/OIDC lands).
- ADR-0014 (catch record draft persistence — the app's existing offline-first persistence,
  distinct from the reference-data caching explicitly deferred here).
- ADR-0016 (coverage strategy — this connector's coverage targets follow the same ≥95%
  core-logic / 100% error-handling bars).
- `.github/instructions/ci-cd.instructions.md` (frozen build-time/Option-B configuration decision
  and the three-environment split this ADR does not yet implement).
- `.github/instructions/security.instructions.md` (encryption in transit, Keychain, secrets).
