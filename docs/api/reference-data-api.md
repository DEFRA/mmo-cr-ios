# Reference data API (vessels, species, ports)

See ADR-0018 for the full design rationale (including its dated addenda covering the `species`
and `ports` datasets, and the 2026-10 addendum covering the CDP dev base URL). This document is
the quick developer reference for running the app against the reference-data API.

## Endpoints

There are **two** routes, with **two different response shapes**, modelled for three datasets today:
`ReferenceDataset.vessels`, `ReferenceDataset.species` and `ReferenceDataset.ports`. All three share
the same `ReferenceDataEnvelope`/bare-item shapes described below — only the DTO/domain type
differs per dataset.

### Collection route

```
GET {baseURL}/api/v1/reference-data/{dataset}
Header: Authorization: Bearer <token>   (omitted entirely when no token is configured)
```

There is **no** collection-id path segment — `collectionId` only ever appears as a *response*
field inside the envelope below, never as a request path component. Returns the shared envelope:

```json
{
  "dataset": "vessels",
  "collectionId": "00000000-0000-4000-8000-000000000010",
  "schemaVersion": "1.0",
  "version": "local-seed-1",
  "view": "canonical",
  "total": 2,
  "items": [
    {
      "id": "00000000-0000-4000-8000-000000000011",
      "name": "ACHILLES",
      "namePln": "ACHILLES PH1234",
      "identifiers": {
        "cfr": "GBR000A1234",
        "uvi": null,
        "mmsi": "232001234",
        "ircs": "MABC7",
        "externalMark": "PH1234",
        "registrationNumber": "PH1234"
      },
      "typeCode": "FISHING",
      "registrationCountryCode": "GBR",
      "lengthOverallMetres": 8.74,
      "status": "active",
      "activeFrom": "2015-03-17",
      "activeTo": null
    }
  ]
}
```

Only `id` and `name` are required on a vessel item; every other field may be omitted or `null`.
Note the vessel identifiers (`cfr`, `uvi`, `mmsi`, `ircs`, `externalMark`, `registrationNumber`)
are **nested** under an `identifiers` object — `VesselOption` flattens them into top-level
properties. Unknown fields are ignored by the decoder.

### Single-item route

```
GET {baseURL}/api/v1/reference-data/{dataset}/{itemId}
Header: Authorization: Bearer <token>   (omitted entirely when no token is configured)
```

Returns a **bare** item object — **not** wrapped in the envelope above:

```json
{
  "id": "00000000-0000-4000-8000-000000000011",
  "name": "ACHILLES",
  "namePln": "ACHILLES PH1234",
  "identifiers": {
    "cfr": "GBR000A1234",
    "uvi": null,
    "mmsi": "232001234",
    "ircs": "MABC7",
    "externalMark": "PH1234",
    "registrationNumber": "PH1234"
  },
  "typeCode": "FISHING",
  "registrationCountryCode": "GBR",
  "lengthOverallMetres": 8.74,
  "status": "active",
  "activeFrom": "2015-03-17",
  "activeTo": null
}
```

An unknown `itemId` returns `404` with the error-response shape below.

### `view` query parameter

`view` defaults to `canonical` when omitted. **The app deliberately sends no `view` parameter on
either route, for any dataset**, so it always receives the canonical shape — which is what
`VesselDTO`/`VesselOption`, `SpeciesDTO`/`SpeciesOption` and `PortDTO`/`PortOption` all model.

The API also offers a reduced `?view=mobile` shape per dataset (for vessels: flat
`pln`/`cfr`/`displayName` fields, no `identifiers` object; for species: flat `id`/`faoCode`/
`scientificName`/`displayName`, no `commonNames`/`localNames` arrays; ports have not been checked
against a `view=mobile` shape — only canonical has been verified). The app does **not** use
`view=mobile` for any dataset: the canonical view is a superset, so taking it avoids losing
fields (vessels: `uvi`, `mmsi`, `ircs`, `typeCode`, `status`, the active date range; species:
`commonNames`/`localNames` beyond the single GBR entry the mobile `displayName` already picks, and
`active`) that the mobile view omits. If you ever add `view=mobile` back for a dataset, its DTO
must change with it — the two shapes are not interchangeable, and decoding mobile JSON with the
canonical DTO silently yields `nil`/empty for every field the mobile shape flattens away.

### Error responses

Non-2xx responses (both routes, and the manifest route) carry a distinct, envelope-free error
shape:

```json
{
  "error": {
    "code": "reference_item_not_found",
    "message": "…",
    "traceId": "…",
    "retryable": false
  }
}
```

