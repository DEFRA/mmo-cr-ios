//
//  CatchRecordErrorEnvelope.swift
//  record-catch
//
//  Decodes the Catch Recording Service's standard error response body — a **flat** shape
//  (`statusCode`, `code`, `message`, `correlationId`, `details[]`) — distinct from the
//  reference-data API's `{ "error": { ... } }` envelope (`APIErrorDetails`, ADR-0018). Mapped into
//  the same `APIErrorDetails` type the rest of the app's error-handling already understands, so
//  `APIError`'s `isUnauthorized`/`isConflict`/etc. helpers and `NetworkLogger` work unchanged for
//  this connector too (see ADR-0025 "Error mapping").
//

import Foundation

/// The Catch Recording Service's flat error body. Only `code` and `correlationId` are ever carried
/// forward into `APIErrorDetails` — `message` and `details` are **deliberately dropped** (never
/// stored, logged, or surfaced): server-authored text must never become user-facing copy (GOV.UK
/// content patterns — see figma-design.instructions.md §6) or leak into diagnostics, mirroring the
/// reference-data connector's own `APIErrorDetails` doc comment.
nonisolated struct CatchRecordErrorEnvelope: Decodable, Sendable {
    let statusCode: Int
    let code: String
    let correlationId: String?

    /// Best-effort decode of the Catch Recording Service's error body from a non-2xx response.
    /// Returns `nil` — never throws — when the body is empty or doesn't match this shape, so a
    /// malformed error body can never mask the real HTTP-status failure (mirrors
    /// `RemoteReferenceDataClient.decodeErrorDetails`).
    static func decodeDetails(from data: Data, decoder: JSONDecoder) -> APIErrorDetails? {
        guard !data.isEmpty, let envelope = try? decoder.decode(CatchRecordErrorEnvelope.self, from: data) else {
            return nil
        }
        return APIErrorDetails(code: envelope.code, traceId: envelope.correlationId, dataset: nil, retryable: nil)
    }
}
