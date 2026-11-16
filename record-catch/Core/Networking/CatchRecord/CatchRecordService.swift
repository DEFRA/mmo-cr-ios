//
//  CatchRecordService.swift
//  record-catch
//
//  The Catch Recording Service's catch-record lifecycle connector (ADR-0025) — mirrors
//  `ReferenceDataClient.swift`'s architecture (ADR-0018): `CatchRecordService` is the production
//  implementation, composed from `HTTPPerforming` + `APIConfiguration` + `AuthTokenProviding` via
//  the shared `CatchRecordTransport`, so it is unit-testable with an in-memory `StubHTTPClient` and
//  needs no live network in the test suite (testing.instructions.md). `StubCatchRecordService` is a
//  fixture-backed double for future call sites/tests; `FailingCatchRecordService` is used whenever
//  the Catch Recording Service's base URL is not yet configured (see
//  `CatchRecordServicesFactory`/ADR-0025).
//
//  **Not yet wired to anything.** No screen, view model, or the local draft store calls this
//  connector yet — see ADR-0025 for the connector-only scope of this change.
//

import Foundation

/// The 10 in-scope catch-record lifecycle operations (ADR-0025) — list, create, retrieve, replace,
/// save-a-section, abandon, history, submit, list-submissions, edit-start. Every method that takes
/// an `expectedVersion`/`limit`/`idempotencyKey` validates it client-side first (via
/// `CatchRecordRequestValidation`) and throws `APIError.invalidRequest` — never sending a request —
/// if the value is out of bounds.
nonisolated protocol CatchRecordServicing: Sendable {
    func listCatchRecords(limit: Int?, status: PersistedCatchRecordStatus?) async throws -> CatchRecordListResponseDTO
    func createDraft(vesselId: String, catchRecordReference: String?, idempotencyKey: String?) async throws -> StandardSaveResponseDTO
    func retrieveCatchRecord(catchRecordId: String) async throws -> RetrieveCatchRecordResponseDTO
    func replaceCatchRecord(catchRecordId: String, expectedVersion: Int, payload: CompleteReplacementPayload) async throws -> StandardSaveResponseDTO
    func saveSection(catchRecordId: String, expectedVersion: Int, section: SectionPatchPayload) async throws -> StandardSaveResponseDTO
    func abandonDraft(catchRecordId: String, expectedVersion: Int) async throws
    func history(catchRecordId: String, limit: Int?) async throws -> CatchRecordHistoryResponseDTO
    func submit(catchRecordId: String, expectedVersion: Int, idempotencyKey: String?) async throws -> SubmissionResponseDTO
    func listSubmissions(catchRecordId: String) async throws -> SubmissionsListResponseDTO
    func startEdit(catchRecordId: String, expectedVersion: Int, idempotencyKey: String?) async throws -> StandardSaveResponseDTO
}

