//
//  APIError.swift
//  record-catch
//
//  Typed, total error model for the reference-data API connector (see ADR-0018). Modelled as an
//  enum rather than a stringly-typed Error so every failure mode is enumerable, testable and
//  `Equatable`, and so call sites can distinguish transient/retryable failures (`.offline`,
//  `.timedOut`) from terminal ones (`.unauthorized`, `.decoding`) per
//  security.instructions.md's error-handling guidance.
//

import Foundation

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
    /// A `4xx` response not otherwise mapped below, carrying the raw status code.
    case transport(code: Int)
    /// `401 Unauthorized` — typically a missing/invalid bearer token.
    case unauthorized
    /// `403 Forbidden`.
    case forbidden
    /// `404 Not Found`.
    case notFound
    /// A `5xx` server error, carrying the raw status code.
    case server(status: Int)
    /// The response body could not be decoded into the expected shape. The associated `String` is
    /// a non-sensitive, human-readable description (never raw response body content) suitable for
    /// diagnostic logging.
    case decoding(String)
}
