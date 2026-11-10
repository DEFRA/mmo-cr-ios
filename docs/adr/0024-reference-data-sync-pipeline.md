# ADR-0024: Reference-data background sync pipeline

## Status

Accepted

## Context

ADR-0018 built the reference-data API connector (`RemoteReferenceDataClient`/`StubReferenceDataClient`,
`ReferenceDataFetching`) but deliberately left it unwired: "this is the connector only". The app's
ports/species/gears/vessels pickers (`AddPortViewModel` etc.) still read from bundled catalogues or
in-memory fixtures. DEFRA's offline-first requirement (copilot-instructions.md §3) means these
reference datasets must work fully offline after a first successful sync, degrade gracefully when a
sync fails, and never block a screen behind a spinner.

This ADR records the design for actually wiring the connector in: a background sync pipeline that
keeps a local SwiftData snapshot of each dataset up to date, triggered by app lifecycle events, with
an explicit, accessible UI for sync failure — not a new architecture pattern (MVVM + Swift
Concurrency, per `swift-swiftui.instructions.md`, is unchanged), but a new persistence + sync layer
within it.

## Decision

### Manifest-driven change detection

A single `GET /reference-data/manifest` call returns a per-dataset `version`/`collectionId`/
`schemaVersion`/`itemCount`. `ReferenceDataSyncService.sync()` fetches the manifest once per sync
attempt, then compares it against each dataset's locally-stored `ReferenceDatasetStateEntity` row.
A dataset is only refetched when the manifest shows a change (or data has never been synced) —
unchanged datasets are skipped entirely, so a typical sync after the first one does no network
transfer beyond the manifest call itself.

### SwiftData models

Two new `@Model` types in `Core/Persistence/ReferenceData/`:

- `ReferenceItemEntity` — one row per item (port/species/gear/vessel), in a single shared table
  (`dataset` + `itemID` + JSON `payload`), mirroring `FavouriteEntity`'s "one entity, several
  payload shapes" design (ADR-0023) rather than one `@Model` type per dataset.
- `ReferenceDatasetStateEntity` — one row per dataset, tracking the locally-synced
  `version`/`collectionId`/`schemaVersion`/`itemCount`/`lastModified`/`syncedAt`/`payloadFormatVersion`.

Both are registered in `RecordCatchApp`'s shared `ModelContainer` schema alongside
`CatchRecordEntity`/`FavouriteEntity`.

### Background actor persistence

`ReferenceDataStore` is a `@ModelActor` (not `@MainActor`) — every read/write happens off the main
actor, so persisting a few hundred items on sync never blocks the UI thread. `ReferenceDataStoreProvider`
holds the app-wide instance (set once in `RecordCatchApp.init()`), mirroring `LaunchArguments.current`'s
"process-wide seam, no DI plumbing" role, for call sites (cached search providers) that don't want a
`ModelContainer` threaded through their init.

### Atomic replace

`ReferenceDataStore.replace(dataset:items:state:)` deletes every existing row for a dataset, inserts
the new rows, upserts the state row, and only then calls `modelContext.save()` once. Nothing is
written to disk until that single save, so a dataset is never left half-replaced.

### Validation

`ReferenceDataValidator` runs pure, side-effect-free checks on the *mapped* domain arrays (not the raw
wire envelope) before a dataset is allowed to replace the on-device snapshot: non-empty, a manifest
`itemCount` match when the manifest supplied one, no duplicate identifiers, and dataset-specific sanity
checks (blank names/ids, out-of-range port coordinates, non-positive vessel lengths, blank gear
measurement labels). Any failure throws `ReferenceDataValidationError` and the existing snapshot for
that dataset is kept — never a partial or corrupt replace. This is strict, all-or-nothing per dataset.

### Gears from two requests

`gears` is the one dataset built from **two** concurrent requests — the canonical view (the source of
the required/per-trip split via `applicableCharacteristics.fixed`, filtered to the current vessel-length
band) and the `?view=mobile` view (category/pair-fishing display fields and the labelled `measurements`
catalogue) — joined by `RemoteReferenceDataClient.fetchGears()` and `GearOption.make(canonical:mobile:
measurementsById:vesselLengthBand:)`. The two responses' `version`/`collectionId`/gear-code sets must
agree, or the whole fetch throws `.gearViewsMismatch`; a measurement id referenced by a characteristic
but absent from the mobile response's catalogue throws `.unresolvedGearMeasurement` — both strict,
rather than silently dropping or guessing.