/// Production implementation. See the file-level doc comment for how closely this mirrors
/// `RemoteReferenceDataClient`.
nonisolated struct CatchRecordService: CatchRecordServicing {
    private let transport: CatchRecordTransport
    private let configuration: APIConfiguration
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        httpClient: HTTPPerforming,
        configuration: APIConfiguration,
        tokenProvider: AuthTokenProviding,
        logger: NetworkLogger = NetworkLogger()
    ) {
        self.transport = CatchRecordTransport(httpClient: httpClient, tokenProvider: tokenProvider, logger: logger)
        self.configuration = configuration
        self.decoder = CatchRecordTransport.makeDecoder()
        self.encoder = CatchRecordTransport.makeEncoder()
    }

    func listCatchRecords(limit: Int? = nil, status: PersistedCatchRecordStatus? = nil) async throws -> CatchRecordListResponseDTO {
        try CatchRecordRequestValidation.validateLimit(limit)
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(
            route: .listCatchRecords(limit: limit, status: status),
            baseURL: configuration.baseURL,
            bearerToken: token
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(CatchRecordListResponseDTO.self, from: $0) }
    }

    func createDraft(vesselId: String, catchRecordReference: String? = nil, idempotencyKey: String? = nil) async throws -> StandardSaveResponseDTO {
        try CatchRecordRequestValidation.validateIdempotencyKey(idempotencyKey)
        let token = await transport.resolvedToken()
        let payload = CreateDraftCatchRecordPayload(vesselId: vesselId, catchRecordReference: catchRecordReference)
        let request = try makeCatchRecordRequest(
            route: .createDraft,
            baseURL: configuration.baseURL,
            body: payload,
            bearerToken: token,
            metadata: CatchRecordRequestMetadata(idempotencyKey: idempotencyKey),
            encoder: encoder
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(StandardSaveResponseDTO.self, from: $0) }
    }

    func retrieveCatchRecord(catchRecordId: String) async throws -> RetrieveCatchRecordResponseDTO {
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(
            route: .retrieveCatchRecord(catchRecordId: catchRecordId),
            baseURL: configuration.baseURL,
            bearerToken: token
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(RetrieveCatchRecordResponseDTO.self, from: $0) }
    }

    func replaceCatchRecord(catchRecordId: String, expectedVersion: Int, payload: CompleteReplacementPayload) async throws -> StandardSaveResponseDTO {
        try CatchRecordRequestValidation.validateVersion(expectedVersion)
        let body = try encoder.encode(payload)
        try CatchRecordRequestValidation.validateReplacementPayloadSize(body)
        let token = await transport.resolvedToken()
        let request = try makeCatchRecordRequest(
            route: .replaceCatchRecord(catchRecordId: catchRecordId),
            baseURL: configuration.baseURL,
            body: payload,
            bearerToken: token,
            metadata: CatchRecordRequestMetadata(ifMatch: String(expectedVersion)),
            encoder: encoder
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(StandardSaveResponseDTO.self, from: $0) }
    }

    func saveSection(catchRecordId: String, expectedVersion: Int, section: SectionPatchPayload) async throws -> StandardSaveResponseDTO {
        try CatchRecordRequestValidation.validateVersion(expectedVersion)
        let token = await transport.resolvedToken()
        let request = try makeCatchRecordRequest(
            route: .saveCatchRecordSection(catchRecordId: catchRecordId),
            baseURL: configuration.baseURL,
            body: section,
            bearerToken: token,
            metadata: CatchRecordRequestMetadata(ifMatch: String(expectedVersion)),
            encoder: encoder
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(StandardSaveResponseDTO.self, from: $0) }
    }

    func abandonDraft(catchRecordId: String, expectedVersion: Int) async throws {
        try CatchRecordRequestValidation.validateVersion(expectedVersion)
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(
            route: .abandonDraft(catchRecordId: catchRecordId),
            baseURL: configuration.baseURL,
            bearerToken: token,
            ifMatch: String(expectedVersion)
        )
        try await transport.sendExpectingNoContent(request, decoder: decoder)
    }

    func history(catchRecordId: String, limit: Int? = nil) async throws -> CatchRecordHistoryResponseDTO {
        try CatchRecordRequestValidation.validateLimit(limit)
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(
            route: .history(catchRecordId: catchRecordId, limit: limit),
            baseURL: configuration.baseURL,
            bearerToken: token
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(CatchRecordHistoryResponseDTO.self, from: $0) }
    }

    func submit(catchRecordId: String, expectedVersion: Int, idempotencyKey: String? = nil) async throws -> SubmissionResponseDTO {
        try CatchRecordRequestValidation.validateVersion(expectedVersion)
        try CatchRecordRequestValidation.validateIdempotencyKey(idempotencyKey)
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(
            route: .submit(catchRecordId: catchRecordId),
            baseURL: configuration.baseURL,
            bearerToken: token,
            ifMatch: String(expectedVersion),
            idempotencyKey: idempotencyKey
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(SubmissionResponseDTO.self, from: $0) }
    }

    func listSubmissions(catchRecordId: String) async throws -> SubmissionsListResponseDTO {
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(
            route: .listSubmissions(catchRecordId: catchRecordId),
            baseURL: configuration.baseURL,
            bearerToken: token
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(SubmissionsListResponseDTO.self, from: $0) }
    }

    func startEdit(catchRecordId: String, expectedVersion: Int, idempotencyKey: String? = nil) async throws -> StandardSaveResponseDTO {
        try CatchRecordRequestValidation.validateVersion(expectedVersion)
        try CatchRecordRequestValidation.validateIdempotencyKey(idempotencyKey)
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(
            route: .startEdit(catchRecordId: catchRecordId),
            baseURL: configuration.baseURL,
            bearerToken: token,
            ifMatch: String(expectedVersion),
            idempotencyKey: idempotencyKey
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(StandardSaveResponseDTO.self, from: $0) }
    }
}

