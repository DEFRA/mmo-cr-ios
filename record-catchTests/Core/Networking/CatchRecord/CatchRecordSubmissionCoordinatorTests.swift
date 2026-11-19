//
//  CatchRecordSubmissionCoordinatorTests.swift
//  record-catchTests
//
//  Covers `CatchRecordSubmissionCoordinator` — the on-device submission queue/flush engine
//  (ADR-0028). Core business logic requires >=95% coverage (testing.instructions.md); error-
//  handling paths (permanent vs retryable failure) require 100%.
//

import XCTest
@testable import record_catch

@MainActor
final class CatchRecordSubmissionCoordinatorTests: XCTestCase {

    // MARK: - Fixtures

    private func makeDraft(vessel: String? = "ACHILLES") -> CatchRecordDraft {
        let draft = CatchRecordDraft()
        draft.vessel = vessel
        draft.departureDate = Date(timeIntervalSince1970: 1_700_000_000)
        draft.returnDate = Date(timeIntervalSince1970: 1_700_000_000)
        draft.departurePort = PortOption(name: "Plymouth")
        draft.returnPort = PortOption(name: "Plymouth")
        draft.gearCatches = [
            GearCatch(
                gear: GearOption(id: "seine-nets", name: "Seine nets"),
                statisticalArea: "27.7.e",
                speciesCaught: [SpeciesOption(id: "cod", name: "Atlantic cod (COD)", weights: .init(aboveMinimumKg: "250"))]
            )
        ]
        return draft
    }

    private func makeSaveResponse(status: PersistedCatchRecordStatus = .draft, version: Int = 1) -> StandardSaveResponseDTO {
        StandardSaveResponseDTO(
            id: "server-1", catchRecordReference: "A12345-11112026-100000", status: status,
            displayStatus: status == .submitted ? .submitted : .draft, version: version, savedSection: nil,
            sectionCompletion: SectionCompletionDTO(trip: true, pairFishing: true, gears: true),
            progress: CatchRecordProgressDTO(
                hasUnsubmittedChanges: false, numberOfSubmissions: 0,
                incompleteGearAssociationIds: [], currentIncompleteGearAssociationId: nil, allGearsComplete: true
            )
        )
    }

    private func makeSubmissionResponse(version: Int = 2) -> SubmissionResponseDTO {
        let json = Data("""
        {
          "id": "server-1", "catchRecordReference": "A12345-11112026-100000", "status": "SUBMITTED",
          "displayStatus": "Submitted", "version": \(version), "savedSection": null,
          "sectionCompletion": { "trip": true, "pairFishing": true, "gears": true },
          "progress": {
            "hasUnsubmittedChanges": false, "numberOfSubmissions": 1,
            "incompleteGearAssociationIds": [], "currentIncompleteGearAssociationId": null,
            "allGearsComplete": true
          },
          "submittedAt": "2026-11-11T10:00:00Z", "submittedBy": "user-1",
          "artifacts": []
        }
        """.utf8)
        // swiftlint:disable:next force_try
        return try! CatchRecordTransport.makeDecoder().decode(SubmissionResponseDTO.self, from: json)
    }

    /// Records every call made to it and lets each call site configure what `createDraft`/
    /// `replaceCatchRecord`/`submit` return or throw — the real `CatchRecordServicing` doubles
    /// (`StubCatchRecordService`/`FailingCatchRecordService`) can't vary their response per call,
    /// which `flushPending()`'s multi-record tests need.
    private final class SpyCatchRecordService: CatchRecordServicing, @unchecked Sendable {
        var createDraftResult: Result<StandardSaveResponseDTO, Error> = .success(StandardSaveResponseDTO(
            id: "server-1", catchRecordReference: "ref", status: .draft, displayStatus: .draft, version: 1,
            savedSection: nil, sectionCompletion: SectionCompletionDTO(trip: false, pairFishing: false, gears: false),
            progress: CatchRecordProgressDTO(hasUnsubmittedChanges: false, numberOfSubmissions: 0, incompleteGearAssociationIds: [], currentIncompleteGearAssociationId: nil, allGearsComplete: false)
        ))
        var replaceResult: Result<StandardSaveResponseDTO, Error>?
        var submitResult: Result<SubmissionResponseDTO, Error>?
        private(set) var createDraftCallCount = 0
        private(set) var replaceCallCount = 0
        private(set) var submitCallCount = 0
        private(set) var idempotencyKeysSeen: [String?] = []