### Triggers

`ReferenceDataSyncCoordinator` (a `@MainActor` façade over the actor `ReferenceDataSyncService`)
attempts a sync on:

- **Reaching Home** (`notifyReachedHome()`) — a fresh sign-in or an unlock with an existing session.
  Bypasses the 15-minute throttle, since the user has just authenticated and a first-ever sync must
  not wait.
- **Returning to the foreground** (`notifyForeground()`) after backgrounding.
- **Connectivity being restored** (`notifyConnectivityRestored()`) — `ConnectivityMonitoring.isOnline`
  transitioning `false` → `true`.
- **A user-initiated retry** (`retry()`, from `SyncErrorBanner`) — always bypasses the throttle.

Every trigger is a no-op while offline, while a sync is already in flight, or (bar `retry()`/
`notifyReachedHome()`) within 15 minutes of the last attempt. No trigger ever fires during a
`-uiTest*` launch — no XCUITest run depends on live network access to the reference-data API.

### Error UI

`ReferenceDataSyncCoordinator.status` (`.idle`/`.syncing`/`.failed(hasLocalData:)`) is exposed to the
UI via the `\.referenceDataSyncStatus` environment key (mirroring `\.connectivityMonitor`'s "protocol,
not concrete type" pattern, since the real coordinator and `StubReferenceDataSyncStatusObserver` are
different types). `SyncErrorBanner` is pinned below `OfflineBanner` in `ViewTemplate` — visible on
every screen without threading status through each one — and renders nothing while idle/syncing or
while offline (being offline is `OfflineBanner`'s message, never also treated as a sync failure).
Two messages, matching `hasLocalData`: "could not update, you can keep using what you already have"
vs "has not downloaded yet". Both carry a retry action and a WCAG 2.2 4.1.3 status-message
announcement.

### Sign-out

Reference data is **not** personal data (unlike a catch record), so it is kept across sign-out —
re-downloading a few hundred ports/species/gears/vessels on every sign-in would be wasteful and
pointless. Only the coordinator's throttle/in-flight state is reset
(`ReferenceDataSyncCoordinator.resetForSignOut()`), so the next sign-in's `notifyReachedHome()` is
never suppressed by a stale throttle timestamp from the previous session.

### Data before Home (gating Home behind a successful sync)

A fresh sign-in or an app-lock unlock no longer moves straight to Home. `RootSessionCoordinator`
gained a `.preparingData` phase, shown between `.appLock`/`.signIn` and `.home`:
`handleSignIn`/`makeAppLockViewModel`'s `onUnlocked` now set `phase = .preparingData` (not `.home`),
and the new `completeDataPreparation()` moves `.preparingData → .home` once the required data is
present. **No picker is reachable before that** — the entire Home tab bar, and therefore every
catch-record journey, sits behind this gate.

`DataPreparationView`/`DataPreparationViewModel` drive the gate: on appearing, the view model calls
`ReferenceDataSyncCoordinator.prepareRequiredData(timeout:)`, which bypasses the usual 15-minute
throttle (reusing an already-in-flight sync via a new `inFlightSync` task reference if one is
racing in from another trigger, rather than starting a redundant second one), waits up to 20
seconds for it to finish, and reports whether `ReferenceDataSyncCoordinator.requiredKinds` —
**`[.ports, .species, .gears]` only** — are all present on-device
(`ReferenceDataSyncService.hasData(for:)`). **Vessels are deliberately excluded**: no picker consumes
synced vessel data yet (see Consumers below), so gating on it would block Home for no benefit.

On success the user proceeds straight to Home. On failure (offline, or a sync that ran but still
lacks the required data) the screen shows a WCAG 2.2 4.1.3-announced failure state with a "Try
again" action (re-runs `prepare()`) and a "Sign out" action — mirroring `AppLockView`'s layout and
`SyncErrorBanner`'s accessibility pattern. The view model depends on the narrow `@MainActor`
`ReferenceDataPreparing` protocol (`isDeviceOnline`/`prepareRequiredData(timeout:)`), which
`ReferenceDataSyncCoordinator` conforms to via an extension — the same seam shape as
`ReferenceDataSyncStatusObserving` for `SyncErrorBanner` — so the view model is unit-testable
without a real sync/persistence/network stack.

**UI tests never depend on this.** `RootSessionCoordinator.isUITesting` (default
`LaunchArguments.current.isUITesting`) makes `handleSignIn`/`onUnlocked` skip `.preparingData`
entirely for any `-uiTest*` launch, and `prepareRequiredData` short-circuits to `true` the same way —
consistent with every other sync trigger already being a no-op during UI testing. In practice this
rarely even matters: `UITestRootView` substitutes its own seeded view before `sessionCoordinator.phase`
is ever consulted for the large majority of `-uiTest*` launches.

### Consumers: Synced*SearchProvider (pickers read synced data)

`ReferenceDataStore` gained `decodedItems<T: Decodable>(for:as:)`, which reads the same JSON rows
`sync()` wrote and decodes each into the exact domain type the sync service persisted (`PortOption`/
`SpeciesOption`/`GearOption` — no DTO/wire-shape mapping needed, since `fetchAndValidate` already
encodes domain types, not wire envelopes). A row that fails to decode is skipped and logged via
`NetworkLogger` rather than failing the whole read.

Three new production providers in `Features/Common/Data/` — `SyncedPortSearchProvider`,
`SyncedSpeciesSearchProvider`, `SyncedGearSearchProvider` — conform to the existing
`PortSearchProviding`/`SpeciesSearchProviding`/`GearSearchProviding` protocols exactly as the
bundled/stub providers they replace, reusing each provider's existing pure `static func filtered(...)`
helper rather than duplicating matching logic. Ports/species filter out `isActive == false`; gears
has no `isActive` field, so every synced gear is returned. Each takes a
`store: ReferenceDataStore? = ReferenceDataStoreProvider.shared` default and returns `[]` if the
store is `nil` (e.g. before `RecordCatchApp.init()` has set the shared instance).

`CatchRecordHostView` resolves `portSearch`/`gearSearch`/`speciesSearch` via the same
injected-or-computed pattern already used for `favouritePorts`/`favouriteGears`/`favouriteSpecies`:
an explicit `init` override wins; otherwise a `-uiTest*` launch falls back to the bundled/stub
providers (so UI tests keep their existing fixed, seeded catalogues), and production resolves to the
new Synced providers. `AddPortView`/`AddSpeciesView` gained matching `portSearch`/`speciesSearch`
init parameters (defaulting to the bundled/stub provider, so every other call site — including
previews — is unaffected) to carry the override through.

**Vessels remain out of scope** for this change: no picker yet reads synced vessel data, so
`SyncedVesselSearchProvider` does not exist and `requiredKinds` above excludes `.vessels`.

### No migrations / payload-format version

This connector does not support SwiftData schema migrations for `ReferenceItemEntity.payload`'s
decoded shape. Instead, `ReferenceDataSyncService.payloadFormatVersion` is bumped whenever a domain
type's `Codable` shape changes incompatibly; `ReferenceDatasetStateEntity.payloadFormatVersion` is
compared against it as an extra "unchanged" condition, so a version bump simply forces every device
to refetch once — cheap and correct for datasets this small.

### No bundled fallback

Unlike ADR-0012's original gear catalogue, there is no bundled "last known good" dataset shipped in
the app bundle as a fallback. If a sync has never succeeded, `SyncErrorBanner`/the screen-level
"not yet downloaded" empty state (future work — see Known gaps) says so plainly rather than silently
falling back to stale bundled data a user might not expect in a live fishing-trip context.

### Map data (blob datasets)

`map-land`/`map-statistical-areas` are synced by the same pipeline but are **opaque blobs**, not
item collections, and this ADR deliberately stops at "fetch and store the raw bytes" — not parsing
GeoJSON or feeding `PrecomputedMapLoader`/`MapLandLoader`/`SubrectangleLoader`'s existing
bundle-based rendering pipeline, which is unchanged and untouched by this work. Wiring the stored
blobs into map rendering (replacing or supplementing the bundled `.geojson`/precomputed `.plist`
assets) is explicit future work.

- **`ReferenceBlobEntity`** — a third `@Model`, one row per blob dataset (`dataset` unique key +
  `payload: Data` marked `@Attribute(.externalStorage)`, since a GeoJSON blob can run to several
  MB and SwiftData should not inline that into the main database file). `ReferenceDataStore` gained
  parallel `blobState(for:)`/`hasBlob(for:)`/`blob(for:)`/`replaceBlob(dataset:payload:state:)`
  methods, reusing the same `StateSnapshot` shape as item datasets (`itemCount` is always `nil` for
  a blob, matching the manifest's documented `featureCount`/`sizeBytes` fields for these datasets).
- **No fixed route.** Every item dataset has a fixed `GET /reference-data/{dataset}` fallback route
  it can blindly refetch even with no manifest entry. A blob dataset does not — its only known
  location is the manifest entry's own `url` field. `ReferenceDataEndpoint.makeReferenceDataBlobRequest`
  therefore takes an already-resolved `URL` rather than building one from `baseURL` + fixed path
  segments, and `RemoteReferenceDataClient.fetchBlob(urlString:)` resolves that string against
  `configuration.baseURL` only when it has no scheme of its own.
- **Absent manifest entry → `.unchanged`, not `.failed`.** Because there is no fallback route,
  `ReferenceDataSyncService.syncBlobDataset` treats "the manifest fetch failed, or the manifest
  simply doesn't list this dataset yet" as `.unchanged` rather than attempting a blind retry or
  reporting a failure — a backend that hasn't shipped `map-land`/`map-statistical-areas` yet must
  not make every sync attempt look broken.
- **Shallow validation only.** `ReferenceDataValidator.validateBlob` checks non-empty, within the
  existing response-size cap, and that the bytes are syntactically valid JSON
  (`JSONSerialization.jsonObject`) — it does not validate GeoJSON semantics. This matches the
  explicit scope boundary: store the manifest-described bytes opaquely; precomputation/parsing is a
  separate, future change.
- **Independent of `map-ports`.** The manifest documents a `map-ports` entry that is always derived
  from the `ports` item dataset rather than being independently fetchable, so `ReferenceBlobKind`
  deliberately only has two cases (`mapLand`, `mapStatisticalAreas`) and does not include it.

## Known gaps (flagged, not hidden)

- **Production bearer token (now release-blocking, not just a gap).** `AuthTokenProviding` still
  has no Keychain/MSAL-backed production implementation (ADR-0018 §5's "pending real auth" gap is
  not closed by this ADR). `ReferenceDataSyncCoordinator.make(store:connectivityMonitor:)` resolves
  to `NilAuthTokenProvider` (always `nil`) outside `DEBUG`/`ENABLE_DEBUG_REFERENCE_DATA_TOOL`. Now
  that Home is gated behind a successful sync ("Data before Home" above), a production build with no
  token will show `DataPreparationView`'s failure state indefinitely — a safe, visible degradation,
  never silent data loss or a crash, but one that blocks every user from reaching Home at all. **This
  must be closed before shipping to real users** — track as a follow-up once ADR-0022's Entra
  integration exposes a reference-data-scoped token.
- **No dedicated "not yet downloaded" full-screen state for individual pickers.**
  `SyncErrorBanner` still covers every other screen uniformly; the port/species/gear pickers
  themselves have no bespoke empty state beyond `DataPreparationView`'s app-wide gate (which only
  covers the very first sync after sign-in/unlock, not a later failure once Home has been reached).
- **Vessel reference data has no consumer.** `SyncedVesselSearchProvider` does not exist and
  `ReferenceDataSyncCoordinator.requiredKinds` excludes `.vessels` — vessels still come from whatever
  pre-existing fixture/bundled source the vessel picker already used. Revisit once a vessel picker
  is wired to read synced data.
- **Native-app exception.** As with every feature in this app, built against the already-recorded
  native-iOS exception to DEFRA's mobile app standards (see copilot-instructions.md §2).

## Consequences

- Ports/species/gears pickers now read `ReferenceDataStoreProvider.shared`-backed
  `Synced*SearchProvider`s in production (see "Consumers" above) instead of bundled/in-memory
  fixtures; vessels remain on their pre-existing fixture pending a consumer. UI tests keep the
  bundled/stub providers unconditionally, so existing XCUITest fixtures/assertions are unaffected.
- Home is now unreachable until a sync has produced ports/species/gears data at least once per
  device (see "Data before Home" above) — a deliberate tightening of the offline-first promise from
  "works offline once synced" to "cannot reach Home before the first successful sync", which is an
  explicit DEFRA requirement for this change, not an incidental side effect.
- Every dataset failure is independently retryable and never corrupts or partially replaces existing
  data.
- The reference-data layer adds `ReferenceItemEntity`/`ReferenceDatasetStateEntity`/`ReferenceBlobEntity`
  to the shared `ModelContainer`, increasing on-device storage slightly (bounded for item datasets —
  each is at most a few hundred items; the two blob datasets are larger but stored via
  `@Attribute(.externalStorage)`) but keeping Core/Persistence as the single source of truth for
  offline data, per `swift-swiftui.instructions.md`.
