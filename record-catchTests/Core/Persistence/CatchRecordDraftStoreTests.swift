import XCTest
@testable import record_catch

@MainActor
final class CatchRecordDraftStoreTests: XCTestCase {

    // MARK: - Save / load round trip

    func test_save_thenLoadDraft_returnsThePersistedPayload() async throws {
        let store = InMemoryCatchRecordDraftStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.gearCatches = [GearCatch(gear: .seineNets, statisticalArea: "38E96")]

        try await store.save(draft)
        let loaded = try await store.loadDraft(localID: draft.localID)

        XCTAssertEqual(loaded, draft.payload)
    }

    func test_save_calledTwiceForSameLocalID_updatesRatherThanDuplicates() async throws {
        let store = InMemoryCatchRecordDraftStore()
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
        let store = InMemoryCatchRecordDraftStore()
        let loaded = try await store.loadDraft(localID: UUID())
        XCTAssertNil(loaded)
    }

    // MARK: - Delete

    func test_deleteDraft_removesIt_soLoadReturnsNil() async throws {
        let store = InMemoryCatchRecordDraftStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        try await store.save(draft)

        try await store.deleteDraft(localID: draft.localID)

        let loaded = try await store.loadDraft(localID: draft.localID)
        XCTAssertNil(loaded)
    }

    func test_deleteDraft_forUnknownLocalID_isANoOp() async throws {
        let store = InMemoryCatchRecordDraftStore()
        try await store.deleteDraft(localID: UUID()) // should not throw
    }

    // MARK: - allUnsentDrafts

    func test_allUnsentDrafts_returnsEverySavedDraft_newestFirst() async throws {
        let store = InMemoryCatchRecordDraftStore()
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
        let store = InMemoryCatchRecordDraftStore()
        let summaries = try await store.allUnsentDrafts()
        XCTAssertTrue(summaries.isEmpty)
    }

    func test_init_seed_prePopulatesTheStore() async throws {
        let localID = UUID()
        let payload = CatchRecordDraft(localID: localID).payload
        let store = InMemoryCatchRecordDraftStore(seed: [localID: payload])

        let loaded = try await store.loadDraft(localID: localID)

        XCTAssertEqual(loaded, payload)
    }

    // MARK: - Checkpoint (see BR-SUB-010/AC12 — distinguishing Draft from Complete Not Submitted)

    func test_allUnsentDrafts_summary_carriesCheckpointFromTheDraft() async throws {
        let store = InMemoryCatchRecordDraftStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.advance(to: .gear)
        try await store.save(draft)

        let summaries = try await store.allUnsentDrafts()

        XCTAssertEqual(summaries.first?.checkpoint, .gear)
    }

    func test_isComplete_whenCheckpointIsBeforeCheckYourAnswers_isFalse() async throws {
        let store = InMemoryCatchRecordDraftStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.advance(to: .landingStorage)
        try await store.save(draft)

        let summaries = try await store.allUnsentDrafts()

        XCTAssertFalse(summaries.first?.isComplete ?? true)
    }

    func test_isComplete_whenCheckpointIsCheckYourAnswers_isTrue() async throws {
        let store = InMemoryCatchRecordDraftStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.advance(to: .checkYourAnswers)
        try await store.save(draft)

        let summaries = try await store.allUnsentDrafts()

        XCTAssertTrue(summaries.first?.isComplete ?? false)
    }

    // MARK: - markSubmitted / allRecords (a submitted draft is retained, not deleted — see
    // CheckYourAnswersViewModel and ADR-0014/0015)

    func test_markSubmitted_excludesTheDraftFromAllUnsentDrafts() async throws {
        let store = InMemoryCatchRecordDraftStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        try await store.save(draft)

        try await store.markSubmitted(localID: draft.localID)

        let summaries = try await store.allUnsentDrafts()
        XCTAssertTrue(summaries.isEmpty)
    }

    func test_markSubmitted_keepsTheDraftLoadable_andIncludedInAllRecords() async throws {
        let store = InMemoryCatchRecordDraftStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        try await store.save(draft)

        try await store.markSubmitted(localID: draft.localID)

        let loaded = try await store.loadDraft(localID: draft.localID)
        XCTAssertNotNil(loaded, "a submitted draft must be retained, not deleted, so it keeps showing on Home")

        let records = try await store.allRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.vessel, "ACHILLES")
        XCTAssertTrue(records.first?.isSubmitted ?? false)
    }

    func test_markSubmitted_forUnknownLocalID_isANoOp() async throws {
        let store = InMemoryCatchRecordDraftStore()
        try await store.markSubmitted(localID: UUID()) // should not throw
        let records = try await store.allRecords()
        XCTAssertTrue(records.isEmpty)
    }

    func test_allRecords_includesBothUnsentAndSubmittedDrafts_newestFirst() async throws {
        let store = InMemoryCatchRecordDraftStore()
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
        let store = InMemoryCatchRecordDraftStore()
        let records = try await store.allRecords()
        XCTAssertTrue(records.isEmpty)
    }
}