`RemoteReferenceDataClient` maps every non-2xx response to `APIError.response(status:details:)`.
`details` decodes this body's `code`/`traceId`/`retryable` (via `APIErrorDetails`) whenever it
matches the shape above; it is `nil` when the body is empty, absent, or doesn't match (a malformed
error body never masks the real HTTP-status failure). `message` and `dataset`'s sibling `details`
field are deliberately **not** surfaced — server-authored text must never become user-facing copy.
See the ADR-0018 addendum "Standard error envelope, parsed — and the error model collapsed" for
the full `APIError` shape and the `is*`/`isRetryable` helpers call sites should use instead of
matching raw status integers.

### Correlation id (`x-cdp-request-id`)

Every request (all three dataset routes, both item routes, and the manifest route) sends a fresh
`x-cdp-request-id: <UUID>` header. The backend echoes it back as the error envelope's `traceId`
above, so a specific failure can be correlated end-to-end: quote the `traceId` from
`APIError.traceId`/the app's log output when asking the backend team to look up a request. See the
ADR-0018 addendum "Correlation id".

## Manifest

```
GET {baseURL}/api/v1/reference-data/manifest
Header: Authorization: Bearer <token>   (omitted entirely when no token is configured)
```

Returns the active version/GUID/item-count of every persisted dataset — a single bare object, not
an envelope and not a dataset in its own right:

```json
{
  "manifestId": "…",
  "version": "…",
  "datasets": [
    {
      "dataset": "ports",
      "collectionId": "00000000-0000-4000-8000-000000000030",
      "version": "ports-from-excel-1",
      "schemaVersion": "1.0",
      "format": "json",
      "itemCount": 624,
      "lastModified": "…",
      "url": "…"
    }
  ]
}
```

`ReferenceDataFetching.fetchManifest()` decodes this into `ReferenceDataManifest`. Entries for
datasets the app doesn't model yet (`gears`, `map-land`, `map-statistical-areas`, `map-ports`)
decode harmlessly — `dataset`/`format` are plain `String`, not `ReferenceDataset`. Unlike every
other route, the manifest request sets `cachePolicy = .reloadIgnoringLocalCacheData`: the API
serves it with `Cache-Control: max-age=3600`, which would otherwise let `URLCache` silently serve
an hour-old manifest and defeat its purpose as a change-detection signal. See the ADR-0018
addendum "Manifest" and "`URLCache` position".

**Connector-only, like every other route in this file.** `fetchManifest()` is not wired into
`AppEnvironment`, any view model, or any persistence — it exists as the future basis for a
change-detection/sync strategy, not that strategy itself.

## Query parameters: none, by design — fetch everything, every time

**No request built by this connector ever sends a query parameter**, including `view` (see above)
and including any dataset-specific filter the live API supports (`query`, `code`, `countryCode`,
`ids`, `sort`, `includeInactive`, or — for ports — the `latitude`/`longitude`/`radiusKm` radius
search). This isn't an oversight: the app always wants the **entire** collection, and the backend's
pagination behaviour makes that a load-bearing invariant, not a style choice.

⚠️ **Pagination trap.** A request with **no** query key other than `view` is treated by the
backend as a "fetch everything" request and returns the full, unpaginated collection — this is
exactly why a bare `GET /ports` returns all 624 items. The moment **any other** query parameter is
added, the backend silently engages pagination at its own default page size. Adding a filter in
future **must** also send explicit `offset`/`limit` and read the response's pagination metadata —
never add a bare filter parameter and assume the full result set still comes back. A regression
test (`test_everyCollectionRequest_sendsNoQueryParameters`) locks in today's no-query-parameters
behaviour so this doesn't regress silently. See the ADR-0018 addendum "Fetch-all, no query
parameters" and "Parked" sections for the full list of parked (not forgotten) capabilities —
persistence, retry/backoff, query parameters/pagination/radius search, and `view=mobile`.

### Authentication behaviour (verified against the local stub)

- Omitting the `Authorization` header entirely returns `401`.
- Sending an **invalid** bearer token currently returns `200` — the local stub backend does not
  validate the token value. **Do not** treat a successful local response as proof that
  authentication is correctly enforced; that must be verified against a real, validating backend
  before this seam is trusted for anything beyond local development.

### ⚠️ Pitfall record: how the collection-id path segment got invented

An earlier version of this document (and ADR-0018) claimed the collection route was
`/api/v1/reference-data/{dataset}/{collectionId}?view=mobile`. Both the `{collectionId}`
segment and the `view=mobile` parameter are gone. That was **wrong**, and was
re-derived by directly probing the running backend. Root cause: the original sample `curl` used an
unset `$VESSEL_ID` shell variable, so the URL collapsed to `.../vessels/?view=mobile` — the
trailing slash happened to still route to the **collection** endpoint on the local stub server,
which was misread as evidence of a `{collectionId}` path segment. There is no such segment;
`collectionId` is a response field only. If you're tempted to re-derive the contract from a curl
transcript, watch out for exactly this: an empty/unset path variable silently producing a
"working" URL that isn't the one you think it is.

