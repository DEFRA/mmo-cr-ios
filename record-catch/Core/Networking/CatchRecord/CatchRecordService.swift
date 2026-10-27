//
//  CatchRecordService.swift
//  record-catch
//
//  The catch-record submission API connector — mirrors ReferenceDataClient.swift's architecture
//  (ADR-0018) ahead of the real backend contract (see CatchRecordEndpoint.swift's placeholder-route
//  warning). `CatchRecordService` is the production implementation, composed from `HTTPPerforming`
//  + `APIConfiguration` + `AuthTokenProviding` exactly like `RemoteReferenceDataClient`, so it is
//  unit-testable with an in-memory `StubHTTPClient` and needs no live network in the test suite
//  (testing.instructions.md). `StubCatchRecordService` is a fixture-backed double for call
//  sites/tests, following the same "real + stub pair" pattern as `StubReferenceDataClient`.
//
//  Only one route exists so far — submitting a completed catch report — since the real contract
//  (additional routes, exact request/response shapes, auth requirements) is not yet confirmed by
//  the backend team.
//
//  **Not yet wired to anything.** This is the connector only, matching the scope ADR-0018 set for
//  `ReferenceDataClient`: it is not plugged into `CatchRecordSubmissionServicing`/
//  `CheckYourAnswersViewModel` (Features/Common/Data/CatchRecordSubmissionService.swift),
//  which still use `StubCatchRecordSubmissionService`'s fixed-delay stub. Wiring this connector in
//  as that protocol's real implementation is future work once the backend contract is confirmed.
//

import Foundation

/// Submits a completed catch report to the (not-yet-built) MMO catch-record API. See the
/// file-level doc comment above for scope.
nonisolated protocol CatchRecordServicing: Sendable {
    /// Submits `report` to the catch-record submission route and decodes the server's
    /// acknowledgement. Mirrors `ReferenceDataFetching`'s error mapping: throws `APIError` on any
    /// non-2xx response, transport failure, or decode failure.
    func submitCatchReport(_ report: CatchRecordSubmissionRequestDTO) async throws -> CatchRecordSubmissionResponseDTO
}

/// Production implementation. See the file-level doc comment above for how closely this mirrors
/// `RemoteReferenceDataClient`.
nonisolated struct CatchRecordService: CatchRecordServicing {
    private let httpClient: HTTPPerforming
    private let configuration: APIConfiguration
    private let tokenProvider: AuthTokenProviding
    private let logger: NetworkLogger
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        httpClient: HTTPPerforming,
        configuration: APIConfiguration,
        tokenProvider: AuthTokenProviding,
        logger: NetworkLogger = NetworkLogger()
    ) {
        self.httpClient = httpClient
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        self.logger = logger
        self.decoder = JSONDecoder()
        // Explicit ISO8601 dates: unlike the on-device draft store (which accepts `Date`'s default
        // Codable encoding — seconds since the 2001 reference date — for local persistence), a real
        // wire API must never inherit that default, so it's set deliberately here.
        let requestEncoder = JSONEncoder()
        requestEncoder.dateEncodingStrategy = .iso8601
        self.encoder = requestEncoder
    }

    func submitCatchReport(_ report: CatchRecordSubmissionRequestDTO) async throws -> CatchRecordSubmissionResponseDTO {
        let token = await resolvedToken()
        let request = try makeSubmitCatchRecordRequest(
            baseURL: configuration.baseURL,
            body: report,
            bearerToken: token,
            encoder: encoder
        )
        return try await send(request) { data in
            try self.decoder.decode(CatchRecordSubmissionResponseDTO.self, from: data)
        }
    }

    /// Resolves the bearer token, proceeding with `nil` (i.e. no `Authorization` header) if the
    /// provider throws — matches `RemoteReferenceDataClient.resolvedToken()`.
    private func resolvedToken() async -> String? {
        do {
            return try await tokenProvider.bearerToken()
        } catch {
            return nil
        }
    }

    /// Sends `request`, logs it, maps any non-2xx status (or decoded error envelope) into
    /// `APIError.response`, and decodes the body with `decode` on success — mirrors
    /// `RemoteReferenceDataClient.send(_:fallbackPath:decode:)`.
    private func send<Item>(
        _ request: URLRequest,
        decode: (Data) throws -> Item
    ) async throws -> Item {
        let path = request.url?.path ?? "catch-records"
        let startedAt = Date()

        do {
            let (data, response) = try await httpClient.send(request)
            let duration = Date().timeIntervalSince(startedAt)
            let statusCode = response.statusCode
            let isSuccess = (200..<300).contains(statusCode)
            let details = isSuccess ? nil : Self.decodeErrorDetails(from: data, decoder: decoder)

            logger.log(NetworkLogEntry(
                method: "POST",
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
            logger.log(NetworkLogEntry(method: "POST", path: path, statusCode: nil, durationSeconds: duration))
            throw Self.mapURLError(error)
        }
    }

    /// Best-effort decode of the API's standard error envelope (`{ "error": { ... } }`) from a
    /// non-2xx response body — matches `RemoteReferenceDataClient.decodeErrorDetails`.
    private static func decodeErrorDetails(from data: Data, decoder: JSONDecoder) -> APIErrorDetails? {
        guard !data.isEmpty else { return nil }
        struct ErrorEnvelope: Decodable {
            let error: APIErrorDetails
        }
        return try? decoder.decode(ErrorEnvelope.self, from: data).error
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

/// Fixture-backed double for future call sites/tests, following the same "real + stub pair"
/// pattern as `StubReferenceDataClient`.
nonisolated struct StubCatchRecordService: CatchRecordServicing {
    var response: CatchRecordSubmissionResponseDTO?
    var error: APIError?

    func submitCatchReport(_ : CatchRecordSubmissionRequestDTO) async throws -> CatchRecordSubmissionResponseDTO {
        if let error { throw error }
        if let response { return response }
        throw APIError.response(status: 503, details: nil)
    }
}
