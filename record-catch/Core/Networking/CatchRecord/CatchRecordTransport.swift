//
//  CatchRecordTransport.swift
//  record-catch
//
//  Shared send/decode/error-mapping logic for the Catch Recording Service connector — composed
//  into `CatchRecordService`/`VesselFavouritesService`/`CatchRecordPlatformService` (ADR-0025)
//  rather than duplicated across them, mirroring `RemoteReferenceDataClient.send(_:fallbackPath:decode:)`.
//

import Foundation

/// Shared transport used by every Catch Recording Service connector type. Resolves the bearer
/// token, sends the request, logs it (method/path/status/duration — never headers, the token, or
/// the body), maps any non-2xx status into `APIError.response`, and decodes the body on success.
nonisolated struct CatchRecordTransport: Sendable {
    let httpClient: HTTPPerforming
    let tokenProvider: AuthTokenProviding
    let logger: NetworkLogger

    /// Decodes ISO 8601 timestamps the Catch Recording Service may send with or without fractional
    /// seconds (e.g. `2026-11-11T10:00:00Z` or `2026-11-11T10:00:00.000Z`) — `Foundation`'s built-in
    /// `.iso8601` strategy only accepts the former (see ADR-0025 "Open questions").
    static let dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let date = Self.fractionalSecondsFormatter.date(from: rawValue) {
            return date
        }
        if let date = Self.wholeSecondsFormatter.date(from: rawValue) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected an ISO 8601 date string, with or without fractional seconds; got \(rawValue)"
        )
    }

    private static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let wholeSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Resolves the bearer token, proceeding with `nil` (i.e. no `Authorization` header) if the
    /// provider throws — matches `RemoteReferenceDataClient.resolvedToken()`.
    func resolvedToken() async -> String? {
        do {
            return try await tokenProvider.bearerToken()
        } catch {
            return nil
        }
    }

    /// Sends `request`, logs it, maps any non-2xx status (or decoded error envelope) into
    /// `APIError.response`, and decodes the body with `decode` on success.
    func send<Item>(
        _ request: URLRequest,
        decoder: JSONDecoder,
        decode: (Data) throws -> Item
    ) async throws -> Item {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? "unknown"
        let startedAt = Date()

        do {
            let (data, response) = try await httpClient.send(request)
            let duration = Date().timeIntervalSince(startedAt)
            let statusCode = response.statusCode
            let isSuccess = (200..<300).contains(statusCode)
            let details = isSuccess ? nil : CatchRecordErrorEnvelope.decodeDetails(from: data, decoder: decoder)

            logger.log(NetworkLogEntry(
                method: method,
                path: path,
                statusCode: statusCode,
                durationSeconds: duration,
                errorCode: details?.code,
                traceId: details?.traceId
            ))

            guard isSuccess else {
                throw APIError.response(status: statusCode, details: details)
            }

            do {
                return try decode(data)
            } catch let decodingError as DecodingError {
                throw APIError.decoding(String(describing: decodingError))
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            let duration = Date().timeIntervalSince(startedAt)
            logger.log(NetworkLogEntry(method: method, path: path, statusCode: nil, durationSeconds: duration))
            throw Self.mapURLError(error)
        }
    }

    /// Convenience for a `204 No Content` route (e.g. abandon draft, remove favourite) — discards
    /// the (expected-empty) body and surfaces only success/failure.
    func sendExpectingNoContent(_ request: URLRequest, decoder: JSONDecoder) async throws {
        _ = try await send(request, decoder: decoder) { _ in () }
    }

    private static func mapURLError(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .offline
        case .timedOut:
            return .timedOut
        default:
            return .response(status: error.errorCode, details: nil)
        }
    }
}

// MARK: - Client-side precondition checks (ADR-0025 "Checks before sending")

/// Pure, shared validation for values the Catch Recording Service connector must check **before**
/// sending a request — nothing is sent over the network if one of these fails, so a bad call-site
/// value never reaches the service or wastes a request. Every failure throws
/// `APIError.invalidRequest`, which `isRetryable` reports as `false` (see `APIError.swift`).
nonisolated enum CatchRecordRequestValidation {
    /// `If-Match`/section-save/abandon/submit/edit-start all require a `version` of at least 1 —
    /// the service's own `version` field is documented as `minimum: 1`.
    static func validateVersion(_ version: Int) throws {
        guard version >= 1 else {
            throw APIError.invalidRequest(reason: "version must be at least 1, got \(version)")
        }
    }

    /// `limit` (listing/history) must be within the service's documented `1...100` bound.
    static func validateLimit(_ limit: Int?) throws {
        guard let limit else { return }
        guard (1...100).contains(limit) else {
            throw APIError.invalidRequest(reason: "limit must be between 1 and 100, got \(limit)")
        }
    }

    /// `submissionNumber` must be within the service's documented `1...1000` bound.
    static func validateSubmissionNumber(_ submissionNumber: Int) throws {
        guard (1...1000).contains(submissionNumber) else {
            throw APIError.invalidRequest(reason: "submissionNumber must be between 1 and 1000, got \(submissionNumber)")
        }
    }

    /// `Idempotency-Key`, when supplied, must be `1...256` characters — the service's own
    /// documented bound.
    static func validateIdempotencyKey(_ key: String?) throws {
        guard let key else { return }
        guard (1...256).contains(key.count) else {
            throw APIError.invalidRequest(reason: "Idempotency-Key must be 1 to 256 characters, got \(key.count)")
        }
    }

    /// `PUT` (complete replacement) is capped at 1 MiB by the service.
    static func validateReplacementPayloadSize(_ data: Data) throws {
        let oneMebibyte = 1024 * 1024
        guard data.count <= oneMebibyte else {
            throw APIError.invalidRequest(reason: "complete replacement payload exceeds 1 MiB (\(data.count) bytes)")
        }
    }
}