        func listCatchRecords(limit _: Int? = nil, status _: PersistedCatchRecordStatus? = nil) async throws -> CatchRecordListResponseDTO {
            CatchRecordListResponseDTO(items: [], limit: 20, count: 0)
        }

        func createDraft(vesselId _: String, catchRecordReference _: String?, idempotencyKey: String?) async throws -> StandardSaveResponseDTO {
            createDraftCallCount += 1
            idempotencyKeysSeen.append(idempotencyKey)
            return try createDraftResult.get()
        }

        func retrieveCatchRecord(catchRecordId _: String) async throws -> RetrieveCatchRecordResponseDTO {
            throw APIError.invalidConfiguration
        }

        func replaceCatchRecord(catchRecordId _: String, expectedVersion _: Int, payload _: CompleteReplacementPayload) async throws -> StandardSaveResponseDTO {
            replaceCallCount += 1
            guard let replaceResult else { return try createDraftResult.get() }
            return try replaceResult.get()
        }

        func saveSection(catchRecordId _: String, expectedVersion _: Int, section _: SectionPatchPayload) async throws -> StandardSaveResponseDTO {
            try createDraftResult.get()
        }

        func abandonDraft(catchRecordId _: String, expectedVersion _: Int) async throws {}

        func history(catchRecordId _: String, limit _: Int? = nil) async throws -> CatchRecordHistoryResponseDTO {
            throw APIError.invalidConfiguration
        }

        func submit(catchRecordId _: String, expectedVersion _: Int, idempotencyKey: String?) async throws -> SubmissionResponseDTO {
            submitCallCount += 1
            idempotencyKeysSeen.append(idempotencyKey)
            guard let submitResult else { throw APIError.invalidConfiguration }
            return try submitResult.get()
        }

        func listSubmissions(catchRecordId _: String) async throws -> SubmissionsListResponseDTO {
            SubmissionsListResponseDTO(catchRecordId: "cr-1", count: 0, submissions: [])
        }

        func startEdit(catchRecordId _: String, expectedVersion _: Int, idempotencyKey _: String?) async throws -> StandardSaveResponseDTO {
            try createDraftResult.get()
        }
    }

    private func makeSUT(
        service: SpyCatchRecordService = SpyCatchRecordService(),
        draftStore: CatchRecordDraftStoring = InMemoryCatchRecordDraftStore(),
        isOnline: @escaping () -> Bool = { true }
    ) -> CatchRecordSubmissionCoordinator {
        CatchRecordSubmissionCoordinator(service: service, draftStore: draftStore, isOnline: isOnline)
    }

    // MARK: - Happy path

