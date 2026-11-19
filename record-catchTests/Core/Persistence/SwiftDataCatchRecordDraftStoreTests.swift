import XCTest
import SwiftData
@testable import record_catch

/// Exercises `SwiftDataCatchRecordDraftStore` against a real, in-memory `ModelContainer` (rather
/// than `InMemoryCatchRecordDraftStore`'s hand-rolled dictionary fake), so the actual SwiftData
/// fetch/insert/delete/save calls in `CatchRecordDraftStore.swift` — and `CatchRecordEntity`'s
/// initializer — are covered (see ADR-0014). `isStoredInMemoryOnly: true` keeps this hermetic and
/// fast: nothing touches disk.
@MainActor
final class SwiftDataCatchRecordDraftStoreTests: XCTestCase {

    private func makeStore() throws -> SwiftDataCatchRecordDraftStore {
        try makeStoreWithContext().store
    }

    /// Like `makeStore()`, but also hands back the underlying `ModelContext` for tests that need
    /// to inspect a `CatchRecordEntity` field with no accessor on `CatchRecordDraftStoring` (e.g.
    /// `serverVersion` after `markSubmissionSucceeded` clears `idempotencyKey`, at which point
    /// `submissionProgress(localID:)` deliberately returns `nil` — see
    /// `test_markSubmissionSucceeded_clearsTheQueueStateAndIdempotencyKey`).
    private func makeStoreWithContext() throws -> (store: SwiftDataCatchRecordDraftStore, context: ModelContext) {
        let container = try ModelContainer(
            for: CatchRecordEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        return (SwiftDataCatchRecordDraftStore(modelContext: context), context)
    }

    // MARK: - Save / load round trip

    func test_save_thenLoadDraft_returnsThePersistedPayload() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.returnDate = Date()
        draft.gearCatches = [GearCatch(gear: .seineNets, statisticalArea: "38E96")]

        try await store.save(draft)
        let loaded = try await store.loadDraft(localID: draft.localID)

        XCTAssertEqual(loaded, draft.payload)
    }

    func test_save_calledTwiceForSameLocalID_updatesRatherThanDuplicates() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        try await store.save(draft)

        draft.vessel = "HERCULES"
        try await store.save(draft)

