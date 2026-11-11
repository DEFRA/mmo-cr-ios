//
//  CatchRecordEndpoint.swift
//  record-catch
//
//  Pure URLRequest construction for the Catch Recording Service's 18 in-scope endpoints (ADR-0025)
//  — mirrors `ReferenceDataEndpoint.swift`'s conventions (ADR-0018): no I/O, fully testable without
//  a real network, and the only place headers/paths/query items are assembled.
//
//  ⚠️ `If-Match` is sent as the service's documented pattern requires — plain digits (e.g. `"3"`),
//  not a quoted HTTP entity tag as RFC 9110 §13.1.1 would normally expect. Isolated to this one
//  function so it is a single-line change if the backend's expectations turn out to differ (see
//  ADR-0025 "Open questions").
//

import Foundation

/// Every operation this connector performs, one case per `(method, path)` pair in the service's
/// OpenAPI spec (18 in-scope routes — see ADR-0025 for the 5 explicitly excluded ones: the
/// single-example-document route, the submission-artifact download, `/completion`, and skippers).
nonisolated enum CatchRecordAPIRoute: Equatable, Sendable {
    case health
    case listExampleData
    case listCatchRecords(limit: Int?, status: PersistedCatchRecordStatus?)
    case createDraft
    case retrieveCatchRecord(catchRecordId: String)
    case replaceCatchRecord(catchRecordId: String)
    case saveCatchRecordSection(catchRecordId: String)
    case abandonDraft(catchRecordId: String)
    case history(catchRecordId: String, limit: Int?)
    case submit(catchRecordId: String)
    case listSubmissions(catchRecordId: String)
    case startEdit(catchRecordId: String)
    case listFavouriteGears(vesselId: String)
    case addFavouriteGear(vesselId: String)
    case removeFavouriteGear(vesselId: String, gearId: String)
    case listFavouriteSpecies(vesselId: String)
    case addFavouriteSpecies(vesselId: String)
    case removeFavouriteSpecies(vesselId: String, speciesId: String)
    case listFavouritePorts(vesselId: String)
    case addFavouritePort(vesselId: String)
    case removeFavouritePort(vesselId: String, portId: String)

    var httpMethod: String {
        switch self {
        case .health, .listExampleData, .listCatchRecords, .retrieveCatchRecord, .history,
             .listSubmissions, .listFavouriteGears, .listFavouriteSpecies, .listFavouritePorts:
            return "GET"
        case .createDraft, .submit, .startEdit, .addFavouriteGear, .addFavouriteSpecies, .addFavouritePort:
            return "POST"
        case .replaceCatchRecord:
            return "PUT"
        case .saveCatchRecordSection:
            return "PATCH"
        case .abandonDraft, .removeFavouriteGear, .removeFavouriteSpecies, .removeFavouritePort:
            return "DELETE"
        }
    }

    var pathSegments: [String] {
        switch self {
        case .health:
            return ["health"]
        case .listExampleData:
            return ["example"]
        case .listCatchRecords, .createDraft:
            return ["v1", "catch-records"]
        case .retrieveCatchRecord(let id), .replaceCatchRecord(let id), .saveCatchRecordSection(let id), .abandonDraft(let id):
            return ["v1", "catch-records", id]
        case .history(let id, _):
            return ["v1", "catch-records", id, "history"]
        case .submit(let id):
            return ["v1", "catch-records", id, "submission"]
        case .listSubmissions(let id):
            return ["v1", "catch-records", id, "submissions"]
        case .startEdit(let id):
            return ["v1", "catch-records", id, "edit-start"]
        case .listFavouriteGears(let vesselId), .addFavouriteGear(let vesselId):
            return ["v1", "vessels", vesselId, "favourite-gears"]
        case .removeFavouriteGear(let vesselId, let gearId):
            return ["v1", "vessels", vesselId, "favourite-gears", gearId]
        case .listFavouriteSpecies(let vesselId), .addFavouriteSpecies(let vesselId):
            return ["v1", "vessels", vesselId, "favourite-species"]
        case .removeFavouriteSpecies(let vesselId, let speciesId):
            return ["v1", "vessels", vesselId, "favourite-species", speciesId]
        case .listFavouritePorts(let vesselId), .addFavouritePort(let vesselId):
            return ["v1", "vessels", vesselId, "favourite-ports"]
        case .removeFavouritePort(let vesselId, let portId):
            return ["v1", "vessels", vesselId, "favourite-ports", portId]
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .listCatchRecords(let limit, let status):
            var items: [URLQueryItem] = []
            if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
            if let status { items.append(URLQueryItem(name: "status", value: status.rawValue)) }
            return items
        case .history(_, let limit):
            guard let limit else { return [] }
            return [URLQueryItem(name: "limit", value: String(limit))]
        default:
            return []
        }
    }

    /// `true` for `.health`/`.listExampleData` — both unauthenticated per the spec (`security: []`),
    /// so `makeCatchRecordRequest` never attaches an `Authorization` header for them even if a
    /// bearer token is available.
    var isUnauthenticated: Bool {
        switch self {
        case .health, .listExampleData: return true
        default: return false
        }
    }
}