## Species dataset

The `species` dataset (`ReferenceDataset.species`) follows the exact same two routes/response
shapes above — only the item shape differs. Originally verified against a local backend
(216 items in the canonical view; the app now talks to the CDP dev environment by default,
see Configuration below):

```json
{
  "dataset": "species",
  "collectionId": "00000000-0000-4000-8000-000000000040",
  "schemaVersion": "1.0",
  "version": "species-excel-1",
  "view": "canonical",
  "total": 216,
  "items": [
    {
      "id": "5E9E48CF-7BCE-4653-ABA9-9F54591CC814",
      "faoCode": "QSC",
      "scientificName": "Aequipecten opercularis",
      "commonNames": [
        { "id": "84ac2d6c-3563-5cc9-9009-b0738509d29a", "countryCode": "GBR", "name": "Queen scallop" }
      ],
      "localNames": [],
      "active": true
    }
  ]
}
```

Only `id` is required on a species item; every other field may be omitted or `null`. Unlike
vessels, the API has **no top-level display name** for a species — `commonNames`/`localNames` are
arrays of `{ id, countryCode, name }` entries (see `SpeciesNameDTO`), and `SpeciesOption.init(dto:)`
derives a single `name` of the form `"Common name (FAOCODE)"`: it prefers the first `GBR`
`commonNames` entry, falling back to the first entry of any country, then `scientificName`, then
`id` — so every mapped species always has a non-empty name. `active` defaults to `true` when the
API omits it, matching its own observed default on the local stub (every one of the 216 seeded
items is `"active": true`).

The single-item route (`GET {baseURL}/api/v1/reference-data/species/{itemId}`) returns the same
item shape as above, bare (not wrapped in the envelope) — identical in structure to the vessel
single-item route.

**Note on `SpeciesOption`'s `Codable` shape:** unlike `VesselOption`, `SpeciesOption` has **no
backwards-compatibility seam** for its persisted (`CatchRecordDraftStore`) payload — it is this
app's own `Codable` shape going forward, not guaranteed to decode a payload written by a previous
version of the type. See the ADR-0018 addendum for why this was an accepted, deliberate trade-off.

## Ports dataset

The `ports` dataset (`ReferenceDataset.ports`) follows the exact same two routes/response shapes
above — only the item shape differs. Verified against the local backend at
`http://localhost:3002` (624 items in the canonical view):

```json
{
  "dataset": "ports",
  "collectionId": "00000000-0000-4000-8000-000000000030",
  "schemaVersion": "1.0",
  "version": "ports-from-excel-1",
  "view": "canonical",
  "total": 624,
  "items": [
    {
      "id": "49e319b2-9e65-45aa-a80e-0cf4b20bfe79",
      "code": "GBAOT",
      "name": "Abbotsbury",
      "countryCode": "GBR",
      "coordinate": { "latitude": 50.6666984558105, "longitude": -2.59999990463257 },
      "active": true
    }
  ]
}
```

Only `id` and `name` are required on a port item; `code`, `countryCode`, `coordinate` and `active`
may all be omitted or `null`. `coordinate` decodes directly into the pre-existing `PortCoordinate`
type (see `PortOption.swift`, ADR-0004) since the API's `{ "latitude", "longitude" }` shape already
matches it field-for-field. A small number of the 624 seeded ports (e.g. `"Fowey"`) have a `null`
coordinate — `PortOption.coordinate` was already optional for this reason, so no further change was
needed to tolerate it. Unknown fields are ignored by the decoder.

The single-item route (`GET {baseURL}/api/v1/reference-data/ports/{itemId}`) returns the same item
shape as above, bare (not wrapped in the envelope) — identical in structure to the vessel/species
single-item routes.

**`PortOption` predates this connector (ADR-0004) and already carries persisted drafts — unlike
`SpeciesOption`, a backwards-compatibility seam is required.** `PortOption` gained three new fields
sourced only from `init(dto:)`: `code`, `countryCode` and `isActive` (mapped from the API's
`active`). All three are modelled as **`Optional` types with no non-optional default** so that
`CatchRecordDraft` JSON persisted before this change (ADR-0014) — which has no `code`/
`countryCode`/`isActive` keys at all — still decodes successfully via the synthesised `Codable`
conformance, with those fields simply `nil`. See the ADR-0018 addendum for why this is the opposite
trade-off to `SpeciesOption`'s "no migration path" decision, and why it was necessary here.

