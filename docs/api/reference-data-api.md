# Reference data API (vessels, species, ports)

See ADR-0018 for the full design rationale (including its dated addenda covering the `species`
and `ports` datasets). This document is the quick developer reference for running the app against
a local reference-data backend.

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

Non-2xx responses (both routes) use a distinct, envelope-free error shape:

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

`RemoteReferenceDataClient` maps the **status code** (not this body) into `APIError` — see
ADR-0018 §6 for the full mapping table. The body's `code`/`traceId` are not currently parsed by the
app; they're documented here for anyone debugging against the raw API directly.

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
shapes above — only the item shape differs. Verified against the local backend at
`http://localhost:3002` (216 items in the canonical view):

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

| Info.plist key | Source | Debug value | Release value |
|---|---|---|---|
| `APIBaseURL` | `API_BASE_URL` in `record-catch/Config/{Debug,Release}.xcconfig` | `http://localhost:3002` | placeholder HTTPS endpoint |

`APIConfiguration` throws `APIError.invalidConfiguration` if `APIBaseURL` is missing/blank/malformed,
or (outside a `DEBUG` build) not `https`.

## Authentication token (local development only)

The app has no real authentication yet (see ADR-0018 §5). To authenticate against a local backend
that requires a bearer token, set the `REFERENCE_DATA_API_TOKEN` environment variable for the
`record-catch` scheme's Run action before building/running:

1. In Xcode: **Product ▸ Scheme ▸ Edit Scheme… ▸ Run ▸ Arguments ▸ Environment Variables**.
2. Set `REFERENCE_DATA_API_TOKEN` to your local backend's token (the scheme already declares the
   key with an empty value so it's discoverable — just fill in the value; **never commit a real
   value**).

If unset (or blank), requests are sent **without** an `Authorization` header, and the API's `401`
response surfaces as `APIError.unauthorized` — a clear failure rather than a silent one. This is a
`DEBUG`-only seam (`EnvironmentTokenProvider`); it does not exist in a Release build. The real
implementation, once OAuth/OIDC authentication lands, will read the token from
`Core/Security/KeychainStoring.swift` instead.

## Testing on a physical device (LAN IP)

The Debug ATS exception only covers `localhost`. To test on a physical device against your Mac's
backend over the LAN:

1. Find your Mac's LAN IP address (e.g. `System Settings ▸ Wi-Fi ▸ Details…`, or `ipconfig getifaddr en0`).
2. Add that IP as a further `NSExceptionDomains` entry in `record-catch/Resources/Info-Debug.plist`
   (**Debug only** — never in `Info-Release.plist`).
3. Point `API_BASE_URL` at that IP for the device build (e.g. temporarily edit
   `record-catch/Config/Debug.xcconfig`, or override the build setting for that run).
4. The app also requests local-network access (`NSLocalNetworkUsageDescription`, Debug only) — you
   will see the standard local-network permission prompt on first launch.

## Developer smoke check

`record-catch/Core/Networking/ReferenceData/ReferenceDataDevSmokeCheck.swift` provides a
`DEBUG`-only `verifyReferenceDataConnectivity()` function that performs one real call against the
configured base URL and reports the decoded vessel count. It is **not** part of the automated
`record-catchTests` suite (it requires a live backend) — invoke it manually while developing
against a real backend (e.g. via Xcode's "Run Code Snippet" tooling). It is not yet updated to also
smoke-check `fetchSpecies()`/`fetchPorts()`; that is left for a future change alongside this doc's
step 7 note.
