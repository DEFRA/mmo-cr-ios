//
//  ReferenceDataEndpoint.swift
//  record-catch
//
//  Pure URLRequest construction for the reference-data API (see ADR-0018 §2/§5). Deliberately
//  side-effect-free (no I/O) so request-building is unit-testable without any network.
//
//  Neither dataset route sends a `view` query parameter — the connector deliberately uses the
//  API's default **canonical** view rather than `?view=mobile` (see ADR-0018's correction note
//  and `VesselDTO`/`VesselOption`, which model the canonical shape). More generally, **no route
//  built here ever sends a query parameter of any kind**: the app fetches every dataset in full,
//  and the backend only engages pagination once a query key *other than* `view` is present (see
//  the ADR-0018 addendum "Fetch-all, no query parameters") — sending one later without also
//  sending `offset`/`limit` would silently truncate results to the backend's default page size.
//
//  `makeReferenceDataHealthRequest` builds `GET {baseURL}/health`, the one route in this file that
//  is **not** under `/api/v1/reference-data` — it's the service root's plain liveness probe, added
//  alongside the dataset/manifest routes for the connector's own use (e.g. a future startup/sync
//  readiness check), distinct from the `/health/ready` readiness route ADR-0018 explicitly parked
//  as unimplemented.
//

import Foundation

/// The reference-data datasets the app knows how to fetch. `vessels`, `species` and `ports` are
/// concretely modelled today; the live API's envelope shape is generic (`ReferenceDataEnvelope`),
/// so a future dataset (gear) is a new case here plus a new DTO/domain mapping — not a new
/// networking shape. There is deliberately no "list collections" endpoint, since the live contract
/// exposes none. The manifest route (`makeReferenceDataManifestRequest` below) is **not** a case
/// here — it isn't a dataset and has no single-item route.
nonisolated enum ReferenceDataset: String, Sendable {
    case vessels
    case species
    case ports
}

/// Builds the `URLRequest` for `GET {baseURL}/api/v1/reference-data/{dataset}` — the
/// **collection** route, which returns the `ReferenceDataEnvelope` wrapper (see ADR-0018 §2).
/// There is deliberately **no** collection-id path segment: the live API has no such concept —
/// `collectionId` only ever appears as a *response* field inside the envelope, never as a request
/// path component (see ADR-0018's correction note for how this was originally mis-inferred).
///
/// - Parameters:
///   - baseURL: The app's configured API base URL (see `APIConfiguration`).
///   - dataset: Which reference-data collection to fetch.
///   - bearerToken: When non-`nil`, attached as `Authorization: Bearer <token>`. When `nil`, the
///     request carries **no** `Authorization` header at all (never an empty/placeholder one) —
///     see ADR-0018 §5.
///   - requestId: Correlation id sent as `x-cdp-request-id`, echoed by the backend as the error
///     envelope's `traceId` (see ADR-0018 addendum "Correlation id"). Defaults to a fresh `UUID`
///     per call; tests inject a fixed value to assert on it.
/// - Returns: A fully-formed `GET` request with an `Accept: application/json` header.
nonisolated func makeReferenceDataRequest(
    baseURL: URL,
    dataset: ReferenceDataset,
    bearerToken: String?,
    requestId: String = UUID().uuidString
) -> URLRequest {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.path += "/api/v1/reference-data/\(dataset.rawValue)"

    // `URLComponents` only fails to produce a URL for a malformed base URL, which
    // `APIConfiguration` has already validated by construction; force-unwrapping here would still
    // be a production `!`, so fall back to the base URL itself rather than crash.
    let url = components?.url ?? baseURL

    return makeGETRequest(url: url, bearerToken: bearerToken, requestId: requestId)
}

