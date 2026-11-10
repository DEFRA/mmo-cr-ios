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

- **Production bearer token.** `AuthTokenProviding` still has no Keychain/MSAL-backed production
  implementation (ADR-0018 §5's "pending real auth" gap is not closed by this ADR).
  `ReferenceDataSyncCoordinator.make(store:connectivityMonitor:)` resolves to `NilAuthTokenProvider`
  (always `nil`) outside `DEBUG`/`ENABLE_DEBUG_REFERENCE_DATA_TOOL`. If the live API requires a
  token, every sync attempt reports `.failed` uniformly — a safe, visible degradation, not silent
  data loss or a crash — but this must be closed before relying on this pipeline with real users.
  Track as a follow-up once ADR-0022's Entra integration exposes a reference-data-scoped token.
- **No dedicated "not yet downloaded" full-screen state.** `SyncErrorBanner` covers every screen
  uniformly; a richer per-screen empty state (e.g. inside the port/species/gear pickers themselves)
  is not built in this change.
- **Native-app exception.** As with every feature in this app, built against the already-recorded
  native-iOS exception to DEFRA's mobile app standards (see copilot-instructions.md §2).

## Consequences

- Ports/species/gears/vessels pickers can move off bundled/in-memory fixtures onto
  `ReferenceDataStoreProvider.shared`-backed cached providers in a follow-up change, without needing
  any further sync-pipeline work.
- Every dataset failure is independently retryable and never corrupts or partially replaces existing
  data.
- The reference-data layer adds `ReferenceItemEntity`/`ReferenceDatasetStateEntity`/`ReferenceBlobEntity`
  to the shared `ModelContainer`, increasing on-device storage slightly (bounded for item datasets —
  each is at most a few hundred items; the two blob datasets are larger but stored via
  `@Attribute(.externalStorage)`) but keeping Core/Persistence as the single source of truth for
  offline data, per `swift-swiftui.instructions.md`.