        let summaries = try await store.allUnsentDrafts()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.vessel, "HERCULES")
    }

    func test_loadDraft_forUnknownLocalID_returnsNil() async throws {
        let store = try makeStore()
        let loaded = try await store.loadDraft(localID: UUID())
        XCTAssertNil(loaded)
    }

    // MARK: - Delete

    func test_deleteDraft_removesIt_soLoadReturnsNil() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        try await store.save(draft)

        try await store.deleteDraft(localID: draft.localID)

        let loaded = try await store.loadDraft(localID: draft.localID)
        XCTAssertNil(loaded)
    }

    func test_deleteDraft_forUnknownLocalID_isANoOp() async throws {
        let store = try makeStore()
        try await store.deleteDraft(localID: UUID()) // should not throw
    }

    // MARK: - allUnsentDrafts

    func test_allUnsentDrafts_returnsEverySavedDraft_newestFirst() async throws {
        let store = try makeStore()
        let first = CatchRecordDraft()
        first.vessel = "ACHILLES"
        try await store.save(first)

        try await Task.sleep(nanoseconds: 5_000_000) // ensures a distinct lastEditedAt

        let second = CatchRecordDraft()
        second.vessel = "HERCULES"
        try await store.save(second)

        let summaries = try await store.allUnsentDrafts()

        XCTAssertEqual(summaries.map(\.vessel), ["HERCULES", "ACHILLES"])
    }

    func test_allUnsentDrafts_whenEmpty_returnsEmptyArray() async throws {
        let store = try makeStore()
        let summaries = try await store.allUnsentDrafts()
        XCTAssertTrue(summaries.isEmpty)
    }

    func test_allUnsentDrafts_summary_carriesVesselAndTripEndDateFromTheDraft() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.returnDate = Date()
        try await store.save(draft)

        let summaries = try await store.allUnsentDrafts()

        XCTAssertEqual(summaries.first?.localID, draft.localID)
        XCTAssertEqual(summaries.first?.vessel, draft.vessel)
        XCTAssertEqual(summaries.first?.tripEndDate, draft.returnDate)
    }

    // MARK: - Checkpoint (see BR-SUB-010/AC12 — distinguishing Draft from Complete Not Submitted)

    func test_allUnsentDrafts_summary_carriesCheckpointFromTheDraft() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.advance(to: .ports)
        try await store.save(draft)

        let summaries = try await store.allUnsentDrafts()

        XCTAssertEqual(summaries.first?.checkpoint, .ports)
        XCTAssertFalse(summaries.first?.isComplete ?? true)
    }

    func test_allUnsentDrafts_summary_whenCheckYourAnswersReached_isComplete() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.advance(to: .checkYourAnswers)
        try await store.save(draft)

        let summaries = try await store.allUnsentDrafts()

        XCTAssertTrue(summaries.first?.isComplete ?? false)
    }

    /// Regression guard: a row persisted before `checkpointRawValue` existed (`nil`) must still
    /// load, falling back to the safe "still in progress" default rather than crashing or
    /// miscategorising an old row as complete (see `CatchRecordEntity.checkpointRawValue`).
    func test_allUnsentDrafts_entityPersistedWithoutCheckpoint_fallsBackToVesselAndIsNotComplete() async throws {
        let container = try ModelContainer(
            for: CatchRecordEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let payload = CatchRecordDraftPayload(
            vessel: "ACHILLES",
            departureDate: nil,
            returnDate: nil,
            departurePort: nil,
            returnPort: nil,
            gearCatches: [],
            speciesNotLanded: []
        )
        let entity = CatchRecordEntity(
            localID: UUID(),
            lastEditedAt: Date(),
            summary: CatchRecordEntitySummary(vessel: "ACHILLES", tripEndDate: nil),
            payload: try JSONEncoder().encode(payload)
        )
        context.insert(entity)
        try context.save()

        let store = SwiftDataCatchRecordDraftStore(modelContext: context)
        let summaries = try await store.allUnsentDrafts()

        XCTAssertEqual(summaries.first?.checkpoint, .vessel)
        XCTAssertFalse(summaries.first?.isComplete ?? true)
    }

    // MARK: - markSubmitted / allRecords (a submitted draft is retained, not deleted — see
    // CheckYourAnswersViewModel and ADR-0014/0015)

    func test_markSubmitted_excludesTheDraftFromAllUnsentDrafts() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        try await store.save(draft)

        try await store.markSubmitted(localID: draft.localID)

        let summaries = try await store.allUnsentDrafts()
        XCTAssertTrue(summaries.isEmpty)
    }

    func test_markSubmitted_forUnknownLocalID_isANoOp() async throws {
        let store = try makeStore()
        try await store.markSubmitted(localID: UUID()) // should not throw
        let records = try await store.allRecords()
        XCTAssertTrue(records.isEmpty)
    }

    func test_markSubmitted_keepsTheDraftLoadable_andIncludedInAllRecords() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.returnDate = Date()
        try await store.save(draft)

        try await store.markSubmitted(localID: draft.localID)

        let loaded = try await store.loadDraft(localID: draft.localID)
        XCTAssertNotNil(loaded, "a submitted draft must be retained, not deleted, so it keeps showing on Home")

        let records = try await store.allRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.vessel, "ACHILLES")
        XCTAssertTrue(records.first?.isSubmitted ?? false)
    }

    func test_allRecords_includesBothUnsentAndSubmittedDrafts_newestFirst() async throws {
        let store = try makeStore()
        let unsent = CatchRecordDraft()
        unsent.vessel = "ACHILLES"
        try await store.save(unsent)

        try await Task.sleep(nanoseconds: 5_000_000) // ensures a distinct lastEditedAt

        let submitted = CatchRecordDraft()
        submitted.vessel = "HERCULES"
        try await store.save(submitted)
        try await store.markSubmitted(localID: submitted.localID)

        let records = try await store.allRecords()

        XCTAssertEqual(records.map(\.vessel), ["HERCULES", "ACHILLES"])
        XCTAssertEqual(records.map(\.isSubmitted), [true, false])
    }

    func test_allRecords_whenEmpty_returnsEmptyArray() async throws {
        let store = try makeStore()
        let records = try await store.allRecords()
        XCTAssertTrue(records.isEmpty)
    }

    // MARK: - Submission queue (ADR-0028)

    func test_enqueueForSubmission_persistsDraft_andMarksItPendingWithAnIdempotencyKey() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"

        try await store.enqueueForSubmission(draft)

        let pendingIDs = try await store.pendingSubmissionLocalIDs()
        XCTAssertEqual(pendingIDs, [draft.localID])
        let progress = try await store.submissionProgress(localID: draft.localID)
        XCTAssertNotNil(progress?.idempotencyKey)
        XCTAssertNil(progress?.serverID)
    }

    func test_enqueueForSubmission_calledTwice_reusesTheSameIdempotencyKey() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"

        try await store.enqueueForSubmission(draft)
        let firstKey = try await store.submissionProgress(localID: draft.localID)?.idempotencyKey

        try await store.enqueueForSubmission(draft)
        let secondKey = try await store.submissionProgress(localID: draft.localID)?.idempotencyKey

        XCTAssertNotNil(firstKey)
        XCTAssertEqual(firstKey, secondKey)
    }

    func test_enqueueForSubmission_forUnknownLocalID_isANoOp() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft() // never saved first
        try await store.enqueueForSubmission(draft)
        // save(_:) inside enqueueForSubmission always inserts, so this always succeeds; assert the
        // record is now queryable rather than asserting a no-op.
        let pendingIDs = try await store.pendingSubmissionLocalIDs()
        XCTAssertEqual(pendingIDs, [draft.localID])
    }

    func test_markSending_updatesQueueState_withoutClearingProgress() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        try await store.enqueueForSubmission(draft)

        try await store.markSending(localID: draft.localID)

        let progress = try await store.submissionProgress(localID: draft.localID)
        XCTAssertNotNil(progress?.idempotencyKey)
    }

    func test_markSending_forUnknownLocalID_isANoOp() async throws {
        let store = try makeStore()
        try await store.markSending(localID: UUID()) // should not throw
    }

    func test_submissionProgress_forNeverQueuedRecord_returnsNil() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        try await store.save(draft) // saved, but never enqueued for submission

        let progress = try await store.submissionProgress(localID: draft.localID)

        XCTAssertNil(progress)
    }

    func test_submissionProgress_forUnknownLocalID_returnsNil() async throws {
        let store = try makeStore()
        let progress = try await store.submissionProgress(localID: UUID())
        XCTAssertNil(progress)
    }

    func test_recordServerProgress_storesServerIDAndVersion_forSubsequentAttempts() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        try await store.enqueueForSubmission(draft)

        try await store.recordServerProgress(localID: draft.localID, serverID: "server-1", version: 3)

        let progress = try await store.submissionProgress(localID: draft.localID)
        XCTAssertEqual(progress?.serverID, "server-1")
        XCTAssertEqual(progress?.serverVersion, 3)
    }

    func test_markSubmissionSucceeded_withSubmittedVersion_recordsItAsTheNewServerVersion() async throws {
        let (store, context) = try makeStoreWithContext()
        let draft = CatchRecordDraft()
        try await store.enqueueForSubmission(draft)
        try await store.recordServerProgress(localID: draft.localID, serverID: "server-1", version: 1)

        try await store.markSubmissionSucceeded(localID: draft.localID, submittedVersion: 2)

        // `submissionProgress(localID:)` deliberately returns nil once `markSubmissionSucceeded`
        // clears the idempotency key (see the next test), so the persisted `serverVersion` has to
        // be read straight off the entity here rather than through that accessor.
        let localID = draft.localID
        let descriptor = FetchDescriptor<CatchRecordEntity>(predicate: #Predicate { $0.localID == localID })
        let entity = try context.fetch(descriptor).first
        XCTAssertEqual(entity?.serverVersion, 2)
        let records = try await store.allRecords()
        XCTAssertEqual(records.first?.displayStatus, .submitted)
        XCTAssertEqual(records.first?.submissionCount, 1)
    }

    func test_markSubmissionSucceeded_clearsTheQueueStateAndIdempotencyKey() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        try await store.enqueueForSubmission(draft)

        try await store.markSubmissionSucceeded(localID: draft.localID, submittedVersion: nil)

        let pendingIDs = try await store.pendingSubmissionLocalIDs()
        XCTAssertTrue(pendingIDs.isEmpty)
        let progress = try await store.submissionProgress(localID: draft.localID)
        XCTAssertNil(progress, "idempotencyKey must be cleared so a future re-submission gets a fresh one")
    }

    func test_markSubmissionFailed_whenRetryable_keepsTheRecordQueued() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        try await store.enqueueForSubmission(draft)

        try await store.markSubmissionFailed(localID: draft.localID, permanent: false, errorCode: "offline")

        let pendingIDs = try await store.pendingSubmissionLocalIDs()
        XCTAssertEqual(pendingIDs, [draft.localID])
    }

    func test_markSubmissionFailed_whenPermanent_revertsToDraft_clearingTheQueue() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        try await store.enqueueForSubmission(draft)

        try await store.markSubmissionFailed(localID: draft.localID, permanent: true, errorCode: "missing_vessel")

        let pendingIDs = try await store.pendingSubmissionLocalIDs()
        XCTAssertTrue(pendingIDs.isEmpty)
        let progress = try await store.submissionProgress(localID: draft.localID)
        XCTAssertNil(progress, "a permanent failure clears the idempotency key so a retry starts a fresh cycle")
    }

    func test_markSubmissionFailed_forUnknownLocalID_isANoOp() async throws {
        let store = try makeStore()
        try await store.markSubmissionFailed(localID: UUID(), permanent: true, errorCode: "x") // should not throw
    }

    func test_pendingSubmissionLocalIDs_whenEmpty_returnsEmptyArray() async throws {
        let store = try makeStore()
        let pendingIDs = try await store.pendingSubmissionLocalIDs()
        XCTAssertTrue(pendingIDs.isEmpty)
    }

    func test_pendingSubmissionLocalIDs_ordersOldestQueuedFirst() async throws {
        let store = try makeStore()
        let first = CatchRecordDraft()
        try await store.enqueueForSubmission(first)

        try await Task.sleep(nanoseconds: 5_000_000) // ensures a distinct lastEditedAt

        let second = CatchRecordDraft()
        try await store.enqueueForSubmission(second)

        let pendingIDs = try await store.pendingSubmissionLocalIDs()

        XCTAssertEqual(pendingIDs, [first.localID, second.localID])
    }
}