/// Fixture-backed double for future call sites/tests, following the same "real + stub pair"
/// pattern as `StubReferenceDataClient`.
nonisolated struct StubCatchRecordService: CatchRecordServicing {
    var listResponse: CatchRecordListResponseDTO?
    var saveResponse: StandardSaveResponseDTO?
    var retrieveResponse: RetrieveCatchRecordResponseDTO?
    var historyResponse: CatchRecordHistoryResponseDTO?
    var submissionResponse: SubmissionResponseDTO?
    var submissionsListResponse: SubmissionsListResponseDTO?
    var error: APIError?

    func listCatchRecords(limit _: Int? = nil, status _: PersistedCatchRecordStatus? = nil) async throws -> CatchRecordListResponseDTO {
        if let error { throw error }
        if let listResponse { return listResponse }
        throw APIError.response(status: 503, details: nil)
    }

    func createDraft(vesselId _: String, catchRecordReference _: String? = nil, idempotencyKey _: String? = nil) async throws -> StandardSaveResponseDTO {
        if let error { throw error }
        if let saveResponse { return saveResponse }
        throw APIError.response(status: 503, details: nil)
    }

    func retrieveCatchRecord(catchRecordId _: String) async throws -> RetrieveCatchRecordResponseDTO {
        if let error { throw error }
        if let retrieveResponse { return retrieveResponse }
        throw APIError.response(status: 404, details: nil)
    }

    func replaceCatchRecord(catchRecordId _: String, expectedVersion _: Int, payload _: CompleteReplacementPayload) async throws -> StandardSaveResponseDTO {
        if let error { throw error }
        if let saveResponse { return saveResponse }
        throw APIError.response(status: 503, details: nil)
    }

    func saveSection(catchRecordId _: String, expectedVersion _: Int, section _: SectionPatchPayload) async throws -> StandardSaveResponseDTO {
        if let error { throw error }
        if let saveResponse { return saveResponse }
        throw APIError.response(status: 503, details: nil)
    }

    func abandonDraft(catchRecordId _: String, expectedVersion _: Int) async throws {
        if let error { throw error }
    }

    func history(catchRecordId _: String, limit _: Int? = nil) async throws -> CatchRecordHistoryResponseDTO {
        if let error { throw error }
        if let historyResponse { return historyResponse }
        throw APIError.response(status: 404, details: nil)
    }

    func submit(catchRecordId _: String, expectedVersion _: Int, idempotencyKey _: String? = nil) async throws -> SubmissionResponseDTO {
        if let error { throw error }
        if let submissionResponse { return submissionResponse }
        throw APIError.response(status: 503, details: nil)
    }

    func listSubmissions(catchRecordId _: String) async throws -> SubmissionsListResponseDTO {
        if let error { throw error }
        if let submissionsListResponse { return submissionsListResponse }
        throw APIError.response(status: 404, details: nil)
    }

    func startEdit(catchRecordId _: String, expectedVersion _: Int, idempotencyKey _: String? = nil) async throws -> StandardSaveResponseDTO {
        if let error { throw error }
        if let saveResponse { return saveResponse }
        throw APIError.response(status: 503, details: nil)
    }
}

/// Used whenever the Catch Recording Service's base URL is not yet configured for this stage (see
/// `CatchRecordServicesFactory`/ADR-0025) — every method throws `APIError.invalidConfiguration`
/// rather than crashing or guessing a wrong address.
nonisolated struct FailingCatchRecordService: CatchRecordServicing {
    func listCatchRecords(limit _: Int? = nil, status _: PersistedCatchRecordStatus? = nil) async throws -> CatchRecordListResponseDTO {
        throw APIError.invalidConfiguration
    }

    func createDraft(vesselId _: String, catchRecordReference _: String? = nil, idempotencyKey _: String? = nil) async throws -> StandardSaveResponseDTO {
        throw APIError.invalidConfiguration
    }

    func retrieveCatchRecord(catchRecordId _: String) async throws -> RetrieveCatchRecordResponseDTO {
        throw APIError.invalidConfiguration
    }

    func replaceCatchRecord(catchRecordId _: String, expectedVersion _: Int, payload _: CompleteReplacementPayload) async throws -> StandardSaveResponseDTO {
        throw APIError.invalidConfiguration
    }

    func saveSection(catchRecordId _: String, expectedVersion _: Int, section _: SectionPatchPayload) async throws -> StandardSaveResponseDTO {
        throw APIError.invalidConfiguration
    }

    func abandonDraft(catchRecordId _: String, expectedVersion _: Int) async throws {
        throw APIError.invalidConfiguration
    }

    func history(catchRecordId _: String, limit _: Int? = nil) async throws -> CatchRecordHistoryResponseDTO {
        throw APIError.invalidConfiguration
    }

    func submit(catchRecordId _: String, expectedVersion _: Int, idempotencyKey _: String? = nil) async throws -> SubmissionResponseDTO {
        throw APIError.invalidConfiguration
    }

    func listSubmissions(catchRecordId _: String) async throws -> SubmissionsListResponseDTO {
        throw APIError.invalidConfiguration
    }

    func startEdit(catchRecordId _: String, expectedVersion _: Int, idempotencyKey _: String? = nil) async throws -> StandardSaveResponseDTO {
        throw APIError.invalidConfiguration
    }
}
