# Reference data API (vessels)

See ADR-0018 for the full design rationale. This document is the quick developer reference for
running the app against a local reference-data backend.

## Endpoints

There are **two** routes, with **two different response shapes**. Only the `vessels` dataset is
implemented today (`ReferenceDataset.vessels`).

### Collection route

```
GET {baseURL}/api/v1/reference-data/{dataset}?view=mobile
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
  "view": "mobile",
  "total": 2,
  "items": [
    {
      "id": "00000000-0000-4000-8000-000000000011",
      "name": "ACHILLES",
      "pln": "PH1234",
      "cfr": "GBR000A1234",
      "displayName": "ACHILLES PH1234",
      "lengthOverallMetres": 8.74
    },
    {
      "id": "00000000-0000-4000-8000-000000000012",
      "name": "SEA SPRAY",
      "pln": "BM45",
      "cfr": "GBR000B5678",
      "displayName": "SEA SPRAY BM45",
      "lengthOverallMetres": 11.2
    }
  ]
}
```

Only `id` and `name` are required on a vessel item — `pln`, `cfr`, `displayName` and
`lengthOverallMetres` may all be omitted.

### Single-item route

```
GET {baseURL}/api/v1/reference-data/{dataset}/{itemId}?view=mobile
Header: Authorization: Bearer <token>   (omitted entirely when no token is configured)
```

Returns a **bare** item object — **not** wrapped in the envelope above:

```json
{
  "id": "00000000-0000-4000-8000-000000000011",
  "name": "ACHILLES",
  "pln": "PH1234",
  "cfr": "GBR000A1234",
  "displayName": "ACHILLES PH1234",
  "lengthOverallMetres": 8.74
}
```

An unknown `itemId` returns `404` with the error-response shape below.

### `view` query parameter

`view` defaults to `canonical` when omitted; the app always requests `view=mobile` explicitly on
both routes above.

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
`/api/v1/reference-data/{dataset}/{collectionId}?view=mobile`. That was **wrong**, and was
re-derived by directly probing the running backend. Root cause: the original sample `curl` used an
unset `$VESSEL_ID` shell variable, so the URL collapsed to `.../vessels/?view=mobile` — the
trailing slash happened to still route to the **collection** endpoint on the local stub server,
which was misread as evidence of a `{collectionId}` path segment. There is no such segment;
`collectionId` is a response field only. If you're tempted to re-derive the contract from a curl
transcript, watch out for exactly this: an empty/unset path variable silently producing a
"working" URL that isn't the one you think it is.

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
against a real backend (e.g. via Xcode's "Run Code Snippet" tooling).