    func test_submitNow_whenOnlineAndBackendAccepts_returnsSubmitted_andMarksSucceeded() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let service = SpyCatchRecordService()
        service.createDraftResult = .success(makeSaveResponse())
        service.replaceResult = .success(makeSaveResponse(version: 1))
        service.submitResult = .success(makeSubmissionResponse(version: 2))
        let sut = makeSUT(service: service, draftStore: draftStore)
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .submitted)
        XCTAssertEqual(service.createDraftCallCount, 1)
        XCTAssertEqual(service.replaceCallCount, 1)
        XCTAssertEqual(service.submitCallCount, 1)
        let summaries = try await draftStore.allRecords()
        XCTAssertEqual(summaries.first?.displayStatus, .submitted)
    }

    func test_submitNow_reusesTheSameIdempotencyKey_forCreateDraftAndSubmit() async throws {
        let service = SpyCatchRecordService()
        service.createDraftResult = .success(makeSaveResponse())
        service.replaceResult = .success(makeSaveResponse(version: 1))
        service.submitResult = .success(makeSubmissionResponse())
        let sut = makeSUT(service: service)
        let draft = makeDraft()
        await sut.enqueue(draft)

        _ = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(service.idempotencyKeysSeen.count, 2)
        XCTAssertNotNil(service.idempotencyKeysSeen[0])
        XCTAssertEqual(service.idempotencyKeysSeen[0], service.idempotencyKeysSeen[1])
    }

    func test_submitNow_whenAlreadyHasAServerID_doesNotCreateASecondDraft() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let service = SpyCatchRecordService()
        service.createDraftResult = .success(makeSaveResponse())
        service.replaceResult = .success(makeSaveResponse(version: 1))
        service.submitResult = .success(makeSubmissionResponse())
        let sut = makeSUT(service: service, draftStore: draftStore)
        let draft = makeDraft()
        await sut.enqueue(draft)
        _ = await sut.submitNow(localID: draft.localID, timeout: 5) // first attempt creates the server record

        // A second "Accept and submit" (an amendment re-submission) must reuse the existing server
        // record rather than creating a duplicate.
        await sut.enqueue(draft)
        _ = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(service.createDraftCallCount, 1)
        XCTAssertEqual(service.replaceCallCount, 2)
        XCTAssertEqual(service.submitCallCount, 2)
        let summaries = try await draftStore.allRecords()
        XCTAssertEqual(summaries.first?.submissionCount, 2)
    }

    // MARK: - Offline

    func test_submitNow_whenOffline_returnsQueued_withoutCallingTheService() async throws {
        let service = SpyCatchRecordService()
        let sut = makeSUT(service: service, isOnline: { false })
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .queued)
        XCTAssertEqual(service.createDraftCallCount, 0)
    }

    // MARK: - Retryable failure stays queued (never surfaces as a permanent error)

    func test_submitNow_whenCreateDraftThrowsARetryableError_returnsQueued_andStaysQueued() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let service = SpyCatchRecordService()
        service.createDraftResult = .failure(APIError.offline)
        let sut = makeSUT(service: service, draftStore: draftStore)
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .queued)
        let pendingIDs = try await draftStore.pendingSubmissionLocalIDs()
        XCTAssertEqual(pendingIDs, [draft.localID])
    }

    // MARK: - Permanent failure reverts to Draft, never silently retried

    func test_submitNow_whenMappingFails_returnsFailedPermanently_andNoLongerQueued() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let sut = makeSUT(draftStore: draftStore)
        let draft = makeDraft(vessel: nil) // missing vessel -> CatchRecordMappingError.missingVessel
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .failedPermanently)
        let pendingIDs = try await draftStore.pendingSubmissionLocalIDs()
        XCTAssertTrue(pendingIDs.isEmpty)
    }

    func test_submitNow_whenServiceThrowsANonRetryableAPIError_returnsFailedPermanently() async throws {
        let service = SpyCatchRecordService()
        service.createDraftResult = .failure(APIError.invalidRequest(reason: "bad input"))
        let sut = makeSUT(service: service)
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .failedPermanently)
    }

    // MARK: - flushPending

    func test_flushPending_whenOffline_doesNothing() async throws {
        let service = SpyCatchRecordService()
        let sut = makeSUT(service: service, isOnline: { false })
        let draft = makeDraft()
        await sut.enqueue(draft)

        await sut.flushPending()

        XCTAssertEqual(service.createDraftCallCount, 0)
    }

    func test_flushPending_sendsEveryPendingRecord() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let service = SpyCatchRecordService()
        service.createDraftResult = .success(makeSaveResponse())
        service.replaceResult = .success(makeSaveResponse(version: 1))
        service.submitResult = .success(makeSubmissionResponse())
        let sut = makeSUT(service: service, draftStore: draftStore)
        let first = makeDraft()
        let second = makeDraft()
        await sut.enqueue(first)
        await sut.enqueue(second)

        await sut.flushPending()

        let pendingIDs = try await draftStore.pendingSubmissionLocalIDs()
        XCTAssertTrue(pendingIDs.isEmpty)
        XCTAssertEqual(service.submitCallCount, 2)
    }

    func test_flushPending_updatesLastFlushCompletedAt() async {
        let sut = makeSUT()
        XCTAssertEqual(sut.lastFlushCompletedAt, .distantPast)

        await sut.flushPending()

        XCTAssertGreaterThan(sut.lastFlushCompletedAt, .distantPast)
    }

    // MARK: - enqueue

    func test_enqueue_persistsTheDraft_asQueuedForSubmission() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let sut = makeSUT(draftStore: draftStore)
        let draft = makeDraft()

        await sut.enqueue(draft)

        let pendingIDs = try await draftStore.pendingSubmissionLocalIDs()
        XCTAssertEqual(pendingIDs, [draft.localID])
    }

    // MARK: - Error paths with no server-side correlate yet (defensive, never leave a record stuck)

    /// `loadDraft` returns `nil` for an id that was never enqueued/saved at all — a defensive path,
    /// since every real caller enqueues the draft (persisting it) before calling `submitNow`.
    func test_submitNow_whenNoLocalDraftExistsForTheID_returnsFailedPermanently() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let sut = makeSUT(draftStore: draftStore)

        let outcome = await sut.submitNow(localID: UUID(), timeout: 5)

        XCTAssertEqual(outcome, .failedPermanently)
    }

    /// `submissionProgress` returns `nil` whenever a draft was persisted via plain `save(_:)` rather
    /// than `enqueueForSubmission(_:)` (no idempotency key yet) — a defensive guard, since every real
    /// caller enqueues before attempting a submission.
    func test_submitNow_whenDraftWasNeverEnqueuedForSubmission_returnsFailedPermanently() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let sut = makeSUT(draftStore: draftStore)
        let draft = makeDraft()
        try await draftStore.save(draft) // persisted, but not enqueued — no idempotency key yet

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .failedPermanently)
    }

    // MARK: - Unexpected (non-`APIError`) submission failure still resolves definitively

    private struct UnexpectedError: Error {}

    func test_submitNow_whenServiceThrowsANonAPIError_returnsFailedPermanently() async throws {
        let service = SpyCatchRecordService()
        service.createDraftResult = .success(makeSaveResponse())
        service.replaceResult = .success(makeSaveResponse(version: 1))
        service.submitResult = .failure(UnexpectedError())
        let sut = makeSUT(service: service)
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .failedPermanently)
    }

    // MARK: - flushPending while already flushing (never drops a concurrently-requested flush)

    func test_flushPending_whenCalledWhileAlreadyFlushing_runsAgainOnceTheFirstRunCompletes() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let service = SpyCatchRecordService()
        service.createDraftResult = .success(makeSaveResponse())
        service.replaceResult = .success(makeSaveResponse(version: 1))
        service.submitResult = .success(makeSubmissionResponse())
        let sut = makeSUT(service: service, draftStore: draftStore)
        let first = makeDraft()
        await sut.enqueue(first)

        async let firstFlush: Void = sut.flushPending()
        // Requested while the first flush is still in-flight — must not be dropped on the floor.
        async let secondFlush: Void = sut.flushPending()
        _ = await (firstFlush, secondFlush)

        let pendingIDs = try await draftStore.pendingSubmissionLocalIDs()
        XCTAssertTrue(pendingIDs.isEmpty)
    }
}

