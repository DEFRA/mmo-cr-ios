# Backend API plans — reference data, favourites & catch submission

> **Status:** Draft / proposal. These are **candidate** API shapes for the backends behind the MMO Catch
> Recording mobile apps. They are **not yet agreed** with the MMO backend team and no decision ratifies
> them yet — treat this document as the starting point for that conversation, not a contract.
>
> **Audience: all client platforms** (iOS and Android). This document describes the **HTTP contract only**
> and is deliberately platform-neutral — it does not prescribe how any individual app models, stores or
> renders the data.

## Contents

- [Cross-cutting conventions](#cross-cutting-conventions)
- [0. Reference-data manifest](#0-reference-data-manifest) — `GET /reference/manifest`
- [1. Gear reference data](#1-gear-reference-data) — `GET /reference/gear`
- [2. Species reference data](#2-species-reference-data) — `GET /reference/species`
- [3. Vessels](#3-vessels) — `GET /vessels`
- [4. Ports reference data](#4-ports-reference-data) — `GET /reference/ports`
- [5. Map data](#5-map-data) — `GET /reference/map/{layer}`
- [6. Favourites (per-user)](#6-favourites-per-user) — `GET/PUT/DELETE /me/favourites/...`
- [7. Catch record submission](#7-catch-record-submission) — `POST /catch-records`, `GET /catch-records`
- [Open questions](#open-questions)

---

## Cross-cutting conventions

These apply to **every** endpoint below unless a section says otherwise.

### Transport & security (DEFRA mandatory)

- **Encrypt all traffic — HTTPS/TLS only.** Never plain HTTP.
- **Auth:** `Authorization: Bearer <access token>` (OAuth 2.0/OIDC). The client keeps tokens in its
  platform secure store and never in the payload. Reference-data endpoints may be readable with any valid
  user token; **vessels and favourites are per-user** and MUST be scoped to the authenticated user
  server-side.
- **Data minimisation.** Gear/species/ports/map are public reference data and carry no personal data.
  Vessels and favourites are personal data — do not return more than the client needs and do not log bodies.

### Versioning & offline-first caching (DEFRA mandatory)

The clients are **offline-first**: each ships a bundled snapshot of every reference dataset and treats the
network as optional. So every reference endpoint is cache-revalidation friendly:

- Responses carry a strong **`ETag`** and a body-level **`version`** (an opaque, monotonically-changing
  version string, e.g. a date or hash).
- Clients send **`If-None-Match: "<etag>"`**; the server answers **`304 Not Modified`** (empty body) when
  nothing changed, so a launch on a flaky connection costs almost nothing.
- Responses set **`Cache-Control`** with a sensible `max-age` + `stale-while-revalidate`.
- On any network failure the client falls back to its **bundled / last-downloaded snapshot** — a reference
  endpoint being unreachable must never block the user's journey.

### Localisation

Labels are returned as **display text directly** (English), not as translation keys. Each client owns its
own localisation of any labels it chooses to translate. Proper nouns (species names, port names, vessel
names) are likewise returned as plain strings. If a dataset ever needs to be served in multiple languages,
do it via **`Accept-Language`** content negotiation rather than by returning keys.

### Standard error envelope

Non-2xx responses use a consistent shape so a client can log/report diagnostics:

```jsonc
{
  "error": {
    "code": "unauthorized",            // stable machine string
    "message": "Access token expired", // human-readable, safe to log
    "traceId": "b6b1…"                 // correlation id for support/diagnostics
  }
}
```

| Status | When |
|--------|------|
| `304 Not Modified` | `If-None-Match` matched (reference endpoints) |
| `400 Bad Request` | Malformed request/body |
| `401 Unauthorized` | Missing/expired token |
| `403 Forbidden` | Token valid but not entitled (e.g. another user's favourites) |
| `404 Not Found` | Unknown id / layer |
| `409 Conflict` | Favourites write lost a concurrency race (see §6) |
| `422 Unprocessable Entity` | Submission failed server-side validation (see §7) |
| `503 Service Unavailable` | Backend down — client queues the request and retries |

---

## 0. Reference-data manifest

A single, cheap "what changed?" check across **all** reference-data types. A client fetches this **once on
launch/refresh**, compares each dataset's `version`/`etag` against what it already has bundled or cached,
and only downloads the datasets that actually changed. This avoids pulling every full catalogue on every
launch.

```
GET /reference/manifest
Accept: application/json
If-None-Match: "<etag>"          # optional — 304 if nothing changed at all
```

### `200 OK`

```jsonc
{
  "version": "2026-09-08",              // changes whenever ANY dataset below changes
  "generatedAt": "2026-09-08T00:00:00Z",
  "datasets": [
    { "id": "gear",    "version": "2026-09-01", "etag": "\"gear-v5\"",   "url": "/reference/gear",    "sizeBytes": 24000 },
    { "id": "species", "version": "2026-08-15", "etag": "\"species-v9\"","url": "/reference/species", "sizeBytes": 61000 },
    { "id": "ports",   "version": "2026-07-01", "etag": "\"ports-v4\"",  "url": "/reference/ports",   "sizeBytes": 48000 },

    // Map layers are reference data too and appear here as individual datasets:
    { "id": "map.land",          "version": "2026-05-01", "etag": "\"land-v3\"",  "url": "/reference/map/land",          "format": "geojson", "crs": "EPSG:4326", "featureCount": 7,    "sizeBytes": 1200000 },
    { "id": "map.subrectangles", "version": "2026-05-01", "etag": "\"sub-v7\"",   "url": "/reference/map/subrectangles", "format": "geojson", "crs": "EPSG:4326", "featureCount": 3465, "sizeBytes": 2100000 },
    { "id": "map.ports",         "version": "2026-07-01", "etag": "\"ports-v4\"", "url": "/reference/map/ports",         "format": "geojson", "crs": "EPSG:4326", "featureCount": 938,  "sizeBytes": 480000 }
  ]
}
```

**Per-dataset fields**

- `id` — stable dataset identifier.
- `version` / `etag` — the client compares these to decide whether to re-download; `etag` is what it then
  sends as `If-None-Match` to the dataset's own endpoint.
- `url` — where to fetch the full dataset.
- `format` / `crs` / `featureCount` — optional, present for map (GeoJSON) layers.
- `sizeBytes` — advisory, lets a client decide whether to defer a large download to Wi-Fi.

> **Note on the map `ports` layer:** it shares its `version`/`etag` with the `ports` reference dataset
> because both should be generated from **one** source of port data (see §4 and §5). Keeping the ids
> distinct (`ports` vs `map.ports`) lets a client fetch the tabular list and the geospatial layer
> independently.

---

## 1. Gear reference data

The fishing-gear catalogue. Slow-moving reference data.

```
GET /reference/gear
Accept: application/json
If-None-Match: "<etag>"          # optional
```

**Design choices:** measurement definitions are **de-duplicated** into a top-level `measurements`
dictionary and each gear references them by id, so a shared question ("Mesh size (mm)", "Number of trawl
nets", …) is declared exactly once. Each measurement carries its display `label` text directly. Captured
measurement *values* are user-entered and are **not** part of reference data. A gear may legitimately
define **no** measurements (e.g. `HMD`, `MIS`), in which case both arrays are empty.

Each gear defines two kinds of measurement:

- **required** — fixed properties of the gear itself (e.g. mesh size), captured once when a user adds the
  gear to their favourites.
- **variable** — values that can change per trip (e.g. the number of times the gear was shot), captured
  each time the gear is used.

### `200 OK`

```jsonc
{
  "version": "2026-09-01",
  "generatedAt": "2026-09-01T00:00:00Z",

  // Shared measurement definitions, keyed by id, referenced by gears below.
  "measurements": {
    "meshSize":          { "id": "meshSize",          "label": "Mesh size (mm)",       "kind": "integer", "unit": "mm" },
    "numberOfBeams":     { "id": "numberOfBeams",     "label": "Number of beams",      "kind": "integer" },
    "numberOfTrawlNets": { "id": "numberOfTrawlNets", "label": "Number of trawl nets", "kind": "integer" },
    "timesShot":         { "id": "timesShot",         "label": "Times shot",           "kind": "integer" },
    "hooksHauled":       { "id": "hooksHauled",       "label": "Hooks hauled",         "kind": "integer" }
    // …one entry per shared measurement…
  },

  "gear": [
    { "id": "TBB", "name": "Beam trawl",                "requiredMeasurementIds": ["meshSize", "numberOfBeams"], "variableMeasurementIds": ["timesShot"] },
    { "id": "SX",  "name": "Seine nets (not specified)", "requiredMeasurementIds": ["meshSize"],                  "variableMeasurementIds": ["timesShot"] },
    { "id": "LLD", "name": "Drifting longlines",         "requiredMeasurementIds": [],                            "variableMeasurementIds": ["hooksHauled", "hooksLeft"] },
    { "id": "HMD", "name": "Mechanised dredges",         "requiredMeasurementIds": [],                            "variableMeasurementIds": [] }
    // …one entry per gear…
  ]
}
```

**Fields**

- `gear[].id` — stable FAO gear code.
- `gear[].name` — display name.
- `gear[].requiredMeasurementIds` / `variableMeasurementIds` — ordered lists of ids resolved against the
  top-level `measurements` dictionary.
- `measurements[].id` / `label` — stable id and display text.
- `measurements[].kind` — value type (e.g. `integer`); drives client-side validation (all gear measurements
  are whole numbers).
- `measurements[].unit` — optional unit suffix (e.g. `mm`).

*Alternative:* denormalise the measurement objects inline per gear (bigger payload, simpler parse) if
resolving references client-side is unwanted.

---

## 2. Species reference data

The species catalogue.

```
GET /reference/species
GET /reference/species?query=cod        # optional server-side search
Accept: application/json
If-None-Match: "<etag>"
```

**Design choices:** clients cache the **full list** for offline search. The optional `query` param supports
a future server-filtered mode for very large lists or search-relevance rules. Recorded catch weights are
user-entered per catch and are **not** part of reference data.

### `200 OK`

```jsonc
{
  "version": "2026-08-15",
  "species": [
    { "id": "COD", "name": "Atlantic cod (COD)", "commonName": "Atlantic cod", "faoCode": "COD" },
    { "id": "HAD", "name": "Haddock (HAD)",       "commonName": "Haddock",      "faoCode": "HAD" }
    // …
  ]
}
```

- `id` — stable FAO code.
- `name` — combined display string (`"<Common name> (<FAO code>)"`).
- `commonName` / `faoCode` — provided split so a client can format its own display.

---

## 3. Vessels

Unlike the reference datasets, **vessels are per-user** — a fisher sees the vessels they are authorised to
record against — so this is a personal, authenticated endpoint, not open reference data.

```
GET /vessels
Authorization: Bearer <token>
Accept: application/json
```

### `200 OK`

```jsonc
{
  "version": "2026-09-01T09:00:00Z",
  "vessels": [
    { "id": "GBR000A1234", "name": "ACHILLES", "pln": "PH1234", "homePort": { "id": "0349", "name": "Plymouth" } },
    { "id": "GBR000B5678", "name": "HERCULES", "pln": "BM5678", "homePort": null }
  ]
}
```

- `id` — stable vessel identifier.
- `name` — display name.
- `pln` — Port Letter & Number / registration (likely needed on the catch record; confirm with backend).
- `homePort` — optional; reuses the port shape (§4).

---

## 4. Ports reference data

Public reference data — the tabular list of ports with their locations.

```
GET /reference/ports
Accept: application/json
If-None-Match: "<etag>"
```

### `200 OK`

```jsonc
{
  "version": "2026-07-01",
  "ports": [
    { "id": "0349", "name": "Plymouth", "coordinate": { "latitude": 50.3661, "longitude": -4.1427 } },
    { "id": "0100", "name": "Aberdeen", "coordinate": { "latitude": 57.1436, "longitude": -2.0943 } },
    { "id": "9999", "name": "Unknown",  "coordinate": null }
  ]
}
```

- `id` — stable port identifier.
- `name` — display name.
- `coordinate` — `{ latitude, longitude }` in WGS84 degrees, or `null` if unknown.

This is the same set of ports the map's `map.ports` layer carries (§5), so **the tabular list and the map
port layer should be generated from one source** to avoid drift.

---

## 5. Map data

Reference data for the offline fisheries map: three GeoJSON layers — land (`land`), ICES subrectangles
(`subrectangles`) and ports (`ports`). The map is designed to work **fully offline with no network
requests at runtime**, so these endpoints exist strictly to **deliver updated datasets for a client to
bundle/cache**, never for live tile/feature fetches. Each layer appears in the shared manifest (§0) as
`map.land` / `map.subrectangles` / `map.ports`.

### Layer download

```
GET /reference/map/{layer}          # layer ∈ land | subrectangles | ports
Accept: application/geo+json
If-None-Match: "<etag>"
```

Returns a GeoJSON `FeatureCollection` in WGS84 (EPSG:4326). Typical properties:

- **land** — polygon/multipolygon land masses.
- **subrectangles** — polygons with `sub_code` (stable id), `ICESNAME` (parent rectangle), `AREA_KM2`, and
  the parent rectangle centre `stat_x`/`stat_y`.
- **ports** — points with `port_code`, `port` (name), `lat`, `long_`.

> **Coordinate quality — emit clean WGS84.** Served GeoJSON MUST use correct WGS84 **numeric** coordinates.
> An earlier dataset encoded subrectangle ring vertices in **Web Mercator (EPSG:3857) metres**, and some
> coordinate components as JSON **strings** rather than numbers, which forces every client into a
> reprojection/parse workaround. Emitting clean WGS84 numbers keeps any such client fallback as
> belt-and-braces rather than load-bearing.

**Delivery model:** because the map is fully offline, prefer shipping map data **inside the app** and using
these endpoints only as an out-of-band refresh channel if/when a layer must change between app releases.
This is a decision to confirm with the delivery team.

---

## 6. Favourites (per-user)

A user's saved ports, gear and species. These are **per-user, read/write and offline-first** — the client's
**local store is the source of truth** during a journey, and mutations sync when back online. This is the
one area that needs an **offline mutation queue + conflict resolution**.

All favourites endpoints are user-scoped and require `Authorization: Bearer <token>`.

### Read

```
GET /me/favourites/ports
GET /me/favourites/gear
GET /me/favourites/species
If-None-Match: "<etag>"
```

Each returns the user's list plus a `version` for sync reconciliation. Bodies reuse the reference shapes:

```jsonc
// GET /me/favourites/gear
{
  "version": "2026-09-08T10:15:00Z",
  "gear": [
    {
      "id": "SX",
      "name": "Seine nets (not specified)",
      // Captured required (per-favourite) measurement VALUES live with the favourite:
      "requiredMeasurements": [ { "id": "meshSize", "value": 80 } ]
    }
  ]
}
```

> Note the difference from §1: the **reference** catalogue defines *which* measurements exist and their
> labels; a **favourite** carries the user's captured `requiredMeasurements` **values**. Variable (per-trip)
> values are captured on the catch record, not stored on the favourite.

Ports favourites return port objects (§4); species favourites return species objects (§2), and a favourite
species may also carry recorded weights.

### Add / upsert

Idempotent upsert keyed by `id` (adding an existing id replaces it):

```
PUT /me/favourites/gear/{id}
Content-Type: application/json
If-Match: "<etag>"               # optional optimistic concurrency

{ "id": "SX", "name": "Seine nets (not specified)", "requiredMeasurements": [ { "id": "meshSize", "value": 80 } ] }
```

- `200 OK` / `201 Created` with the stored object + new `ETag`.
- `409 Conflict` if `If-Match` no longer matches — client re-reads and re-applies (see conflict rules).

### Remove

```
DELETE /me/favourites/gear/{id}
```

`204 No Content` on success; `404` if it was already gone (a client should treat this as success —
idempotent).

### Offline queue & conflict resolution (must define before build)

- A client keeps a **local mutation queue** (add/remove) and flushes on reconnect (retry + backoff).
- Each favourite carries a `version`/`updatedAt`; the server rejects stale writes with `409` and the client
  reconciles.
- **Recommended rule:** favourites are a small per-user set with no cross-entity invariants, so
  **last-write-wins per `id`, union across devices** is acceptable and simplest. Removals must be modelled
  as explicit **tombstones** (not "absent"), so an offline add on device A doesn't silently resurrect a
  delete from device B. Confirm before implementing.

---

## 7. Catch record submission

Submits a **completed** catch record. This is the primary write of the whole app and MUST be
**offline-first**: a user completes and "submits" a record with no connectivity, the client stores it
locally as the source of truth, queues it, and flushes to this endpoint on reconnect (retry + backoff).

A catch record is composed of the data captured across the journey: the vessel, the trip's departure and
return dates and ports, one **catch group per gear used** (each with that gear's measurements, its
statistical (sub)area, and the species caught with weights), and a single trip-level list of species
caught but not landed.

```
POST /catch-records
Authorization: Bearer <token>
Content-Type: application/json
Idempotency-Key: <client-generated UUID>
```

### Idempotency (required for offline retry)

Because a queued submission may be sent more than once (flaky network, app relaunch mid-flush), the
request MUST be **idempotent**. The client generates a stable `clientRecordId` (UUID) when the user first
submits and sends it both in the body and as the `Idempotency-Key` header. The server stores it and:

- first time it sees the key → creates the record, returns `201 Created`;
- a repeat of the **same** key → returns the **same** result (`200 OK`, not a duplicate record).

This lets a client safely re-send anything still in its queue without creating duplicates.

### Request body

```jsonc
{
  "clientRecordId": "5b1e7c1a-9d2e-4f7b-8b0a-3f2c1d4e5a6b",  // idempotency key, client-generated
  "capturedAt": "2026-09-08T14:32:00Z",                       // when the user completed it (may be offline)

  "vesselId": "GBR000A1234",
  "departureDate": "2026-09-07",
  "returnDate": "2026-09-08",
  "departurePortId": "0349",
  "returnPortId": "0349",

  // One catch group per gear used on the trip (see the per-gear model):
  "gearCatches": [
    {
      "gearId": "SX",
      // Captured measurement VALUES for this gear (ids resolve against the gear catalogue, §1):
      "requiredMeasurements": [ { "id": "meshSize", "value": 80 } ],
      "variableMeasurements": [ { "id": "timesShot", "value": 3 } ],
      "statisticalArea": "27D86",
      "speciesCaught": [
        {
          "speciesId": "COD",
          "weightAboveMinimumKg": 120,
          "weightBelowMinimumKg": 5,     // optional
          "weightLegallyDiscardedKg": 2  // optional
        }
      ]
    }
  ],

  // Trip-level list — species caught but not landed (asked once, not per gear):
  "speciesNotLanded": [ { "speciesId": "HAD" } ]
}
```

**Notes**

- `vesselId`, `departurePortId`, `returnPortId`, `gearId`, `speciesId` are the stable ids from the
  matching endpoints (§1–§4). Sending ids (not names) keeps the submission robust if a display name
  changes.
- Weights are numeric kilograms. `weightAboveMinimumKg` is always present for a caught species; the other
  two are optional.
- A gear that defines no measurements simply sends empty measurement arrays.

### `201 Created` (or `200 OK` on idempotent replay)

The server assigns the authoritative **reference number** — the client MUST NOT invent one.

```jsonc
{
  "id": "cr_01J9Z8...",             // server record id
  "clientRecordId": "5b1e7c1a-...", // echoed idempotency key
  "referenceNumber": "A1234520260908143200",
  "status": "submitted",            // submitted | accepted | rejected
  "submittedAt": "2026-09-08T15:00:00Z"
}
```

### `422 Unprocessable Entity` (validation)

Returns per-field errors so the client can route the user back to the right screen to fix them, using the
standard error envelope plus a `fields` array:

```jsonc
{
  "error": {
    "code": "validation_failed",
    "message": "One or more fields are invalid",
    "traceId": "b6b1…",
    "fields": [
      { "path": "gearCatches[0].speciesCaught[0].weightAboveMinimumKg", "code": "must_be_positive", "message": "Weight must be greater than 0" }
    ]
  }
}
```

### List previous submissions

Returns the authenticated user's previously-submitted catch records with their current status, for a
home/history screen. Newest first.

```
GET /catch-records                       # summary rows (default)
GET /catch-records?view=full             # full catch records inline (see note below)
Authorization: Bearer <token>
Accept: application/json
If-None-Match: "<etag>"
```

**By default this returns lightweight summary rows, NOT the full catch record.** Each row carries only
what a history list needs to render (reference number, status, vessel, dates); the **full** record —
gear catches, measurements, statistical areas, species and weights — is fetched per record from
`GET /catch-records/{id}`. This keeps the list small and fast, which matters most on a poor connection.

A client that wants to cache complete records for offline viewing (e.g. so a user can open any past
record with no connectivity) can request `?view=full`, which returns the **same list but with each entry
expanded to the full submission body** (the §7 request shape plus `id`, `referenceNumber`, `status`,
`submittedAt`, `updatedAt`). Prefer the default summary for the routine history screen and reserve
`?view=full` for an explicit "download my records for offline" sync.

#### `200 OK` (default — summary rows)

```jsonc
{
  "version": "2026-09-08T15:00:00Z",
  "catchRecords": [
    {
      "id": "cr_01J9Z8...",
      "referenceNumber": "A1234520260908143200",
      "status": "accepted",                 // submitted | accepted | rejected
      "vesselId": "GBR000A1234",
      "vesselName": "ACHILLES",             // denormalised for display, saves a lookup
      "departureDate": "2026-09-07",
      "returnDate": "2026-09-08",
      "submittedAt": "2026-09-08T15:00:00Z",
      "updatedAt": "2026-09-08T16:20:00Z"
    },
    {
      "id": "cr_01J9Z7...",
      "referenceNumber": "A1234520260901101500",
      "status": "rejected",
      "vesselId": "GBR000B5678",
      "vesselName": "HERCULES",
      "departureDate": "2026-08-31",
      "returnDate": "2026-09-01",
      "submittedAt": "2026-09-01T10:15:00Z",
      "updatedAt": "2026-09-02T09:00:00Z"
    }
  ]
}
```

Each default entry is a **summary** for a list row — to read a record's gear/species/weights, fetch it
by id (below) or request `?view=full`. `status` reflects the backend's processing outcome
(`submitted` → received, `accepted` → passed processing, `rejected` → needs attention). The list is
cache-revalidation friendly (`ETag` / `If-None-Match`) like the reference endpoints, and a client MUST
also show its own **locally-queued, not-yet-submitted** records alongside this list (offline-first) so a
record the user completed offline is visible before it has reached the backend.

### Single submission (status detail)

```
GET /catch-records/{id}
Authorization: Bearer <token>
```

Returns the full stored record plus its current `status` and, when `rejected`, any per-field reasons
(same `fields` shape as the `422` response above) so the client can show why and let the user correct it.

### Offline queue behaviour (must define before build)

- On "submit" the client persists the record locally and enqueues it; the local copy is the source of
  truth until confirmed.
- The queue flushes on reconnect with retry + backoff; every attempt reuses the same `clientRecordId`.
- `2xx` → mark the local record submitted and store the returned `referenceNumber`.
- `422` → surface the field errors; the record stays a local draft for correction (do not silently drop).
- `401` → refresh the token and retry; do not discard the queued record.
- `5xx` / network failure → keep it queued and retry later.

---

## Open questions

1. **Manifest granularity** — is a single `/reference/manifest` (§0) covering gear, species, ports and the
   three map layers the right split, or should map layers have their own manifest? One shared manifest means
   a single launch-time round-trip for all reference data.
2. **Vessel model fields** — is `pln` required on the catch record? Any vessel status/decommission flag?
3. **Server-side vs client-side search** for species/ports — do we ever need `?query=` server filtering
   (very large lists, or search-relevance rules), or is client-side filtering of the cached list enough?
4. **Map data delivery** — ship only in-app, or support out-of-band GeoJSON refresh via §5?
5. **Favourites conflict policy** — confirm last-write-wins + tombstones, and whether favourites sync across
   a user's devices at all in v1.
6. **Localisation of labels** — the API returns English `label` text directly; confirm each client owns all
   localisation, and whether any dataset ever needs `Accept-Language` content negotiation.
7. **One source for ports** — confirm the tabular `ports` list (§4) and the `map.ports` layer (§5) are
   generated from a single source so they never drift.
8. **Submission validation split** — which catch-record rules are enforced client-side vs returned as
   `422` field errors, and is the `fields[].path` scheme above enough to route a user back to the exact
   screen/field?
9. **Reference number** — confirm it is always server-assigned on submission, and what a client should
   display for a queued-but-not-yet-submitted record.
10. **Draft sync** — is only the *completed* record submitted (§7), or does an in-progress draft also sync
    to the backend so a journey can resume across devices?
11. **History list payload** — is a summary list + per-record detail fetch the right split, or should the
    history screen always pull full records (via `?view=full`) so every past record is viewable offline?
    Depends on how many records a user accumulates and whether offline access to old records is required.