/// Builds the `URLRequest` for `GET {baseURL}/api/v1/reference-data/{dataset}/{itemId}` — the
/// **single-item** route, which returns a **bare** item object (not wrapped in a
/// `ReferenceDataEnvelope`) — see ADR-0018 §2 and the correction note recording how this differs
/// from the collection route above.
///
/// - Parameters:
///   - baseURL: The app's configured API base URL (see `APIConfiguration`).
///   - dataset: Which reference-data dataset the item belongs to.
///   - itemId: The item identifier, percent-encoded into the path by `URLComponents`.
///   - bearerToken: When non-`nil`, attached as `Authorization: Bearer <token>`. When `nil`, the
///     request carries **no** `Authorization` header at all (never an empty/placeholder one) —
///     see ADR-0018 §5.
///   - requestId: As above.
/// - Returns: A fully-formed `GET` request with an `Accept: application/json` header.
nonisolated func makeReferenceDataItemRequest(
    baseURL: URL,
    dataset: ReferenceDataset,
    itemId: String,
    bearerToken: String?,
    requestId: String = UUID().uuidString
) -> URLRequest {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.path += "/api/v1/reference-data/\(dataset.rawValue)/\(itemId)"

    // `URLComponents` only fails to produce a URL for a malformed base URL, which
    // `APIConfiguration` has already validated by construction; force-unwrapping here would still
    // be a production `!`, so fall back to the base URL itself rather than crash.
    let url = components?.url ?? baseURL

    return makeGETRequest(url: url, bearerToken: bearerToken, requestId: requestId)
}

/// Builds the `URLRequest` for `GET {baseURL}/api/v1/reference-data/manifest` — the active
/// version/GUID/itemCount of every persisted dataset (see ADR-0018 addendum "Manifest"). Unlike
/// the dataset routes above, this request **bypasses the local HTTP cache**
/// (`.reloadIgnoringLocalCacheData`): the API serves it with `Cache-Control: max-age=3600`, which
/// would otherwise let `URLCache` silently serve an hour-old manifest — defeating its purpose as
/// a change-detection signal (see ADR-0018 addendum "URLCache position"). There is deliberately
/// no `?include=` support: the app always wants every dataset's entry, and this connector never
/// sends query parameters (see the file-level doc comment above).
///
/// - Parameters:
///   - baseURL: The app's configured API base URL (see `APIConfiguration`).
///   - bearerToken: As above.
///   - requestId: As above.
/// - Returns: A fully-formed `GET` request with an `Accept: application/json` header and a cache
///   policy that forces revalidation with the network on every call.
nonisolated func makeReferenceDataManifestRequest(
    baseURL: URL,
    bearerToken: String?,
    requestId: String = UUID().uuidString
) -> URLRequest {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.path += "/api/v1/reference-data/manifest"

    // `URLComponents` only fails to produce a URL for a malformed base URL, which
    // `APIConfiguration` has already validated by construction; force-unwrapping here would still
    // be a production `!`, so fall back to the base URL itself rather than crash.
    let url = components?.url ?? baseURL

    var request = makeGETRequest(url: url, bearerToken: bearerToken, requestId: requestId)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    return request
}

/// Builds the `URLRequest` for `GET {baseURL}/health` — the backend's plain liveness probe.
/// Deliberately **not** prefixed with `/api/v1/reference-data` (it isn't a reference-data route at
/// all, just the service root's health check) and, like every other route in this file, sends
/// **no** query parameters. The response body shape is not modelled here: `RemoteReferenceDataClient.
/// checkHealth()` only cares whether the request succeeds (2xx) or fails, matching the connector's
/// existing status-code-driven `APIError` mapping rather than assuming an undocumented schema.
///
/// - Parameters:
///   - baseURL: The app's configured API base URL (see `APIConfiguration`).
///   - bearerToken: When non-`nil`, attached as `Authorization: Bearer <token>`. When `nil`, the
///     request carries **no** `Authorization` header at all (never an empty/placeholder one) —
///     see ADR-0018 §5. A health probe may not require auth at all, but the request is built
///     identically to every other route here for consistency.
///   - requestId: As above.
/// - Returns: A fully-formed `GET` request with an `Accept: application/json` header.
nonisolated func makeReferenceDataHealthRequest(
    baseURL: URL,
    bearerToken: String?,
    requestId: String = UUID().uuidString
) -> URLRequest {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.path += "/health"

    // `URLComponents` only fails to produce a URL for a malformed base URL, which
    // `APIConfiguration` has already validated by construction; force-unwrapping here would still
    // be a production `!`, so fall back to the base URL itself rather than crash.
    let url = components?.url ?? baseURL

    return makeGETRequest(url: url, bearerToken: bearerToken, requestId: requestId)
}

/// Shared `GET` request assembly for every reference-data route above.
private func makeGETRequest(url: URL, bearerToken: String?, requestId: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(requestId, forHTTPHeaderField: "x-cdp-request-id")
    if let bearerToken {
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    }
    return request
}
