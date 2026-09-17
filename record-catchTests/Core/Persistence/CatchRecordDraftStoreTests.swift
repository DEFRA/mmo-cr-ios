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
}