/// Sentinel "no request body" type for routes that never send one (every `GET`/`DELETE` route).
nonisolated struct NoRequestBody: Encodable, Sendable {}

/// Builds the `URLRequest` for a `GET`/`DELETE` route carrying no body.
///
/// - Parameters:
///   - ifMatch: Attached as `If-Match` when non-`nil` — required by `abandonDraft`, but this
///     function doesn't enforce that; the caller (`CatchRecordService`) is responsible for always
///     supplying it where the route requires it.
///   - requestId: Correlation id sent as `x-cdp-request-id`, matching the reference-data
///     connector's convention. Defaults to a fresh `UUID` per call; tests inject a fixed value.
nonisolated func makeCatchRecordRequest(
    route: CatchRecordAPIRoute,
    baseURL: URL,
    bearerToken: String?,
    ifMatch: String? = nil,
    idempotencyKey: String? = nil,
    requestId: String = UUID().uuidString
) -> URLRequest {
    var request = URLRequest(url: makeCatchRecordURL(baseURL: baseURL, route: route))
    request.httpMethod = route.httpMethod
    applyCommonHeaders(to: &request, route: route, bearerToken: bearerToken, ifMatch: ifMatch, idempotencyKey: idempotencyKey, requestId: requestId)
    return request
}

/// Builds the `URLRequest` for a route carrying a JSON-encoded `body` (`POST`/`PUT`/`PATCH`
/// routes).
///
/// - Parameters:
///   - idempotencyKey: Attached as `Idempotency-Key` when non-`nil` — always caller-supplied
///     (never generated here), so a future offline-queue retry can reuse the exact same key (see
///     ADR-0025 "Caller-supplied values").
///   - encoder: Injected so `CatchRecordService` controls the encoding strategy (e.g. ISO8601
///     dates) in one place.
/// - Throws: Whatever `encoder.encode(body)` throws (an `EncodingError`) if `body` cannot be
///   serialised.
nonisolated func makeCatchRecordRequest<Body: Encodable>(
    route: CatchRecordAPIRoute,
    baseURL: URL,
    body: Body,
    bearerToken: String?,
    ifMatch: String? = nil,
    idempotencyKey: String? = nil,
    requestId: String = UUID().uuidString,
    encoder: JSONEncoder
) throws -> URLRequest {
    var request = URLRequest(url: makeCatchRecordURL(baseURL: baseURL, route: route))
    request.httpMethod = route.httpMethod
    applyCommonHeaders(to: &request, route: route, bearerToken: bearerToken, ifMatch: ifMatch, idempotencyKey: idempotencyKey, requestId: requestId)
    request.httpBody = try encoder.encode(body)
    return request
}

private func applyCommonHeaders(
    to request: inout URLRequest,
    route: CatchRecordAPIRoute,
    bearerToken: String?,
    ifMatch: String?,
    idempotencyKey: String?,
    requestId: String
) {
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(requestId, forHTTPHeaderField: "x-cdp-request-id")
    if let ifMatch { request.setValue(ifMatch, forHTTPHeaderField: "If-Match") }
    if let idempotencyKey { request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key") }
    if let bearerToken, !route.isUnauthenticated {
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    }
}

/// Shared URL assembly, mirroring `makeReferenceDataURL` in `ReferenceDataEndpoint.swift` — appends
/// the route's path segments (and any query items) after any existing path prefix on `baseURL`
/// (e.g. a CDP gateway prefix) rather than replacing it.
private func makeCatchRecordURL(baseURL: URL, route: CatchRecordAPIRoute) -> URL {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    let suffix = route.pathSegments.map { "/\($0)" }.joined()
    components?.path += suffix
    let queryItems = route.queryItems
    components?.queryItems = queryItems.isEmpty ? nil : queryItems
    return components?.url ?? baseURL
}