## Configuration

| Info.plist key | Source | Local Debug value | Pipeline builds |
|---|---|---|---|
| `MMOCRAppConfig` → `API_BASE_URL` | `CR_APP_CFG_API_BASE_URL` in your git-ignored `Config/Local.xcconfig`, written by the Debug build phase `scripts/inject-app-config.sh` | e.g. `http://localhost:3002`, or the CDP **dev** environment: `https://mmo-cr-catch-recording-service.api.dev.cdp-int.defra.cloud/reference-data-service` | Written by the release pipeline from the GitHub Environment variable `CR_APP_CFG_API_BASE_URL` (ADR-0020) |

`APIConfiguration` throws `APIError.invalidConfiguration` if the base URL is missing/blank/malformed,
or (outside a `DEBUG` build) not `https`. `APIConfiguration` reads the `MMOCRAppConfig` → `API_BASE_URL`
key (ADR-0018, Amendment 2026-10b) — the old flat `APIBaseURL` key is no longer used.

## Authentication token (CDP dev — DEBUG builds only)

The app has no real authentication yet (see ADR-0018 §5). The CDP dev reference-data API requires
a bearer token. Set the `REFERENCE_DATA_API_TOKEN` environment variable before building/running:

1. **Local Xcode runs:** use your own **personal, non-shared** Xcode scheme — never the shared,
   committed `record-catch` scheme. Duplicate it (**Product ▸ Scheme ▸ Manage Schemes… ▸**
   duplicate `record-catch` **▸ untick Shared**), then set the variable under
   **Edit Scheme… ▸ Run ▸ Arguments ▸ Environment Variables**.
2. **BrowserStack App Automate (XCUITest):** pass the token via the build API's
   `setEnvVariables` parameter, sourced from a CI secret (never committed). BrowserStack only
   forwards `setEnvVariables` to the XCUITest *runner* process, not the application under test, so
   every UI test's `launch()` call relays it explicitly via
   `XCUIApplication.forwardReferenceDataAPIToken()`
   (`record-catchUITests/XCUIApplication+ReferenceDataToken.swift`).

If unset (or blank), requests are sent **without** an `Authorization` header, and the API's `401`
response surfaces as `APIError.unauthorized` — a clear failure rather than a silent one. This is a
`DEBUG`-only seam (`EnvironmentTokenProvider`); it does not exist in a Release build. The real
implementation, once OAuth/OIDC authentication lands, will read the token from
`Core/Security/KeychainStoring.swift` instead.

**Never commit a real token** — not in `.xcconfig`, `Info.plist`, the shared scheme, or source. If
one ever leaks, follow DEFRA's credential exposure process immediately.

## Pointing Debug at a local backend instead (or the CDP dev environment)

There is no committed default any more — your own git-ignored `Config/Local.xcconfig` decides.
Set `CR_APP_CFG_API_BASE_URL` there to either a locally-running backend (e.g.
`http:/$()/localhost:3002`) or the CDP **dev** environment
(`https:/$()/mmo-cr-catch-recording-service.api.dev.cdp-int.defra.cloud/reference-data-service`);
see `README.md`'s "Running against the CDP dev reference-data API" section. Never commit
`Config/Local.xcconfig` itself.

### Testing on a physical device (LAN IP)

The Debug ATS exception covers `localhost` and the host of your local `http://` URL. To test on a physical
device against your Mac's backend over the LAN:

1. Find your Mac's LAN IP address (e.g. `System Settings ▸ Wi-Fi ▸ Details…`, or `ipconfig getifaddr en0`).
2. Point `CR_APP_CFG_API_BASE_URL` at that IP in your git-ignored `Config/Local.xcconfig`
   (e.g. `http:/$()/192.168.1.20:3002`). The Debug build phase adds the ATS exception for that host
   automatically (**Debug only** — Release builds never get one); no file needs editing.
3. The app also requests local-network access (`NSLocalNetworkUsageDescription`, Debug only) — you
   will see the standard local-network permission prompt on first launch.

## Developer smoke check

`record-catch/Core/Networking/ReferenceData/ReferenceDataDevSmokeCheck.swift` provides a
`DEBUG`-only `verifyReferenceDataConnectivity()` function that performs one real call against the
configured base URL and reports the decoded vessel count. It is **not** part of the automated
`record-catchTests` suite (it requires a live backend) — invoke it manually while developing
against a real backend (e.g. via Xcode's "Run Code Snippet" tooling). It is not yet updated to also
smoke-check `fetchSpecies()`/`fetchPorts()`/`fetchManifest()`; that is left for a future change
alongside this doc's step 7 note.
