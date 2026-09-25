//
//  ReferenceDataEndpoint.swift
//  record-catch
//
//  Pure URLRequest construction for the reference-data API (see ADR-0018 §2/§5). Deliberately
//  side-effect-free (no I/O) so request-building is unit-testable without any network.
//
//  Neither route sends a `view` query parameter — the connector deliberately uses the API's
//  default **canonical** view rather than `?view=mobile` (see ADR-0018's correction note and
//  `VesselDTO`/`VesselOption`, which model the canonical shape).
//

import Foundation

/// The reference-data datasets the app knows how to fetch. Only `vessels` is concretely modelled
/// today; the live API's envelope shape is generic (`ReferenceDataEnvelope`), so a future dataset
/// (ports, gear, species) is a new case here plus a new DTO/domain mapping — not a new networking
/// shape. There is deliberately no "list collections" endpoint, since the live contract exposes
/// none.
nonisolated enum ReferenceDataset: String, Sendable {
    case vessels
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
/// - Returns: A fully-formed `GET` request with an `Accept: application/json` header.
nonisolated func makeReferenceDataRequest(
    baseURL: URL,
    dataset: ReferenceDataset,
    bearerToken: String?
) -> URLRequest {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.path += "/api/v1/reference-data/\(dataset.rawValue)"

    // `URLComponents` only fails to produce a URL for a malformed base URL, which
    // `APIConfiguration` has already validated by construction; force-unwrapping here would still
    // be a production `!`, so fall back to the base URL itself rather than crash.
    let url = components?.url ?? baseURL

    return makeGETRequest(url: url, bearerToken: bearerToken)
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
/// - Returns: A fully-formed `GET` request with an `Accept: application/json` header.
nonisolated func makeReferenceDataItemRequest(
    baseURL: URL,
    dataset: ReferenceDataset,
    itemId: String,
    bearerToken: String?
) -> URLRequest {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.path += "/api/v1/reference-data/\(dataset.rawValue)/\(itemId)"

    // `URLComponents` only fails to produce a URL for a malformed base URL, which
    // `APIConfiguration` has already validated by construction; force-unwrapping here would still
    // be a production `!`, so fall back to the base URL itself rather than crash.
    let url = components?.url ?? baseURL

    return makeGETRequest(url: url, bearerToken: bearerToken)
}

/// Shared `GET` request assembly for both reference-data routes above.
private func makeGETRequest(url: URL, bearerToken: String?) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let bearerToken {
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    }
    return request
}
