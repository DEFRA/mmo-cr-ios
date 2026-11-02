//
//  CatchRecordEndpoint.swift
//  record-catch
//
//  Pure URLRequest construction for the catch-record submission API. Mirrors
//  ReferenceDataEndpoint.swift's conventions (ADR-0018) ahead of the real backend contract.
//
//  ⚠️ Placeholder route: the actual catch-record service URL/path has not been confirmed by the
//  backend team yet. `{baseURL}/api/v1/catch-records` is a best-guess, following the reference-data
//  API's own `/api/v1/{dataset}` convention (see `ReferenceDataPath.apiRoot` in
//  ReferenceDataEndpoint.swift) purely so this connector has *something* consistent to build and
//  test against. Update `CatchRecordPath.apiRoot` below (and retest) once the real contract lands —
//  do not assume this path is correct for a live backend.
//

import Foundation

/// Builds the `URLRequest` for `POST {baseURL}/api/v1/catch-records` — submits a completed catch
/// report. Deliberately side-effect-free (no I/O), matching `makeReferenceDataRequest` etc.
///
/// - Parameters:
///   - baseURL: The app's configured API base URL (see `APIConfiguration`).
///   - body: The JSON-encodable request body (see `CatchRecordSubmissionRequestDTO`).
///   - bearerToken: When non-`nil`, attached as `Authorization: Bearer <token>`. When `nil`, the
///     request carries **no** `Authorization` header at all (never an empty/placeholder one) —
///     matches the reference-data connector's convention (see ADR-0018 §5).
///   - requestId: Correlation id sent as `x-cdp-request-id`, matching the reference-data
///     connector's convention. Defaults to a fresh `UUID` per call; tests inject a fixed value.
///   - encoder: The `JSONEncoder` used to serialise `body` into the request's `httpBody`. Injected
///     (rather than constructed here) so `CatchRecordService` controls the encoding strategy (e.g.
///     ISO8601 dates) in one place — see its initialiser.
/// - Throws: Whatever `encoder.encode(body)` throws (an `EncodingError`) if `body` cannot be
///   serialised.
/// - Returns: A fully-formed `POST` request with a JSON body and `Accept`/`Content-Type:
///   application/json` headers.
nonisolated func makeSubmitCatchRecordRequest(
    baseURL: URL,
    body: CatchRecordSubmissionRequestDTO,
    bearerToken: String?,
    requestId: String = UUID().uuidString,
    encoder: JSONEncoder
) throws -> URLRequest {
    let url = makeCatchRecordURL(baseURL: baseURL, pathSegments: CatchRecordPath.apiRoot)
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(requestId, forHTTPHeaderField: "x-cdp-request-id")
    if let bearerToken {
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    }
    request.httpBody = try encoder.encode(body)
    return request
}

/// The fixed root path segments for the catch-record submission route — see the file-level
/// placeholder-route warning above.
private enum CatchRecordPath {
    static let apiRoot = ["api", "v1", "catch-records"]
}

/// Shared URL assembly, mirroring `makeReferenceDataURL` in `ReferenceDataEndpoint.swift` — appends
/// `pathSegments` after any existing path prefix on `baseURL` (e.g. a CDP gateway prefix) rather
/// than replacing it.
private func makeCatchRecordURL(baseURL: URL, pathSegments: [String]) -> URL {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    let suffix = pathSegments.map { "/\($0)" }.joined()
    components?.path += suffix
    return components?.url ?? baseURL
}
