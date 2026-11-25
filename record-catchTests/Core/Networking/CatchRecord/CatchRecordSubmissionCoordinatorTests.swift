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

    /// Mirrors what `SelectVesselViewModel.submit()` always captures in production: a resolved
    /// `VesselOption` alongside the display-name string (see ADR-0028). Tests exercising a draft
    /// persisted *before* `vesselSnapshot` existed construct the draft directly instead (see
    /// `test_submitNow_whenVesselHasOnlyAName_resolvesItViaTheVesselProvider`).
    private func makeDraft(vessel: String? = "ACHILLES") -> CatchRecordDraft {
        let draft = CatchRecordDraft()
        draft.vessel = vessel
        draft.vesselSnapshot = vessel.map { VesselOption(id: "v-achilles", name: $0, registrationNumber: "A12345") }
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

    private func makeRetrieveResponse(status: PersistedCatchRecordStatus, version: Int) -> RetrieveCatchRecordResponseDTO {
        let json = Data("""
        {
          "schemaVersion": 1, "id": "server-1", "catchRecordReference": "A12345-11112026-100000",
          "ownerUserId": "user-1", "status": "\(status.rawValue)", "version": \(version),
          "numberOfSubmissions": 0, "hasUnsubmittedChanges": false,
          "vessel": { "id": "A12345", "rssSnapshot": "A12345", "nameSnapshot": "ACHILLES", "externalMarkSnapshot": "A12345", "lengthOverallMetresSnapshot": null },
          "trip": { "startedAndFinishedToday": false, "dateStarted": "2026-11-11", "dateEnded": "2026-11-11",
            "departurePort": { "id": "p1", "codeSnapshot": "PLY", "nameSnapshot": "Plymouth" },
            "returnPort": { "id": "p1", "codeSnapshot": "PLY", "nameSnapshot": "Plymouth" } },
          "pairFishing": { "enabled": false, "pairVessel": null, "pairSkipperName": null },
          "gears": [], "speciesNotLanded": [], "artifacts": [],
          "createdAt": "2026-11-11T10:00:00Z", "createdBy": "user-1",
          "updatedAt": "2026-11-11T10:00:00Z", "updatedBy": "user-1",
          "submittedAt": null, "submittedBy": null, "completedAt": null, "completedBy": null,
          "displayStatus": "Draft", "sectionCompletion": { "trip": true, "pairFishing": true, "gears": true },
          "completedSections": [], "incompleteSections": [],
          "progress": { "hasUnsubmittedChanges": false, "numberOfSubmissions": 0, "incompleteGearAssociationIds": [], "currentIncompleteGearAssociationId": null, "allGearsComplete": true },
          "submissionEligible": true
        }
        """.utf8)
        // swiftlint:disable:next force_try
        return try! CatchRecordTransport.makeDecoder().decode(RetrieveCatchRecordResponseDTO.self, from: json)
    }

    /// Records every call made to it and lets each call site configure what `createDraft`/
    /// `replaceCatchRecord`/`submit`/`retrieveCatchRecord` return or throw — the real
    /// `CatchRecordServicing` doubles (`StubCatchRecordService`/`FailingCatchRecordService`) can't
    /// vary their response per call, which `flushPending()`'s multi-record tests and the
    /// conflict-retry tests both need.
    private final class SpyCatchRecordService: CatchRecordServicing, @unchecked Sendable {
        var createDraftResult: Result<StandardSaveResponseDTO, Error> = .success(StandardSaveResponseDTO(
            id: "server-1", catchRecordReference: "ref", status: .draft, displayStatus: .draft, version: 1,
            savedSection: nil, sectionCompletion: SectionCompletionDTO(trip: false, pairFishing: false, gears: false),
            progress: CatchRecordProgressDTO(hasUnsubmittedChanges: false, numberOfSubmissions: 0, incompleteGearAssociationIds: [], currentIncompleteGearAssociationId: nil, allGearsComplete: false)
        ))
        var replaceResult: Result<StandardSaveResponseDTO, Error>?
        /// Consumed in order by `submit`, one entry per call; falls back to `submitResult` once
        /// exhausted — lets a conflict-retry test make the *first* `submit` throw `409` and the
        /// *second* (retried) call succeed.
        var submitResults: [Result<SubmissionResponseDTO, Error>] = []
        var submitResult: Result<SubmissionResponseDTO, Error>?
        var retrieveResult: Result<RetrieveCatchRecordResponseDTO, Error>?
        private(set) var createDraftCallCount = 0
        private(set) var replaceCallCount = 0
        private(set) var submitCallCount = 0
        private(set) var retrieveCallCount = 0
        private(set) var idempotencyKeysSeen: [String?] = []
        /// The `expectedVersion` each `submit` call was made with, in call order — used to assert
        /// the queue reuses `replaceCatchRecord`'s own returned version, never a stale one.
        private(set) var submitExpectedVersionsSeen: [Int] = []
        private(set) var replaceExpectedVersionsSeen: [Int] = []

        func listCatchRecords(limit _: Int? = nil, status _: PersistedCatchRecordStatus? = nil) async throws -> CatchRecordListResponseDTO {
            CatchRecordListResponseDTO(items: [], limit: 20, count: 0)
        }

        func createDraft(vesselId _: String, catchRecordReference _: String?, idempotencyKey: String?) async throws -> StandardSaveResponseDTO {
            createDraftCallCount += 1
            idempotencyKeysSeen.append(idempotencyKey)
            return try createDraftResult.get()
        }

        func retrieveCatchRecord(catchRecordId _: String) async throws -> RetrieveCatchRecordResponseDTO {
            retrieveCallCount += 1
            guard let retrieveResult else { throw APIError.invalidConfiguration }
            return try retrieveResult.get()
        }

        func replaceCatchRecord(catchRecordId _: String, expectedVersion: Int, payload _: CompleteReplacementPayload) async throws -> StandardSaveResponseDTO {
            replaceCallCount += 1
            replaceExpectedVersionsSeen.append(expectedVersion)
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

        func submit(catchRecordId _: String, expectedVersion: Int, idempotencyKey: String?) async throws -> SubmissionResponseDTO {
            submitCallCount += 1
            idempotencyKeysSeen.append(idempotencyKey)
            submitExpectedVersionsSeen.append(expectedVersion)
            if !submitResults.isEmpty {
                return try submitResults.removeFirst().get()
            }
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
        CatchRecordSubmissionCoordinator(service: service, draftStore: draftStore, vesselProvider: StubVesselProvider(), isOnline: isOnline)
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

    /// Regression test: `submit` must always carry the version `replaceCatchRecord` itself just
    /// returned (the service bumps the version on every successful write), never the version the
    /// queue happened to already hold before the replace — otherwise a backend that bumps the
    /// version on replace would make every submit a guaranteed `409` (ADR-0028 "Version handling").
    func test_submitNow_usesTheVersionReplaceCatchRecordReturns_forSubmit_notAStaleOne() async throws {
        let service = SpyCatchRecordService()
        service.createDraftResult = .success(makeSaveResponse(version: 1))
        service.replaceResult = .success(makeSaveResponse(version: 7)) // the service bumped it on replace
        service.submitResult = .success(makeSubmissionResponse(version: 8))
        let sut = makeSUT(service: service)
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .submitted)
        XCTAssertEqual(service.replaceExpectedVersionsSeen, [1])
        XCTAssertEqual(service.submitExpectedVersionsSeen, [7], "submit must use replace's returned version, not createDraft's")
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

    // MARK: - Vessel resolution (ADR-0024/ADR-0028 — real, API-sourced vessels)

    /// A draft persisted before `CatchRecordDraft.vesselSnapshot` existed only has a vessel
    /// **name** — the queue must resolve it via `vesselProvider` rather than failing the mapping.
    func test_submitNow_whenVesselHasOnlyAName_resolvesItViaTheVesselProvider() async throws {
        let service = SpyCatchRecordService()
        service.createDraftResult = .success(makeSaveResponse())
        service.replaceResult = .success(makeSaveResponse(version: 1))
        service.submitResult = .success(makeSubmissionResponse())
        let provider = StubVesselProvider(vessels: [VesselOption(id: "v-1", name: "ACHILLES", registrationNumber: "A12345")])
        let sut = CatchRecordSubmissionCoordinator(service: service, draftStore: InMemoryCatchRecordDraftStore(), vesselProvider: provider, isOnline: { true })
        let draft = makeDraft()
        draft.vesselSnapshot = nil // simulate a pre-ADR-0028 draft: name only
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .submitted)
    }

    func test_submitNow_whenVesselCannotBeResolvedAtAll_failsPermanently() async throws {
        let sut = CatchRecordSubmissionCoordinator(
            service: SpyCatchRecordService(), draftStore: InMemoryCatchRecordDraftStore(),
            vesselProvider: StubVesselProvider(vessels: []), isOnline: { true }
        )
        let draft = makeDraft()
        draft.vesselSnapshot = nil
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .failedPermanently)
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

    /// Regression test for the bug where submitting always showed "Could not submit your catch
    /// record. Check your connection and try again" regardless of actual connectivity: whenever
    /// `CATCH_RECORD_API_BASE_URL` is not yet configured for a stage/build,
    /// `CatchRecordServicesFactory` substitutes `FailingCatchRecordService`, which throws
    /// `APIError.invalidConfiguration` from every call — a deployment/environment problem the user
    /// cannot fix, and nothing to do with their device's connectivity. This must be queued and
    /// retried automatically (`submissionSaved`, never the inline error), exactly like a genuinely
    /// offline device — never `.failedPermanently`.
    func test_submitNow_whenServiceIsNotConfigured_returnsQueued_neverFailedPermanently() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let service = SpyCatchRecordService()
        service.createDraftResult = .failure(APIError.invalidConfiguration)
        let sut = makeSUT(service: service, draftStore: draftStore, isOnline: { true })
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .queued)
        let pendingIDs = try await draftStore.pendingSubmissionLocalIDs()
        XCTAssertEqual(pendingIDs, [draft.localID])
    }

    /// `401 Unauthorized` (an expired/not-yet-ready sign-in session) is nothing the user can fix
    /// from this screen, so it must behave like "genuinely offline" — queued and retried once the
    /// app's normal session refresh restores a valid token — never reverted to Draft.
    func test_submitNow_whenServiceThrowsUnauthorized_returnsQueued_neverFailedPermanently() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let service = SpyCatchRecordService()
        service.createDraftResult = .failure(APIError.response(status: 401, details: nil))
        let sut = makeSUT(service: service, draftStore: draftStore)
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .queued)
        let pendingIDs = try await draftStore.pendingSubmissionLocalIDs()
        XCTAssertEqual(pendingIDs, [draft.localID])
    }

    // MARK: - Conflict (409) handling (ADR-0028 "Conflict handling")

    /// A `409` on `submit` is resolved by retrieving the record's current version and retrying
    /// once — succeeding when the retried `submit` is accepted.
    func test_submitNow_whenSubmitConflicts_retrievesCurrentVersion_andRetriesOnce() async throws {
        let service = SpyCatchRecordService()
        service.createDraftResult = .success(makeSaveResponse(version: 1))
        service.replaceResult = .success(makeSaveResponse(version: 2))
        service.submitResults = [
            .failure(APIError.response(status: 409, details: nil)),
            .success(makeSubmissionResponse(version: 4))
        ]
        service.retrieveResult = .success(makeRetrieveResponse(status: .draft, version: 3))
        let sut = makeSUT(service: service)
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .submitted)
        XCTAssertEqual(service.retrieveCallCount, 1)
        XCTAssertEqual(service.submitExpectedVersionsSeen, [2, 3], "the retry must use the freshly-retrieved version")
    }

    /// A `409` on `submit`, where the retrieved record already shows `SUBMITTED` (this device's
    /// *own* earlier response was lost in transit, not a genuine conflict with another session),
    /// resolves to `.submitted` without sending a second submit request.
    func test_submitNow_whenSubmitConflicts_andRecordIsAlreadySubmitted_resolvesAsSubmitted_withoutRetrying() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let service = SpyCatchRecordService()
        service.createDraftResult = .success(makeSaveResponse(version: 1))
        service.replaceResult = .success(makeSaveResponse(version: 2))
        service.submitResults = [.failure(APIError.response(status: 409, details: nil))]
        service.retrieveResult = .success(makeRetrieveResponse(status: .submitted, version: 3))
        let sut = makeSUT(service: service, draftStore: draftStore)
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .submitted)
        XCTAssertEqual(service.submitCallCount, 1, "no second submit once the backend already shows it as submitted")
        let summaries = try await draftStore.allRecords()
        XCTAssertEqual(summaries.first?.displayStatus, .submitted)
    }

    /// A conflict that persists past the single retry fails permanently (back to Draft), rather
    /// than looping forever.
    func test_submitNow_whenConflictPersistsPastTheRetry_failsPermanently() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let service = SpyCatchRecordService()
        service.createDraftResult = .success(makeSaveResponse(version: 1))
        service.replaceResult = .success(makeSaveResponse(version: 2))
        service.submitResults = [
            .failure(APIError.response(status: 409, details: nil)),
            .failure(APIError.response(status: 409, details: nil))
        ]
        service.retrieveResult = .success(makeRetrieveResponse(status: .draft, version: 3))
        let sut = makeSUT(service: service, draftStore: draftStore)
        let draft = makeDraft()
        await sut.enqueue(draft)

        let outcome = await sut.submitNow(localID: draft.localID, timeout: 5)

        XCTAssertEqual(outcome, .failedPermanently)
        let pendingIDs = try await draftStore.pendingSubmissionLocalIDs()
        XCTAssertTrue(pendingIDs.isEmpty)
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