// MARK: - CatchRecordSubmissionQueuing doubles

/// Covers the always-queue (`StubCatchRecordSubmissionQueue`) and always-succeed
/// (`AlwaysSucceedingCatchRecordSubmissionQueue`) test/preview doubles — the safe fallbacks used
/// wherever no real `CatchRecordSubmissionCoordinator` has been injected (see their doc comments).
@MainActor
final class CatchRecordSubmissionQueueDoublesTests: XCTestCase {

    private func makeDraft() -> CatchRecordDraft {
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        return draft
    }

    // MARK: - StubCatchRecordSubmissionQueue

    func test_stubQueue_enqueue_persistsTheDraftAsQueued() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let sut = StubCatchRecordSubmissionQueue(draftStore: draftStore)
        let draft = makeDraft()

        await sut.enqueue(draft)

        let pendingIDs = try await draftStore.pendingSubmissionLocalIDs()
        XCTAssertEqual(pendingIDs, [draft.localID])
    }

    func test_stubQueue_submitNow_alwaysReturnsQueued_withoutMutatingState() async throws {
        let sut = StubCatchRecordSubmissionQueue()
        let outcome = await sut.submitNow(localID: UUID(), timeout: 5)
        XCTAssertEqual(outcome, .queued)
    }

    func test_stubQueue_flushPending_isANoOp() async {
        let sut = StubCatchRecordSubmissionQueue()
        await sut.flushPending() // should not throw or hang
    }

    // MARK: - AlwaysSucceedingCatchRecordSubmissionQueue

    func test_alwaysSucceedingQueue_enqueue_persistsTheDraftAsQueued() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let sut = AlwaysSucceedingCatchRecordSubmissionQueue(draftStore: draftStore)
        let draft = makeDraft()

        await sut.enqueue(draft)

        let pendingIDs = try await draftStore.pendingSubmissionLocalIDs()
        XCTAssertEqual(pendingIDs, [draft.localID])
    }

    func test_alwaysSucceedingQueue_submitNow_returnsSubmitted_andMarksTheDraftSucceeded() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let sut = AlwaysSucceedingCatchRecordSubmissionQueue(draftStore: draftStore)
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .submitted)
        let records = try await draftStore.allRecords()
        XCTAssertEqual(records.first?.displayStatus, .submitted)
    }

    func test_alwaysSucceedingQueue_flushPending_isANoOp() async {
        let sut = AlwaysSucceedingCatchRecordSubmissionQueue()
        await sut.flushPending() // should not throw or hang
    }
}
