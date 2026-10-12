//
//  APIError.swift
//  record-catch
//
//  Typed, total error model for the reference-data API connector (see ADR-0018). Collapsed to a
//  single `.response` case for every HTTP failure (see the ADR-0018 addendum "Simplified error
//  model"): the backend always returns a stable, machine-readable `code` plus an explicit
//  `retryable` flag in its standard error envelope, so separate `.unauthorized`/`.forbidden`/
//  `.notFound`/`.transport`/`.server` cases would only duplicate information already carried by
//  `status` and `details?.code`. Call sites use the `is*`/`isRetryable` helpers below instead of
//  matching raw status integers.
//

import Foundation

/// The reference-data API's standard error envelope (`error` object) — see ADR-0018 addendum
/// "Standard error envelope". Deliberately omits `message` and `details`: server-authored text
/// must never become user-facing copy (GOV.UK content patterns — see
/// figma-design.instructions.md §6), and `details` can echo request input back.
nonisolated struct APIErrorDetails: Decodable, Equatable, Sendable {
    /// Stable, machine-readable failure code, e.g. `"reference_data_unavailable"`,
    /// `"unauthorized"`. Distinguishes failure causes that share the same HTTP status (e.g. a
    /// `503` from an unavailable Authentication Service vs. incomplete startup hydration).
    let code: String
    /// Echoes the request's `x-cdp-request-id` correlation header — the value to quote when
    /// asking the backend team to look up a specific failure.
    let traceId: String?
    let dataset: String?
    /// The server's own view on whether retrying is sensible. Prefer this over inferring
    /// retryability from the status code alone — see `APIError.isRetryable`.
    let retryable: Bool?
}

/// Errors the reference-data API connector can produce. See `ReferenceDataClient.swift` for the
/// HTTP-status/`URLError` mapping into these cases.
nonisolated enum APIError: Error, Sendable, Equatable {
    /// The app's base URL configuration is missing, blank, malformed, or (outside DEBUG) not
    /// HTTPS. See `APIConfiguration`.
    case invalidConfiguration
    /// No network connectivity (`URLError.notConnectedToInternet`/`.networkConnectionLost`).
    /// Transient/retryable — consistent with the app's offline-first posture.
    case offline
    /// The request timed out (`URLError.timedOut`). Transient/retryable.
    case timedOut
    /// The response body could not be decoded into the expected shape. The associated `String` is
    /// a non-sensitive, human-readable description (never raw response body content) suitable for
    /// diagnostic logging.
    case decoding(String)
    /// Any non-2xx HTTP response, carrying the raw status and the decoded standard error
    /// envelope when the body matched it. `details` is `nil` when the body was absent, empty, or
    /// didn't match the envelope shape — the status is still authoritative in that case.
    ///
    /// Also used — always with `details: nil` — for the rare cases where no real HTTP response
    /// was received at all: an unmapped `URLError` (carrying its raw, non-HTTP `errorCode`, which
    /// is always negative) or a non-HTTP `URLResponse` from the transport layer (see
    /// `HTTPPerforming.swift`). `status` is therefore a genuine HTTP status in the common case,
    /// but not guaranteed to be one in these two transport-level fallback paths.
    case response(status: Int, details: APIErrorDetails?)
}

extension APIError {
    /// `401 Unauthorized` — typically a missing/invalid bearer token.
    var isUnauthorized: Bool { statusCode == 401 }
    /// `403 Forbidden` — authenticated but missing the required permission.
    var isForbidden: Bool { statusCode == 403 }
    /// `404 Not Found`.
    var isNotFound: Bool { statusCode == 404 }
    /// `503 Service Unavailable` — e.g. `reference_data_unavailable` or
    /// `authentication_service_unavailable`; distinguish the two via `errorCode`.
    var isServiceUnavailable: Bool { statusCode == 503 }

    /// The server's own `retryable` flag when the response carried one; otherwise derived from
    /// known-transient failure modes (offline, timeout, any `5xx` status).
    var isRetryable: Bool {
        switch self {
        case .offline, .timedOut:
            return true
        case let .response(status, details):
            if let retryable = details?.retryable { return retryable }
            return (500..<600).contains(status)
        case .invalidConfiguration, .decoding:
            return false
        }
    }

    /// The server's machine-readable failure code (e.g. `"reference_data_unavailable"`), when a
    /// `.response` carried a decodable envelope.
    var errorCode: String? {
        if case let .response(_, details) = self { return details?.code }
        return nil
    }

    /// The correlation id echoing the request's `x-cdp-request-id` header, when present.
    var traceId: String? {
        if case let .response(_, details) = self { return details?.traceId }
        return nil
    }

    private var statusCode: Int? {
        if case let .response(status, _) = self { return status }
        return nil
    }
}
